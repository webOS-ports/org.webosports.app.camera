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

#ifndef IMAGETOOLS_H
#define IMAGETOOLS_H

#include <QObject>
#include <QString>
#include <QVariantMap>

/*
 * What the camera does to a photo once it is saved, off the GUI thread:
 *
 * - "rotation": the clockwise turn a viewer needs to show it upright, written
 *   as the EXIF Orientation. Neither camera stack turns the picture itself:
 *   the HAL hands over the sensor's frame with Orientation 1, so without
 *   this a portrait photo shows up on its side.
 * - "latitude", "longitude" (and "altitude"): where it was taken, as EXIF GPS.
 * - "exposureBias": the exposure compensation the camera applied, in EV,
 *   written as the EXIF ExposureBiasValue. The Q25's HAL writes its internal
 *   step count there (+10 for +2 EV).
 * - "zoom": a digital zoom the camera did not apply (the libcamera path only
 *   scales its viewfinder), carried out by cropping the centre. The EXIF block
 *   is kept.
 *
 * finished() reports the file once it is done, so the thumbnail shows the
 * final picture.
 */
class ImageTools : public QObject
{
    Q_OBJECT

public:
    explicit ImageTools(QObject *parent = nullptr);

    Q_INVOKABLE void process(const QString &path, const QVariantMap &options);

    /* The same work, synchronously; used by process() on a pool thread. */
    static bool processFile(const QString &path, const QVariantMap &options, QString *error);

Q_SIGNALS:
    void finished(const QString &path, bool ok, const QString &error);
};

#endif // IMAGETOOLS_H
