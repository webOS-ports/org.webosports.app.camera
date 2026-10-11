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

#include "jpegexif.h"

#include <libexif/exif-data.h>

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>

namespace JpegExif {

namespace {

const char kExifHeader[] = { 'E', 'x', 'i', 'f', 0, 0 };
const char kJfifHeader[] = { 'J', 'F', 'I', 'F', 0 };
// A segment's length field counts itself, and is 16 bits.
const int kMaxSegmentPayload = 0xffff - 2;

struct Segment {
    int start;   // the 0xff of its marker
    int end;     // one past its last byte
    uchar marker;
    int dataStart;
};

/* libexif defines the GPS tags as plain numbers rather than enumerators of
 * ExifTag, and its API takes them as ExifTag. They lie within the range of
 * values ExifTag can hold (its enumerators run up to 0xffff), so the cast is
 * well defined; it is just not one of the named values. */
constexpr ExifTag gpsTag(int tag)
{
    return static_cast<ExifTag>(tag); // NOLINT(clang-analyzer-optin.core.EnumCastOutOfRange)
}

uchar byteAt(const QByteArray &a, int i)
{
    return static_cast<uchar>(a.at(i));
}

bool startsWith(const QByteArray &a, int from, int to, const char *prefix, int length)
{
    return to - from >= length && std::memcmp(a.constData() + from, prefix, size_t(length)) == 0;
}

/*
 * The segments before the image data, or false if this is not a JPEG or a
 * segment runs past the end. `scanStart` is where the image data (SOS) or the
 * end of the file begins.
 */
bool segments(const QByteArray &jpeg, QList<Segment> &out, int &scanStart)
{
    const int size = int(jpeg.size());
    if (size < 4 || byteAt(jpeg, 0) != 0xff || byteAt(jpeg, 1) != 0xd8)
        return false;

    int pos = 2;
    while (pos + 1 < size) {
        if (byteAt(jpeg, pos) != 0xff)
            return false;
        const uchar marker = byteAt(jpeg, pos + 1);
        if (marker == 0xff) { // fill byte
            ++pos;
            continue;
        }
        if (marker == 0xda || marker == 0xd9) { // start of scan, end of image
            scanStart = pos;
            return true;
        }
        if ((marker >= 0xd0 && marker <= 0xd7) || marker == 0x01) { // no length
            pos += 2;
            continue;
        }
        if (pos + 4 > size)
            return false;
        const int length = (byteAt(jpeg, pos + 2) << 8) | byteAt(jpeg, pos + 3);
        if (length < 2 || pos + 2 + length > size)
            return false;
        out.append(Segment{ pos, pos + 2 + length, marker, pos + 4 });
        pos += 2 + length;
    }
    return false;
}

bool isExif(const QByteArray &jpeg, const Segment &s)
{
    return s.marker == 0xe1 && startsWith(jpeg, s.dataStart, s.end, kExifHeader, 6);
}

/* An entry of the given shape, replacing any the IFD already has for the tag. */
ExifEntry *newEntry(ExifData *exif, ExifIfd ifd, ExifTag tag, ExifFormat format,
                    unsigned long components)
{
    ExifContent *content = exif->ifd[ifd];
    if (ExifEntry *old = exif_content_get_entry(content, tag))
        exif_content_remove_entry(content, old);

    ExifMem *mem = exif_mem_new_default();
    ExifEntry *entry = exif_entry_new_mem(mem);
    if (!entry) {
        exif_mem_unref(mem);
        return nullptr;
    }
    const unsigned int size = exif_format_get_size(format) * components;
    entry->data = static_cast<unsigned char *>(exif_mem_alloc(mem, size));
    if (!entry->data) {
        exif_entry_unref(entry);
        exif_mem_unref(mem);
        return nullptr;
    }
    entry->size = size;
    entry->tag = tag;
    entry->components = components;
    entry->format = format;
    exif_content_add_entry(content, entry);
    // The content holds it now.
    exif_entry_unref(entry);
    exif_mem_unref(mem);
    return entry;
}

bool setAscii(ExifData *exif, ExifIfd ifd, ExifTag tag, const char *text)
{
    const unsigned long length = std::strlen(text) + 1;
    ExifEntry *e = newEntry(exif, ifd, tag, EXIF_FORMAT_ASCII, length);
    if (!e)
        return false;
    std::memcpy(e->data, text, length);
    return true;
}

bool setRationals(ExifData *exif, ExifIfd ifd, ExifTag tag, const ExifRational *values, int count)
{
    const ExifEntry *e = newEntry(exif, ifd, tag, EXIF_FORMAT_RATIONAL, static_cast<unsigned long>(count));
    if (!e)
        return false;
    const ExifByteOrder order = exif_data_get_byte_order(exif);
    const size_t size = exif_format_get_size(EXIF_FORMAT_RATIONAL);
    for (int i = 0; i < count; ++i)
        exif_set_rational(e->data + size_t(i) * size, order, values[i]);
    return true;
}

bool setCoordinate(ExifData *exif, ExifTag refTag, ExifTag tag, double value,
                   const char *positive, const char *negative)
{
    const Dms dms = toDms(value);
    const ExifRational parts[] = {
        { dms.degrees, 1 },
        { dms.minutes, 1 },
        { dms.secondsE4, 10000 },
    };
    return setAscii(exif, EXIF_IFD_GPS, refTag, value < 0 ? negative : positive)
        && setRationals(exif, EXIF_IFD_GPS, tag, parts, 3);
}

bool setLocation(ExifData *exif, const Location &location)
{
    ExifEntry *version = newEntry(exif, EXIF_IFD_GPS, gpsTag(EXIF_TAG_GPS_VERSION_ID), EXIF_FORMAT_BYTE, 4);
    if (!version)
        return false;
    const unsigned char v[] = { 2, 2, 0, 0 };
    std::memcpy(version->data, v, sizeof v);

    if (!setCoordinate(exif, gpsTag(EXIF_TAG_GPS_LATITUDE_REF), gpsTag(EXIF_TAG_GPS_LATITUDE),
                       location.latitude, "N", "S")
        || !setCoordinate(exif, gpsTag(EXIF_TAG_GPS_LONGITUDE_REF), gpsTag(EXIF_TAG_GPS_LONGITUDE),
                          location.longitude, "E", "W")
        || !setAscii(exif, EXIF_IFD_GPS, gpsTag(EXIF_TAG_GPS_MAP_DATUM), "WGS-84"))
        return false;

    if (location.hasAltitude) {
        ExifEntry *ref = newEntry(exif, EXIF_IFD_GPS, gpsTag(EXIF_TAG_GPS_ALTITUDE_REF), EXIF_FORMAT_BYTE, 1);
        if (!ref)
            return false;
        ref->data[0] = location.altitude < 0 ? 1 : 0; // below sea level
        const ExifRational altitude = {
            static_cast<ExifLong>(std::lround(std::fabs(location.altitude) * 100.0)), 100
        };
        if (!setRationals(exif, EXIF_IFD_GPS, gpsTag(EXIF_TAG_GPS_ALTITUDE), &altitude, 1))
            return false;
    }
    return true;
}

bool setOrientation(ExifData *exif, int orientation)
{
    ExifEntry *e = newEntry(exif, EXIF_IFD_0, EXIF_TAG_ORIENTATION, EXIF_FORMAT_SHORT, 1);
    if (!e)
        return false;
    exif_set_short(e->data, exif_data_get_byte_order(exif), static_cast<ExifShort>(orientation));
    return true;
}

bool setExposureBias(ExifData *exif, double ev)
{
    if (!std::isfinite(ev) || std::fabs(ev) > 1000.0)
        return false;
    ExifEntry *e = newEntry(exif, EXIF_IFD_EXIF, EXIF_TAG_EXPOSURE_BIAS_VALUE, EXIF_FORMAT_SRATIONAL, 1);
    if (!e)
        return false;
    const ExifSRational bias = { static_cast<ExifSLong>(std::lround(ev * 100.0)), 100 };
    exif_set_srational(e->data, exif_data_get_byte_order(exif), bias);
    return true;
}

QByteArray save(ExifData *exif)
{
    unsigned char *data = nullptr;
    unsigned int size = 0;
    exif_data_save_data(exif, &data, &size);
    QByteArray out(reinterpret_cast<const char *>(data), qsizetype(size));
    std::free(data);
    return out;
}

} // namespace

QByteArray exifSegment(const QByteArray &jpeg)
{
    QList<Segment> list;
    int scan = 0;
    if (!segments(jpeg, list, scan))
        return QByteArray();
    const auto exif = std::find_if(list.cbegin(), list.cend(),
                                   [&jpeg](const Segment &s) { return isExif(jpeg, s); });
    return exif == list.cend() ? QByteArray() : jpeg.mid(exif->dataStart, exif->end - exif->dataStart);
}

QByteArray withExifSegment(const QByteArray &jpeg, const QByteArray &exif)
{
    if (exif.size() > kMaxSegmentPayload || !startsWith(exif, 0, int(exif.size()), kExifHeader, 6))
        return QByteArray();
    QList<Segment> list;
    int scan = 0;
    if (!segments(jpeg, list, scan))
        return QByteArray();

    const int length = int(exif.size()) + 2;
    QByteArray segment;
    segment.reserve(length + 2);
    segment.append(char(0xff));
    segment.append(char(0xe1));
    segment.append(char((length >> 8) & 0xff));
    segment.append(char(length & 0xff));
    segment.append(exif);

    // JFIF wants its APP0 first; everything else may follow.
    const bool jfifFirst = !list.isEmpty() && list.first().marker == 0xe0
        && startsWith(jpeg, list.first().dataStart, list.first().end, kJfifHeader, 5);

    QByteArray out;
    out.reserve(jpeg.size() + segment.size());
    out.append(jpeg.constData(), 2); // SOI
    if (!jfifFirst)
        out.append(segment);
    int copiedTo = 2;
    for (int i = 0; i < list.size(); ++i) {
        const Segment &s = list.at(i);
        // Anything between segments (fill bytes, standalone markers) stays.
        out.append(jpeg.constData() + copiedTo, s.start - copiedTo);
        if (!isExif(jpeg, s))
            out.append(jpeg.constData() + s.start, s.end - s.start);
        if (i == 0 && jfifFirst)
            out.append(segment);
        copiedTo = s.end;
    }
    out.append(jpeg.constData() + copiedTo, jpeg.size() - copiedTo);
    return out;
}

Dms toDms(double coordinate)
{
    // In ten-thousandths of a second, rounded once, so 59.99995" never shows up as 60".
    const long long total = std::llround(std::fabs(coordinate) * 3600.0 * 10000.0);
    Dms dms;
    dms.degrees = unsigned(total / (3600LL * 10000));
    dms.minutes = unsigned((total / (60LL * 10000)) % 60);
    dms.secondsE4 = unsigned(total % (60LL * 10000));
    return dms;
}

int orientationForRotation(int clockwise)
{
    switch (((clockwise % 360) + 360) % 360) {
    case 90:  return 6;
    case 180: return 3;
    case 270: return 8;
    default:  return 1;
    }
}

QByteArray edited(const QByteArray &exif, const Location *location, int orientation,
                  const double *exposureBias)
{
    ExifData *data = exif.isEmpty()
        ? exif_data_new()
        : exif_data_new_from_data(reinterpret_cast<const unsigned char *>(exif.constData()),
                                  static_cast<unsigned int>(exif.size()));
    if (!data)
        return QByteArray();
    if (exif.isEmpty()) {
        exif_data_set_byte_order(data, EXIF_BYTE_ORDER_INTEL);
        exif_data_fix(data);
    }

    bool ok = true;
    if (location)
        ok = setLocation(data, *location);
    if (ok && orientation >= 1 && orientation <= 8)
        ok = setOrientation(data, orientation);
    if (ok && exposureBias)
        ok = setExposureBias(data, *exposureBias);

    QByteArray out = ok ? save(data) : QByteArray();
    /* A HAL's embedded thumbnail can push the block past what one segment
     * holds; the picture matters more than its preview. */
    if (ok && out.size() > kMaxSegmentPayload && data->data) {
        std::free(data->data); // allocated by libexif's default (malloc) allocator
        data->data = nullptr;
        data->size = 0;
        out = save(data);
    }
    exif_data_unref(data);
    return out.size() > kMaxSegmentPayload ? QByteArray() : out;
}

} // namespace JpegExif
