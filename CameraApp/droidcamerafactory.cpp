/*
 * Copyright (C) 2026 Herrie
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

#include "droidcamerafactory.h"

#include <QFile>
#include <QDebug>

#if __has_include(<QtMultimedia/spi/qgstreamervideosource.h>)
#include <QtMultimedia/spi/qgstreamervideosource.h>
#define HAVE_QGSTREAMER_VIDEO_SOURCE 1
#endif

static const QLatin1String cGstDroidPlugin("/usr/lib/gstreamer-1.0/libgstdroid.so");

DroidCameraFactory::DroidCameraFactory(QObject *parent)
    : QObject(parent)
{
}

bool DroidCameraFactory::available() const
{
#ifdef HAVE_QGSTREAMER_VIDEO_SOURCE
    return QFile::exists(cGstDroidPlugin);
#else
    return false;
#endif
}

QObject *DroidCameraFactory::createVideoSource(int cameraDevice)
{
#ifdef HAVE_QGSTREAMER_VIDEO_SOURCE
    if (!available())
        return nullptr;

    // The capture session still points at the previous source here and
    // QMediaCaptureSession does not watch for its deletion, so a plain
    // delete would leave the session dispatching into freed memory when
    // the caller reassigns nativeVideoSource (it detaches the old source
    // first). deleteLater() runs after the caller's synchronous QML block
    // has completed that reassignment.
    if (m_videoSource)
        m_videoSource->deleteLater();
    m_videoSource = nullptr;

    // Park imgsrc and vidsrc on fakesinks so the viewfinder chain's tail is
    // the bin's only unlinked pad, which QGStreamerVideoSource ghosts as the
    // source pad. async=false because those pads only produce data during a
    // capture - a prerolling sink there would hold the whole pipeline in
    // PAUSED. The queue is load-bearing: droidcamsrc pushes sticky events
    // from its state-change context, and Qt activates the source from
    // inside a pad idle-probe on the ghost pad - an event push reaching
    // that pad from the state-change thread self-deadlocks. With the queue
    // in between, those pushes terminate at the queue sink and the queue's
    // own thread forwards them. Without a downstream that understands droid
    // queue buffers, droidcamsrc falls back to raw NV21 preview frames,
    // which the Qt GStreamer video sink accepts.
    // The NV21 capsfilter stays inside the bin so droidcamsrc's caps
    // negotiation - which runs while the ghost pad is still unlinked -
    // resolves to a real format and preview size before startPreview.
    // Started with the HAL's defaults instead, QCOM CamX rejects the
    // preview (error 0x1: opaque implementation-defined preview format).
    const QString desc = QStringLiteral(
        "droidcamsrc name=droidcam camera-device=%1 "
        "droidcam.imgsrc ! fakesink async=false "
        "droidcam.vidsrc ! fakesink async=false "
        "droidcam.vfsrc ! capsfilter caps=video/x-raw,format=NV21 ! "
        "queue ! videoconvert").arg(cameraDevice);

    qInfo() << "DroidCameraFactory: creating gst-droid video source:" << desc;
    m_videoSource = new QGStreamerVideoSource(desc, this);
    return m_videoSource;
#else
    Q_UNUSED(cameraDevice);
    return nullptr;
#endif
}
