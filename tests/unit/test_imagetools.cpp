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

#include <gtest/gtest.h>

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QFile>
#include <QImage>
#include <QImageReader>
#include <QTemporaryDir>
#include <QThreadPool>

#include <libexif/exif-data.h>

#include "imagetools.h"
#include "jpegexif.h"

/* A photo with a camera's EXIF block, as the HAL writes one: a red left half
 * and a blue right half, so a crop shows whether it took the middle. */
static QString writePhoto(const QTemporaryDir &dir, const char *name)
{
    QImage image(400, 300, QImage::Format_RGB32);
    image.fill(Qt::blue);
    for (int y = 0; y < 300; ++y)
        for (int x = 0; x < 200; ++x)
            image.setPixel(x, y, qRgb(255, 0, 0));
    const QString path = dir.filePath(QString::fromLatin1(name));
    image.save(path, "JPEG", 95);

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return QString();
    const QByteArray tagged = JpegExif::withExifSegment(f.readAll(),
                                                        JpegExif::edited(QByteArray(), nullptr, 1));
    f.close();
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate) || f.write(tagged) != tagged.size())
        return QString();
    return path;
}

static QByteArray readAll(const QString &path)
{
    QFile f(path);
    return f.open(QIODevice::ReadOnly) ? f.readAll() : QByteArray();
}

TEST(ImageTools, TurnsAndTags)
{
    QTemporaryDir dir;
    const QString path = writePhoto(dir, "a.jpg");
    QString error;
    ASSERT_TRUE(ImageTools::processFile(path, { { "rotation", 90 }, { "latitude", 52.37 },
                                                { "longitude", 4.89 }, { "altitude", 2.0 } }, &error))
        << error.toStdString();

    QImageReader reader(path);
    reader.setAutoTransform(true);
    // Shown turned: 300 wide, 400 tall.
    EXPECT_EQ(reader.read().size(), QSize(300, 400));

    const QByteArray exif = JpegExif::exifSegment(readAll(path));
    ExifData *d = exif_data_new_from_data(reinterpret_cast<const unsigned char *>(exif.constData()),
                                          static_cast<unsigned int>(exif.size()));
    ASSERT_NE(d, nullptr);
    EXPECT_NE(exif_content_get_entry(d->ifd[EXIF_IFD_GPS], static_cast<ExifTag>(EXIF_TAG_GPS_LATITUDE)), nullptr);
    exif_data_unref(d);
}

TEST(ImageTools, CropsTheMiddleAndKeepsTheExif)
{
    QTemporaryDir dir;
    const QString path = writePhoto(dir, "b.jpg");
    QString error;
    ASSERT_TRUE(ImageTools::processFile(path, { { "zoom", 2.0 }, { "rotation", 180 } }, &error))
        << error.toStdString();

    QImageReader reader(path);
    reader.setAutoTransform(false);
    const QImage image = reader.read();
    ASSERT_EQ(image.size(), QSize(200, 150));
    // The middle of a red|blue picture: red on the left, blue on the right.
    EXPECT_GT(qRed(image.pixel(20, 75)), 200);
    EXPECT_GT(qBlue(image.pixel(180, 75)), 200);
    EXPECT_FALSE(JpegExif::exifSegment(readAll(path)).isEmpty());
}

TEST(ImageTools, RefusesNonsense)
{
    QTemporaryDir dir;
    const QString path = writePhoto(dir, "c.jpg");
    const QByteArray before = readAll(path);
    QString error;
    EXPECT_FALSE(ImageTools::processFile(path, { { "latitude", 123.0 }, { "longitude", 4.0 } }, &error));
    EXPECT_FALSE(ImageTools::processFile(dir.filePath("missing.jpg"), { { "rotation", 90 } }, &error));
    // A refused photo is left exactly as it was.
    EXPECT_EQ(readAll(path), before);

    const QString text = dir.filePath("d.jpg");
    QFile f(text);
    ASSERT_TRUE(f.open(QIODevice::WriteOnly));
    f.write("not a picture");
    f.close();
    EXPECT_FALSE(ImageTools::processFile(text, { { "rotation", 90 } }, &error));
    EXPECT_EQ(readAll(text), QByteArray("not a picture"));
}

TEST(ImageTools, ReportsBackOnTheGuiThread)
{
    QTemporaryDir dir;
    const QString path = writePhoto(dir, "e.jpg");
    ImageTools tools;
    QString done;
    bool ok = false;
    QObject::connect(&tools, &ImageTools::finished, &tools,
                     [&](const QString &p, bool success, const QString &) { done = p; ok = success; });
    tools.process(path, { { "rotation", 270 } });
    QElapsedTimer t;
    t.start();
    while (done.isEmpty() && t.elapsed() < 5000)
        QCoreApplication::processEvents(QEventLoop::AllEvents, 20);
    EXPECT_EQ(done, path);
    EXPECT_TRUE(ok);
}

TEST(ImageTools, DeletedWhileWorking)
{
    QTemporaryDir dir;
    const QString path = writePhoto(dir, "f.jpg");
    auto *tools = new ImageTools;
    tools->process(path, { { "zoom", 1.5 } });
    delete tools;
    QThreadPool::globalInstance()->waitForDone();
    QCoreApplication::processEvents();
    SUCCEED();
}
