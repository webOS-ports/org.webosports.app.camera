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

#include <QBuffer>
#include <QImage>
#include <QImageReader>

#include <libexif/exif-data.h>

#include <cmath>

#include "jpegexif.h"

using namespace JpegExif;

/* A real JPEG, as Qt writes it: SOI, the JFIF APP0, then the image. */
static QByteArray makeJpeg(int w = 64, int h = 48)
{
    QImage image(w, h, QImage::Format_RGB32);
    image.fill(Qt::darkCyan);
    QByteArray bytes;
    QBuffer buffer(&bytes);
    buffer.open(QIODevice::WriteOnly);
    image.save(&buffer, "JPEG", 90);
    return bytes;
}

static ExifData *parse(const QByteArray &exif)
{
    return exif_data_new_from_data(reinterpret_cast<const unsigned char *>(exif.constData()),
                                   static_cast<unsigned int>(exif.size()));
}

static double rationalValue(const ExifEntry *e, int i, ExifByteOrder order)
{
    const ExifRational r = exif_get_rational(e->data + i * 8, order);
    return r.denominator ? double(r.numerator) / r.denominator : NAN;
}

static double coordinate(ExifData *d, int tag)
{
    const ExifEntry *e = exif_content_get_entry(d->ifd[EXIF_IFD_GPS], static_cast<ExifTag>(tag));
    if (!e || e->components != 3)
        return NAN;
    const ExifByteOrder o = exif_data_get_byte_order(d);
    return rationalValue(e, 0, o) + rationalValue(e, 1, o) / 60.0 + rationalValue(e, 2, o) / 3600.0;
}

static QString ascii(ExifData *d, ExifIfd ifd, int tag)
{
    const ExifEntry *e = exif_content_get_entry(d->ifd[ifd], static_cast<ExifTag>(tag));
    return e ? QString::fromLatin1(reinterpret_cast<const char *>(e->data)) : QString();
}

TEST(Segments, NoExifInAPlainJpeg)
{
    EXPECT_TRUE(exifSegment(makeJpeg()).isEmpty());
    EXPECT_TRUE(exifSegment(QByteArray("not a jpeg")).isEmpty());
    EXPECT_TRUE(exifSegment(QByteArray()).isEmpty());
}

TEST(Segments, AddedAfterJfifAndReadBack)
{
    const QByteArray jpeg = makeJpeg();
    const QByteArray exif = edited(QByteArray(), nullptr, 6);
    ASSERT_FALSE(exif.isEmpty());

    const QByteArray tagged = withExifSegment(jpeg, exif);
    ASSERT_FALSE(tagged.isEmpty());
    EXPECT_EQ(exifSegment(tagged), exif);
    // JFIF keeps its place as the first segment.
    EXPECT_EQ(uchar(tagged.at(2)), 0xff);
    EXPECT_EQ(uchar(tagged.at(3)), 0xe0);
    // The picture itself is untouched and still decodes.
    QImage decoded;
    ASSERT_TRUE(decoded.loadFromData(tagged, "JPEG"));
    EXPECT_EQ(decoded.size(), QSize(64, 48));
}

TEST(Segments, ReplacedNotDuplicated)
{
    const QByteArray once = withExifSegment(makeJpeg(), edited(QByteArray(), nullptr, 6));
    const QByteArray second = edited(exifSegment(once), nullptr, 3);
    const QByteArray twice = withExifSegment(once, second);
    ASSERT_FALSE(twice.isEmpty());
    EXPECT_EQ(exifSegment(twice), second);
    EXPECT_EQ(twice.count(QByteArray("Exif\0\0", 6)), 1);
}

TEST(Segments, RefusesBrokenInput)
{
    const QByteArray exif = edited(QByteArray(), nullptr, 1);
    EXPECT_TRUE(withExifSegment(QByteArray("\xff\xd8\xff\xe0\x10\x00", 6), exif).isEmpty());
    EXPECT_TRUE(withExifSegment(QByteArray("plain text"), exif).isEmpty());
    // A payload that is not EXIF, or too large for one segment.
    EXPECT_TRUE(withExifSegment(makeJpeg(), QByteArray("hello")).isEmpty());
    EXPECT_TRUE(withExifSegment(makeJpeg(), QByteArray("Exif\0\0", 6) + QByteArray(70000, 'x')).isEmpty());
    // A segment length running past the end.
    QByteArray truncated = makeJpeg();
    truncated.truncate(10);
    EXPECT_TRUE(withExifSegment(truncated, exif).isEmpty());
}

TEST(Dms, SplitsDegrees)
{
    const Dms a = toDms(52.3702);
    EXPECT_EQ(a.degrees, 52u);
    EXPECT_EQ(a.minutes, 22u);
    EXPECT_NEAR(a.secondsE4 / 10000.0, 12.72, 0.0001);
    // The sign is EXIF's reference, not the numbers'.
    const Dms b = toDms(-4.8952);
    EXPECT_EQ(b.degrees, 4u);
    EXPECT_EQ(b.minutes, 53u);
    // Rounding up into the next minute and degree.
    const Dms c = toDms(10.0 - 1e-9);
    EXPECT_EQ(c.degrees, 10u);
    EXPECT_EQ(c.minutes, 0u);
    EXPECT_EQ(c.secondsE4, 0u);
}

TEST(Orientation, FromClockwiseTurn)
{
    EXPECT_EQ(orientationForRotation(0), 1);
    EXPECT_EQ(orientationForRotation(90), 6);
    EXPECT_EQ(orientationForRotation(180), 3);
    EXPECT_EQ(orientationForRotation(270), 8);
    EXPECT_EQ(orientationForRotation(-90), 8);
    EXPECT_EQ(orientationForRotation(450), 6);
    EXPECT_EQ(orientationForRotation(45), 1);
}

TEST(Edited, WritesLocationAndOrientation)
{
    const Location where{ -33.8568, 151.2153, 12.5, true };
    const QByteArray exif = edited(QByteArray(), &where, 8);
    ASSERT_FALSE(exif.isEmpty());

    ExifData *d = parse(exif);
    ASSERT_NE(d, nullptr);
    EXPECT_NEAR(coordinate(d, EXIF_TAG_GPS_LATITUDE), 33.8568, 1e-6);
    EXPECT_NEAR(coordinate(d, EXIF_TAG_GPS_LONGITUDE), 151.2153, 1e-6);
    EXPECT_EQ(ascii(d, EXIF_IFD_GPS, EXIF_TAG_GPS_LATITUDE_REF), "S");
    EXPECT_EQ(ascii(d, EXIF_IFD_GPS, EXIF_TAG_GPS_LONGITUDE_REF), "E");
    EXPECT_EQ(ascii(d, EXIF_IFD_GPS, EXIF_TAG_GPS_MAP_DATUM), "WGS-84");

    const ExifEntry *alt = exif_content_get_entry(d->ifd[EXIF_IFD_GPS], static_cast<ExifTag>(EXIF_TAG_GPS_ALTITUDE));
    ASSERT_NE(alt, nullptr);
    EXPECT_NEAR(rationalValue(alt, 0, exif_data_get_byte_order(d)), 12.5, 1e-9);

    const ExifEntry *o = exif_content_get_entry(d->ifd[EXIF_IFD_0], EXIF_TAG_ORIENTATION);
    ASSERT_NE(o, nullptr);
    EXPECT_EQ(exif_get_short(o->data, exif_data_get_byte_order(d)), 8);
    exif_data_unref(d);
}

TEST(Edited, KeepsWhatWasThere)
{
    // A camera's EXIF: make and model, then tagged afterwards.
    ExifData *camera = exif_data_new();
    exif_data_set_byte_order(camera, EXIF_BYTE_ORDER_MOTOROLA);
    exif_data_fix(camera);
    ExifEntry *make = exif_entry_new();
    exif_content_add_entry(camera->ifd[EXIF_IFD_0], make);
    exif_entry_initialize(make, EXIF_TAG_MAKE);
    unsigned char *raw = nullptr;
    unsigned int size = 0;
    exif_data_save_data(camera, &raw, &size);
    const QByteArray original(reinterpret_cast<const char *>(raw), qsizetype(size));
    free(raw);
    exif_entry_unref(make);
    exif_data_unref(camera);

    const Location where{ 52.0, 5.0, 0, false };
    const QByteArray exif = edited(original, &where, 6);
    ExifData *d = parse(exif);
    ASSERT_NE(d, nullptr);
    EXPECT_NE(exif_content_get_entry(d->ifd[EXIF_IFD_0], EXIF_TAG_MAKE), nullptr);
    EXPECT_EQ(exif_data_get_byte_order(d), EXIF_BYTE_ORDER_MOTOROLA);
    EXPECT_NEAR(coordinate(d, EXIF_TAG_GPS_LATITUDE), 52.0, 1e-9);
    // No altitude was known, so none is claimed.
    EXPECT_EQ(exif_content_get_entry(d->ifd[EXIF_IFD_GPS], static_cast<ExifTag>(EXIF_TAG_GPS_ALTITUDE)), nullptr);
    exif_data_unref(d);
}

TEST(Edited, QtHonoursTheOrientation)
{
    // The point of it all: a viewer turns the picture as tagged.
    const QByteArray tagged = withExifSegment(makeJpeg(64, 48), edited(QByteArray(), nullptr, 6));
    QBuffer buffer;
    buffer.setData(tagged);
    buffer.open(QIODevice::ReadOnly);
    QImageReader reader(&buffer, "JPEG");
    reader.setAutoTransform(true);
    EXPECT_EQ(reader.read().size(), QSize(48, 64));
}

/* An EXIF block with ExposureBiasValue set, as the Q25's HAL writes it: its
 * step count, +10 for +2 EV. */
static QByteArray cameraExifWithBias(ExifSRational bias)
{
    ExifData *camera = exif_data_new();
    exif_data_set_byte_order(camera, EXIF_BYTE_ORDER_MOTOROLA);
    exif_data_fix(camera);
    ExifEntry *e = exif_entry_new();
    exif_content_add_entry(camera->ifd[EXIF_IFD_EXIF], e);
    exif_entry_initialize(e, EXIF_TAG_EXPOSURE_BIAS_VALUE);
    exif_set_srational(e->data, EXIF_BYTE_ORDER_MOTOROLA, bias);
    unsigned char *raw = nullptr;
    unsigned int size = 0;
    exif_data_save_data(camera, &raw, &size);
    const QByteArray out(reinterpret_cast<const char *>(raw), qsizetype(size));
    free(raw);
    exif_entry_unref(e);
    exif_data_unref(camera);
    return out;
}

static double exposureBias(ExifData *d)
{
    const ExifEntry *e = exif_content_get_entry(d->ifd[EXIF_IFD_EXIF], EXIF_TAG_EXPOSURE_BIAS_VALUE);
    if (!e)
        return std::nan("");
    const ExifSRational r = exif_get_srational(e->data, exif_data_get_byte_order(d));
    return r.denominator ? double(r.numerator) / r.denominator : std::nan("");
}

TEST(Edited, ReplacesTheHalsExposureBias)
{
    const double applied = 2.0;
    ExifData *d = parse(edited(cameraExifWithBias({ 10, 1 }), nullptr, 0, &applied));
    ASSERT_NE(d, nullptr);
    EXPECT_NEAR(exposureBias(d), 2.0, 1e-9);
    exif_data_unref(d);

    const double negative = -0.7;
    d = parse(edited(QByteArray(), nullptr, 0, &negative));
    ASSERT_NE(d, nullptr);
    EXPECT_NEAR(exposureBias(d), -0.7, 1e-9);
    exif_data_unref(d);
}

TEST(Edited, LeavesTheExposureBiasAloneWhenNotGiven)
{
    ExifData *d = parse(edited(cameraExifWithBias({ 10, 1 }), nullptr, 6));
    ASSERT_NE(d, nullptr);
    EXPECT_NEAR(exposureBias(d), 10.0, 1e-9);
    exif_data_unref(d);
}

TEST(Edited, RefusesAnExposureBiasThatIsNoNumber)
{
    const double nan = std::nan("");
    EXPECT_TRUE(edited(QByteArray(), nullptr, 0, &nan).isEmpty());
}
