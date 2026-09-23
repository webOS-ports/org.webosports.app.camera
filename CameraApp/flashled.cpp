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

#include "flashled.h"

#include <QDir>
#include <QFile>

FlashLed::FlashLed(QObject *parent)
    : QObject(parent),
      m_on(false)
{
    // Any LED whose function is "flash" (name is <colour>:flash or
    // <devicename>:<colour>:flash), first one wins.
    const QDir leds("/sys/class/leds");
    const QStringList names = leds.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString &name : names) {
        if (!name.endsWith(":flash") && !name.endsWith(":torch"))
            continue;
        QFile max(leds.filePath(name) + "/max_brightness");
        if (!max.open(QIODevice::ReadOnly))
            continue;
        m_maxBrightness = QString::fromLatin1(max.readAll()).trimmed();
        m_brightnessPath = leds.filePath(name) + "/brightness";
        break;
    }
}

FlashLed::~FlashLed()
{
    setOn(false);
}

bool FlashLed::available() const
{
    return !m_brightnessPath.isEmpty();
}

bool FlashLed::on() const
{
    return m_on;
}

void FlashLed::setOn(bool on)
{
    if (!available() || on == m_on)
        return;

    QFile brightness(m_brightnessPath);
    if (!brightness.open(QIODevice::WriteOnly))
        return;
    brightness.write(on ? m_maxBrightness.toLatin1() : QByteArray("0"));
    brightness.close();

    m_on = on;
    Q_EMIT onChanged();
}
