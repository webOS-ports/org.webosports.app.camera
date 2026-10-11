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

#ifndef JPEGEXIF_H
#define JPEGEXIF_H

#include <QByteArray>
#include <QList>

/*
 * Editing the EXIF block of a JPEG in memory: what the camera needs to tag a
 * photo with where it was taken and which way up it is, without decoding or
 * re-encoding the picture. The EXIF data itself is handled by libexif; this
 * finds and replaces the APP1 segment that carries it.
 */
namespace JpegExif {

/* The payload of the JPEG's EXIF APP1 segment ("Exif\0\0" followed by the
 * TIFF data), or an empty array when it has none or is not a JPEG. */
QByteArray exifSegment(const QByteArray &jpeg);

/*
 * The JPEG with its EXIF segment replaced by `exif` (a payload as above), or
 * the segment added when it had none: right after the JFIF APP0 segment if
 * there is one, else right after the start of image. Empty if `jpeg` is not a
 * JPEG, its segments run past its end, or `exif` does not fit in a segment.
 */
QByteArray withExifSegment(const QByteArray &jpeg, const QByteArray &exif);

/* A coordinate as degrees, minutes and seconds, the way EXIF stores it. */
struct Dms {
    unsigned degrees;
    unsigned minutes;
    // Seconds in ten-thousandths, so a rational of n/10000.
    unsigned secondsE4;
};
Dms toDms(double coordinate);

/* The EXIF Orientation value for a picture a viewer has to turn `clockwise`
 * degrees (0, 90, 180, 270; anything else counts as 0) to show upright. */
int orientationForRotation(int clockwise);

struct Location {
    double latitude;
    double longitude;
    double altitude;
    bool hasAltitude;
};

/*
 * `exif` (a payload as above; empty for none) with the GPS position, the
 * orientation and/or the exposure bias set, everything else kept. orientation
 * is an EXIF value 1..8, or 0 to leave it alone; exposureBias is in EV, to
 * the hundredth, or null to leave it alone. Empty on failure.
 */
QByteArray edited(const QByteArray &exif, const Location *location, int orientation,
                  const double *exposureBias = nullptr);

} // namespace JpegExif

#endif // JPEGEXIF_H
