/*
 * (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * svgcheck render  <svg> <scale> <out.png>
 * svgcheck compare <svg> <png> [x y w h] [diff.png]
 *
 * Renders with QSvgRenderer, as QML's Image does. "compare" renders the
 * SVG at the size of the PNG region and compares premultiplied RGBA - what
 * is seen once the image is drawn - and prints the largest difference, how
 * many pixels are within 0, 1, 2 and 4 levels, and the PSNR. The diff image
 * shows each pixel's largest difference times 8.
 */

#include <QtCore/QCoreApplication>
#include <QtCore/QTextStream>
#include <QtGui/QGuiApplication>
#include <QtGui/QImage>
#include <QtGui/QPainter>
#include <QtSvg/QSvgRenderer>

#include <algorithm>
#include <cmath>
#include <cstdlib>

static QImage renderSvg(const QString &path, int width, int height)
{
    QSvgRenderer renderer(path);
    QImage image(width, height, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    if (!renderer.isValid())
        return QImage();
    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    renderer.render(&painter, QRectF(0, 0, width, height));
    return image;
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    const QStringList a = app.arguments();
    QTextStream out(stdout);

    if (a.size() == 5 && a[1] == QLatin1String("render")) {
        QSvgRenderer probe(a[2]);
        if (!probe.isValid())
            return 2;
        const double scale = a[3].toDouble();
        const QSize size = probe.defaultSize();
        const QImage image = renderSvg(a[2], static_cast<int>(std::lround(size.width() * scale)),
                                       static_cast<int>(std::lround(size.height() * scale)));
        return image.save(a[4]) ? 0 : 1;
    }

    if ((a.size() == 4 || a.size() == 5 || a.size() == 8 || a.size() == 9) && a[1] == QLatin1String("compare")) {
        QImage original(a[3]);
        if (original.isNull())
            return 2;
        QRect region = original.rect();
        if (a.size() >= 8)
            region = QRect(a[4].toInt(), a[5].toInt(), a[6].toInt(), a[7].toInt());
        original = original.copy(region).convertToFormat(QImage::Format_ARGB32_Premultiplied);
        const QImage drawn = renderSvg(a[2], original.width(), original.height());
        if (drawn.isNull())
            return 3;
        const QString diffPath = (a.size() == 5 || a.size() == 9) ? a.last() : QString();
        QImage diff(original.size(), QImage::Format_RGB32);

        long long within[4] = {0, 0, 0, 0};
        int largest = 0;
        double squares = 0;
        const long long total = static_cast<long long>(original.width()) * original.height();
        for (int y = 0; y < original.height(); ++y) {
            for (int x = 0; x < original.width(); ++x) {
                const QRgb o = original.pixel(x, y);
                const QRgb d = drawn.pixel(x, y);
                const int dr = std::abs(qRed(o) - qRed(d));
                const int dg = std::abs(qGreen(o) - qGreen(d));
                const int db = std::abs(qBlue(o) - qBlue(d));
                const int da = std::abs(qAlpha(o) - qAlpha(d));
                const int m = std::max({dr, dg, db, da});
                largest = std::max(largest, m);
                squares += static_cast<double>(dr * dr + dg * dg + db * db + da * da) / 4.0;
                if (m <= 0) ++within[0];
                if (m <= 1) ++within[1];
                if (m <= 2) ++within[2];
                if (m <= 4) ++within[3];
                const int v = std::min(255, m * 8);
                diff.setPixel(x, y, qRgb(v, v, v));
            }
        }
        const double mse = squares / static_cast<double>(total);
        const double psnr = mse > 0 ? 10.0 * std::log10(255.0 * 255.0 / mse) : 99.0;
        auto pct = [total](long long n) { return QString::number(100.0 * static_cast<double>(n) / static_cast<double>(total), 'f', 2); };
        out << "max " << largest << "  exact " << pct(within[0]) << "%  <=1 " << pct(within[1])
            << "%  <=2 " << pct(within[2]) << "%  <=4 " << pct(within[3]) << "%  PSNR "
            << QString::number(psnr, 'f', 2) << " dB\n";
        if (!diffPath.isEmpty())
            diff.save(diffPath);
        return 0;
    }

    QTextStream(stderr) << "usage: svgcheck render <svg> <scale> <out.png>\n"
                           "       svgcheck compare <svg> <png> [x y w h] [diff.png]\n";
    return 2;
}
