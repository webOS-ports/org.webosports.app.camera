/*
 * Copyright (C) 2016 Canonical, Ltd.
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

#include "storagelocations.h"

#include <QString>
#include <QDir>
#include <QCoreApplication>
#include <QStandardPaths>
#include <QStorageInfo>

StorageLocations::StorageLocations(QObject *parent) : QObject(parent)
{
    updateRemovableStorageInfo();
}

QString StorageLocations::picturesLocation() const
{
    QString location = CAMERA_OUTPUT_DIR;
    QDir dir;
    dir.mkpath(location);
    return location;
}

QString StorageLocations::videosLocation() const
{
    QString location = CAMERA_OUTPUT_DIR;
    QDir dir;
    dir.mkpath(location);
    return location;
}

QString StorageLocations::temporaryLocation() const
{
    QStringList locations = QStandardPaths::standardLocations(QStandardPaths::TempLocation);
    if (locations.isEmpty()) {
        return QString();
    }
    QString location = locations.at(0);
    QDir dir;
    dir.mkpath(location);
    return location;
}

QString StorageLocations::removableStorageLocation() const
{
    return m_removableStorageLocation;
}

QString StorageLocations::removableStoragePicturesLocation() const
{
    QString storageLocation = removableStorageLocation();
    if (storageLocation.isEmpty()) {
        return QString();
    }

    QStringList locations = QStandardPaths::standardLocations(QStandardPaths::PicturesLocation);
    QString pictureDir = QString(locations.at(0)).split("/").value(3);
    if (pictureDir.isEmpty()){
        return QString();
    }
    QString location = storageLocation + "/" + pictureDir + "/" + QCoreApplication::applicationName();
    QDir dir;
    dir.mkpath(location);
    return location;
}

QString StorageLocations::removableStorageVideosLocation() const
{
    QString storageLocation = removableStorageLocation();
    if (storageLocation.isEmpty()) {
        return QString();
    }

    QStringList locations = QStandardPaths::standardLocations(QStandardPaths::MoviesLocation);
    QString movieDir = QString(locations.at(0)).split("/").value(3);
    if (movieDir.isEmpty()){
        return QString();
    }
    QString location = storageLocation + "/" + movieDir + "/" + QCoreApplication::applicationName();
    QDir dir;
    dir.mkpath(location);
    return location;
}

bool StorageLocations::removableStoragePresent() const
{
    return !removableStorageLocation().isEmpty();
}

void StorageLocations::updateRemovableStorageInfo()
{
    QString removableStorageLocation;
    QString mediaRoot("/media/" + qgetenv("USER"));

    QDir mediaRootDir(mediaRoot);
    if (!mediaRootDir.exists()) return; // no need to get further, it's bound to fail...

    // FIXME: calling QStorageInfo::mountedVolumes() is very slow (80ms on krillin)
    Q_FOREACH(QStorageInfo volume, QStorageInfo::mountedVolumes()) {
         if (volume.rootPath().startsWith(mediaRoot) &&
             volume.isValid() && volume.isReady()) {
            removableStorageLocation = volume.rootPath();
         }
    }

    if (m_removableStorageLocation != removableStorageLocation) {
        m_removableStorageLocation = removableStorageLocation;
        Q_EMIT removableStoragePresentChanged();
    }
}
