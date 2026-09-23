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

#ifndef FLASHLED_H
#define FLASHLED_H

#include <QObject>
#include <QString>

/*
 * The camera flash as a plain kernel LED. The libcamera path has no flash
 * control at all (no GstPhotography), but devices like the PineTab 2 expose
 * the flash LED as /sys/class/leds/<colour>:flash, which is enough for a
 * torch and for lighting a still capture.
 */
class FlashLed : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool on READ on WRITE setOn NOTIFY onChanged)

public:
    explicit FlashLed(QObject *parent = nullptr);
    ~FlashLed();

    bool available() const;
    bool on() const;
    void setOn(bool on);

Q_SIGNALS:
    void onChanged();

private:
    QString m_brightnessPath;
    QString m_maxBrightness;
    bool m_on;
};

#endif // FLASHLED_H
