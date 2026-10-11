/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "imagetools.h"
#include "jpegexif.h"

#include <QBuffer>
#include <QCoreApplication>
#include <QFile>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QPointer>
#include <QSaveFile>
#include <QThreadPool>

#include <cmath>

ImageTools::ImageTools(QObject *parent)
    : QObject(parent)
{
}

void ImageTools::process(const QString &path, const QVariantMap &options)
{
    QPointer<ImageTools> guard(this);
    QThreadPool::globalInstance()->start([guard, path, options] {
        QString error;
        const bool ok = processFile(path, options, &error);
        QMetaObject::invokeMethod(QCoreApplication::instance(), [guard, path, ok, error] {
            if (guard)
                Q_EMIT guard->finished(path, ok, error);
        }, Qt::QueuedConnection);
    });
}

/* The centre 1/zoom of the picture, encoded afresh. */
static QByteArray cropped(const QByteArray &jpeg, double zoom, QString *error)
{
    QBuffer in;
    in.setData(jpeg);
    in.open(QIODevice::ReadOnly);
    QImageReader reader(&in, "jpeg");
    // Applied to the picture as stored; the orientation is EXIF's business.
    reader.setAutoTransform(false);
    const QSize size = reader.size();
    if (!size.isValid()) {
        *error = QStringLiteral("cannot read the picture");
        return QByteArray();
    }
    const int w = std::max(1, int(std::lround(size.width() / zoom)));
    const int h = std::max(1, int(std::lround(size.height() / zoom)));
    reader.setClipRect(QRect((size.width() - w) / 2, (size.height() - h) / 2, w, h));
    const QImage image = reader.read();
    if (image.isNull()) {
        *error = reader.errorString();
        return QByteArray();
    }

    QBuffer out;
    out.open(QIODevice::WriteOnly);
    QImageWriter writer(&out, "jpeg");
    writer.setQuality(95);
    if (!writer.write(image)) {
        *error = writer.errorString();
        return QByteArray();
    }
    return out.data();
}

bool ImageTools::processFile(const QString &path, const QVariantMap &options, QString *error)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        *error = file.errorString();
        return false;
    }
    QByteArray jpeg = file.readAll();
    file.close();

    QByteArray exif = JpegExif::exifSegment(jpeg);

    const double zoom = options.value(QStringLiteral("zoom"), 1.0).toDouble();
    if (zoom > 1.001) {
        jpeg = cropped(jpeg, zoom, error);
        if (jpeg.isEmpty())
            return false;
    }

    const bool hasLocation = options.contains(QStringLiteral("latitude"))
        && options.contains(QStringLiteral("longitude"));
    JpegExif::Location location{};
    if (hasLocation) {
        location.latitude = options.value(QStringLiteral("latitude")).toDouble();
        location.longitude = options.value(QStringLiteral("longitude")).toDouble();
        location.hasAltitude = options.contains(QStringLiteral("altitude"))
            && std::isfinite(options.value(QStringLiteral("altitude")).toDouble());
        location.altitude = location.hasAltitude ? options.value(QStringLiteral("altitude")).toDouble() : 0.0;
        if (!std::isfinite(location.latitude) || !std::isfinite(location.longitude)
            || std::fabs(location.latitude) > 90.0 || std::fabs(location.longitude) > 180.0) {
            *error = QStringLiteral("not a position");
            return false;
        }
    }
    const int orientation = options.contains(QStringLiteral("rotation"))
        ? JpegExif::orientationForRotation(options.value(QStringLiteral("rotation")).toInt())
        : 0;

    /* The exposure compensation the camera applied, in EV. Some HALs (the
     * Q25's) write their internal step count there instead. */
    const bool hasExposureBias = options.contains(QStringLiteral("exposureBias"));
    const double exposureBias = options.value(QStringLiteral("exposureBias")).toDouble();

    if (hasLocation || orientation || zoom > 1.001 || hasExposureBias) {
        const QByteArray newExif = JpegExif::edited(exif, hasLocation ? &location : nullptr, orientation,
                                                    hasExposureBias ? &exposureBias : nullptr);
        if (newExif.isEmpty()) {
            *error = QStringLiteral("cannot write the EXIF data");
            return false;
        }
        jpeg = JpegExif::withExifSegment(jpeg, newExif);
        if (jpeg.isEmpty()) {
            *error = QStringLiteral("not a JPEG");
            return false;
        }
    }

    // Written aside and renamed over, so a crash never leaves half a photo.
    QSaveFile out(path);
    if (!out.open(QIODevice::WriteOnly) || out.write(jpeg) != jpeg.size() || !out.commit()) {
        *error = out.errorString();
        return false;
    }
    return true;
}
