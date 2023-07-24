/*
 * Copyright (C) 2012 Canonical, Ltd.
 *
 * Authors:
 *  Guenter Schwann <guenter.schwann@canonical.com>
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

#ifndef ADVANCEDCAMERASETTINGS_H
#define ADVANCEDCAMERASETTINGS_H

#include <QObject>
#include <QSharedPointer>
#include <QCamera>
#include <QImageCapture>
#include <QMediaCaptureSession>

class AdvancedCameraSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY (QMediaCaptureSession* captureSession READ captureSession WRITE setCaptureSession NOTIFY captureSessionChanged)
    Q_PROPERTY (QSize resolution READ resolution NOTIFY resolutionChanged)
    Q_PROPERTY (QSize imageCaptureResolution READ imageCaptureResolution)
    Q_PROPERTY (QSize videoRecorderResolution READ videoRecorderResolution)
    Q_PROPERTY (QSize maximumResolution READ maximumResolution NOTIFY maximumResolutionChanged)
    Q_PROPERTY (QSize fittingResolution READ fittingResolution NOTIFY fittingResolutionChanged)
    Q_PROPERTY (QStringList videoSupportedResolutions READ videoSupportedResolutions NOTIFY videoSupportedResolutionsChanged)
    Q_PROPERTY (bool hasFlash READ hasFlash NOTIFY hasFlashChanged)
    Q_PROPERTY (bool hdrEnabled READ hdrEnabled WRITE setHdrEnabled NOTIFY hdrEnabledChanged)
    Q_PROPERTY (bool hasHdr READ hasHdr NOTIFY hasHdrChanged)
    Q_PROPERTY (QImageCapture::Quality encodingQuality READ encodingQuality WRITE setEncodingQuality NOTIFY encodingQualityChanged)

public:
    explicit AdvancedCameraSettings(QObject *parent = 0);
    QMediaCaptureSession* captureSession() const;
    void setCaptureSession(QMediaCaptureSession* camera);
    QSize resolution() const;
    QSize imageCaptureResolution() const;
    QSize videoRecorderResolution() const;
    QSize maximumResolution() const;
    QSize fittingResolution() const;
    float getScreenAspectRatio() const;
    QStringList videoSupportedResolutions();
    bool hasFlash() const;
    bool hasHdr() const;
    bool hdrEnabled() const;
    void setHdrEnabled(bool enabled);
    QImageCapture::Quality encodingQuality() const;
    void setEncodingQuality(QImageCapture::Quality quality);
    void readCapabilities();

Q_SIGNALS:
    void captureSessionChanged();
    void resolutionChanged();
    void maximumResolutionChanged();
    void fittingResolutionChanged();
    void hasFlashChanged();
    void hasHdrChanged();
    void hdrEnabledChanged();
    void encodingQualityChanged();
    void videoSupportedResolutionsChanged();

private Q_SLOTS:
    void cameraStateChanged();
    void exposureValueChanged();
    void selectedDeviceChanged(int index);

private:
    inline QCamera* camera_() const;
    inline QImageCapture* imageCapture_() const;
    inline QMediaRecorder* mediaRecorder_() const;

    QSharedPointer<QMediaCaptureSession> m_captureSession;
    bool m_hdrEnabled;
    QStringList m_videoSupportedResolutions;
};

#endif // ADVANCEDCAMERASETTINGS_H
