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

#ifndef CPUBOOST_H
#define CPUBOOST_H

#include <QMap>
#include <QObject>
#include <QString>

/*
 * Pins the CPU frequency while the camera runs.
 *
 * The PineTab 2 resets when its CPU frequency is changed under the load of
 * libcamera's software ISP (see the kernel side of this work); with the
 * frequency pinned it does not. Until that is fixed in the kernel, hold the
 * "performance" governor on every cpufreq policy while a camera is active
 * and put the previous governors back afterwards. Silently does nothing
 * where the sysfs files are not writable.
 */
class CpuBoost : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)

public:
    explicit CpuBoost(QObject *parent = nullptr);
    ~CpuBoost();

    bool active() const;
    void setActive(bool active);

Q_SIGNALS:
    void activeChanged();

private:
    QMap<QString, QString> m_savedGovernors; // policy path -> governor
    bool m_active;
};

#endif // CPUBOOST_H
