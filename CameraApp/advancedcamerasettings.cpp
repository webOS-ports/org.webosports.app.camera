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

#include "advancedcamerasettings.h"

#include <QDebug>
#include <QGuiApplication>
#include <QScreen>

#include <QCamera>
#include <QCameraDevice>
#include <QImageCapture>
#include <QMediaRecorder>

#include <cmath>

#define SUPPORT_HDR_LUNEOS 0

#if SUPPORT_HDR_LUNEOS
// Definition of this enum value is duplicated in qtubuntu-camera
static const QCamera::ExposureMode ExposureHdr = static_cast<QCamera::ExposureMode>(QCamera::ExposureBarcode + 1);
#endif

AdvancedCameraSettings::AdvancedCameraSettings(QObject *parent) :
    QObject(parent),
    m_captureSession(nullptr),
    m_hdrEnabled(false)
{
}

QMediaCaptureSession* AdvancedCameraSettings::captureSession() const
{
    return m_captureSession.get();
}

void AdvancedCameraSettings::setCaptureSession(QMediaCaptureSession *captureSession)
{
    if (captureSession != m_captureSession.get()) {
        m_captureSession.reset(captureSession);

        if (camera_()) {
            selectedDeviceChanged(0);
            cameraStateChanged();
        }

        Q_EMIT captureSessionChanged();
    }
}

inline QCamera* AdvancedCameraSettings::camera_() const
{
    return m_captureSession ? m_captureSession->camera() : nullptr;
}

inline QImageCapture* AdvancedCameraSettings::imageCapture_() const
{
    return m_captureSession ? m_captureSession->imageCapture() : nullptr;
}

inline QMediaRecorder* AdvancedCameraSettings::mediaRecorder_() const
{
    return m_captureSession ? m_captureSession->recorder() : nullptr;
}

void AdvancedCameraSettings::selectedDeviceChanged(int index)
{
    Q_UNUSED(index);

    m_videoSupportedResolutions.clear();

    Q_EMIT resolutionChanged();
    Q_EMIT maximumResolutionChanged();
    Q_EMIT fittingResolutionChanged();
    Q_EMIT hasFlashChanged();
    Q_EMIT videoSupportedResolutionsChanged();
}

void AdvancedCameraSettings::readCapabilities()
{
    QCamera *camera = camera_();
    if (camera) {
        QObject::connect(camera, &QCamera::cameraFormatChanged, this, &AdvancedCameraSettings::resolutionChanged);
        QObject::connect(camera, &QCamera::cameraFormatChanged, this, &AdvancedCameraSettings::maximumResolutionChanged);
        QObject::connect(camera, &QCamera::cameraFormatChanged, this, &AdvancedCameraSettings::fittingResolutionChanged);
        QObject::connect(camera, &QCamera::activeChanged, this, &AdvancedCameraSettings::cameraStateChanged);

        QObject::connect(camera, &QCamera::exposureModeChanged, this, &AdvancedCameraSettings::exposureValueChanged);
    }

#if SUPPORT_HDR_LUNEOS
    if (m_camera) {
         QCamera::ExposureMode exposureMode = m_hdrEnabled ? ExposureHdr : QCamera::ExposureAuto;
        m_camera->setExposureMode(exposureMode);
        QObject::connect(m_camera.get(), &QCamera::exposureModeChanged, this, &AdvancedCameraSettings::exposureValueChanged);
    }
#endif

    m_videoSupportedResolutions.clear();

    Q_EMIT resolutionChanged();
    Q_EMIT maximumResolutionChanged();
    Q_EMIT fittingResolutionChanged();
    Q_EMIT hasFlashChanged();
    Q_EMIT hasHdrChanged();
    Q_EMIT hdrEnabledChanged();
    Q_EMIT encodingQualityChanged();
    Q_EMIT videoSupportedResolutionsChanged();
}

void AdvancedCameraSettings::cameraStateChanged()
{
    QCamera *camera = camera_();
    if (camera && camera->isActive()) {
        readCapabilities();
    }
}

QSize AdvancedCameraSettings::resolution() const
{
    QCamera *camera = camera_();
    if (camera) {
        return camera->cameraFormat().resolution();
    }

    return QSize();
}

QSize AdvancedCameraSettings::imageCaptureResolution() const
{
    QImageCapture* imageCapture = imageCapture_();
    if (imageCapture != 0) {
        return imageCapture->resolution();
    }

    return QSize();
}

QSize AdvancedCameraSettings::videoRecorderResolution() const
{
    QMediaRecorder* recorder = mediaRecorder_();
    if (recorder) {
        return recorder->videoResolution();
    }

    return QSize();
}

QSize AdvancedCameraSettings::maximumResolution() const
{
    QCamera *camera = camera_();
    if (camera) {
        QList<QSize> sizes = camera->cameraDevice().photoResolutions();

        QSize maximumSize;
        long maximumPixels = 0;

        QList<QSize>::const_iterator it = sizes.begin();
        while (it != sizes.end()) {
            const long pixels = ((long)((*it).width())) * ((long)((*it).height()));
            if (pixels > maximumPixels) {
                maximumSize = *it;
                maximumPixels = pixels;
            }
            ++it;
        }

        return maximumSize;
    }

    return QSize();
}

float AdvancedCameraSettings::getScreenAspectRatio() const
{
    float screenAspectRatio;
    QScreen *screen = QGuiApplication::primaryScreen();
    Q_ASSERT(screen);
    const int kScreenWidth = screen->geometry().width();
    const int kScreenHeight = screen->geometry().height();
    Q_ASSERT(kScreenWidth > 0 && kScreenHeight > 0);

    screenAspectRatio = (kScreenWidth > kScreenHeight) ?
        ((float)kScreenWidth / (float)kScreenHeight) : ((float)kScreenHeight / (float)kScreenWidth);

    return screenAspectRatio;
}

QSize AdvancedCameraSettings::fittingResolution() const
{
    QList<float> prioritizedAspectRatios;
    prioritizedAspectRatios.append(getScreenAspectRatio());
    const float backAspectRatios[4] = { 16.0f/9.0f, 3.0f/2.0f, 4.0f/3.0f, 5.0f/4.0f };
    for (int i=0; i<4; ++i) {
        if (!prioritizedAspectRatios.contains(backAspectRatios[i])) {
            prioritizedAspectRatios.append(backAspectRatios[i]);
        }
    }

    QCamera *camera = camera_();
    if (camera) {
        QList<QSize> sizes = camera->cameraDevice().photoResolutions();

        QSize optimalSize;
        long optimalPixels = 0;

        if (!sizes.empty()) {
            float aspectRatio;

            // Loop over all reported camera resolutions until we find the highest
            // one that matches the current prioritized aspect ratio. If it doesn't
            // find one on the current aspect ration, it selects the next ratio and
            // tries again.
            QList<float>::const_iterator ratioIt = prioritizedAspectRatios.begin();
            while (ratioIt != prioritizedAspectRatios.end()) {
                // Don't update the aspect ratio when using this function for finding
                // the optimal thumbnail size as it will affect the preview window size
                aspectRatio = (*ratioIt);

                QList<QSize>::const_iterator it = sizes.begin();
                while (it != sizes.end()) {
                    const float ratio = (float)(*it).width() / (float)(*it).height();
                    const long pixels = ((long)((*it).width())) * ((long)((*it).height()));
                    const float EPSILON = 0.02;
                    if (fabs(ratio - aspectRatio) < EPSILON && pixels > optimalPixels) {
                        optimalSize = *it;
                        optimalPixels = pixels;
                    }
                    ++it;
                }
                if (optimalPixels > 0) break;
                ++ratioIt;
            }
        }

        return optimalSize;
    }

    return QSize();
}

QStringList AdvancedCameraSettings::videoSupportedResolutions()
{
    QCamera *camera = camera_();
    if (camera) {
        if (m_videoSupportedResolutions.isEmpty()) {
            QList<QCameraFormat> videoFormats = camera->cameraDevice().videoFormats();
            QCameraDevice::Position cameraPosition = camera->cameraDevice().position();

            for (auto &format: videoFormats) {
                QSize size = format.resolution();

                // Workaround for bug https://bugs.launchpad.net/ubuntu/+source/libhybris/+bug/1408650
                // When using the front camera on krillin, using resolution 640x480 does
                // not work properly and results in stretched videos. Remove it from
                // the list of supported resolutions.
                if (cameraPosition == QCameraDevice::FrontFace &&
                    size.width() == 640 && size.height() == 480) {
                    continue;
                }
                m_videoSupportedResolutions.append(QString("%1x%2").arg(size.width()).arg(size.height()));
            }
        }
        return m_videoSupportedResolutions;
    } else {
        return QStringList();
    }
}


bool AdvancedCameraSettings::hasFlash() const
{
    QCamera *camera = camera_();
    if (camera) {
        return camera->isFlashModeSupported(QCamera::FlashAuto)
            && camera->isFlashModeSupported(QCamera::FlashOff)
            && camera->isFlashModeSupported(QCamera::FlashOn);
    } else {
        return false;
    }
}

bool AdvancedCameraSettings::hasHdr() const
{
#if SUPPORT_HDR_LUNEOS
    if (m_camera) {
        if (m_camera->exposureMode() == ExposureHdr) {
            return true;
        }
    }
#endif

    return false;
}

bool AdvancedCameraSettings::hdrEnabled() const
{
    return m_hdrEnabled;
}

void AdvancedCameraSettings::setHdrEnabled(bool enabled)
{
#if SUPPORT_HDR_LUNEOS
    if (enabled != m_hdrEnabled) {
        m_hdrEnabled = enabled;

        if (m_camera) {
            QCamera::ExposureMode exposureMode = m_hdrEnabled ? ExposureHdr : QCamera::ExposureAuto;
            m_camera->setExposureMode(exposureMode);
        } else {
            Q_EMIT hdrEnabledChanged();
        }
    }
#endif
}

QImageCapture::Quality AdvancedCameraSettings::encodingQuality() const
{
    QImageCapture* imageCapture = imageCapture_();
    if (imageCapture) {
        return imageCapture->quality();
    } else {
        return QImageCapture::NormalQuality;
    }
}

void AdvancedCameraSettings::setEncodingQuality(QImageCapture::Quality quality)
{
    QImageCapture* imageCapture = imageCapture_();
    if (imageCapture) {
        imageCapture->setQuality(quality);
    }
}

void AdvancedCameraSettings::exposureValueChanged()
{
#if SUPPORT_HDR_LUNEOS
    if (m_camera && m_camera->exposureMode() == ExposureHdr) {
        Q_EMIT hdrEnabledChanged();
    }
#endif
}
