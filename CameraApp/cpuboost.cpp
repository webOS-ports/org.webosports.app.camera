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

#include "cpuboost.h"

#include <QDir>
#include <QFile>

static const char *governorFile = "/scaling_governor";

static QString readGovernor(const QString &policy)
{
    QFile f(policy + governorFile);
    if (!f.open(QIODevice::ReadOnly))
        return QString();
    return QString::fromLatin1(f.readAll()).trimmed();
}

static void writeGovernor(const QString &policy, const QString &governor)
{
    QFile f(policy + governorFile);
    if (!f.open(QIODevice::WriteOnly))
        return;
    f.write(governor.toLatin1());
}

CpuBoost::CpuBoost(QObject *parent)
    : QObject(parent),
      m_active(false)
{
}

CpuBoost::~CpuBoost()
{
    setActive(false);
}

bool CpuBoost::active() const
{
    return m_active;
}

void CpuBoost::setActive(bool active)
{
    if (active == m_active)
        return;
    m_active = active;

    if (active) {
        const QDir cpufreq("/sys/devices/system/cpu/cpufreq");
        const QStringList policies = cpufreq.entryList(QStringList() << "policy*", QDir::Dirs);
        for (const QString &name : policies) {
            const QString policy = cpufreq.filePath(name);
            const QString current = readGovernor(policy);
            if (current.isEmpty() || current == "performance")
                continue;
            m_savedGovernors.insert(policy, current);
            writeGovernor(policy, "performance");
        }
    } else {
        for (auto it = m_savedGovernors.constBegin(); it != m_savedGovernors.constEnd(); ++it)
            writeGovernor(it.key(), it.value());
        m_savedGovernors.clear();
    }

    Q_EMIT activeChanged();
}
