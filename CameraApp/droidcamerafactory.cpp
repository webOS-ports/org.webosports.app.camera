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
#include <QFileInfo>
#include <QDir>
#include <QDebug>

#include <gst/gst.h>

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

    // A camera switch tears the old source (and any recording branch in
    // it) down wholesale; just drop our bookkeeping.
    if (m_recBin) {
        if (m_recTeePad)
            gst_object_unref(static_cast<GstPad *>(m_recTeePad));
        m_recBin = nullptr;
        m_recTeePad = nullptr;
        m_pendingVideoPath.clear();
        emit recordingChanged();
    }

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
        "droidcam.imgsrc ! appsink name=droidimgsink emit-signals=true "
        "async=false sync=false "
        "droidcam.vidsrc ! fakesink async=false "
        "droidcam.vfsrc ! capsfilter caps=video/x-raw,format=NV21 ! "
        "tee name=vftee ! queue ! videoconvert").arg(cameraDevice);

    qInfo() << "DroidCameraFactory: creating gst-droid video source:" << desc;
    auto *source = new QGStreamerVideoSource(desc, this);
    m_videoSource = source;

    // Full-resolution JPEGs from the HAL arrive on the imgsrc appsink when
    // a capture is triggered; the callback runs on a streaming thread.
    if (GstElement *bin = source->gstElement()) {
        GstElement *sink = gst_bin_get_by_name(GST_BIN(bin), "droidimgsink");
        if (sink) {
            g_signal_connect(sink, "new-sample",
                G_CALLBACK(+[](GstElement *appsink, gpointer user) -> GstFlowReturn {
                    auto *self = static_cast<DroidCameraFactory *>(user);
                    GstSample *sample = nullptr;
                    g_signal_emit_by_name(appsink, "pull-sample", &sample);
                    if (!sample)
                        return GST_FLOW_OK;
                    GstBuffer *buffer = gst_sample_get_buffer(sample);
                    QByteArray data;
                    GstMapInfo map;
                    if (buffer && gst_buffer_map(buffer, &map, GST_MAP_READ)) {
                        data = QByteArray(reinterpret_cast<const char *>(map.data),
                                          static_cast<int>(map.size));
                        gst_buffer_unmap(buffer, &map);
                    }
                    gst_sample_unref(sample);
                    if (!data.isEmpty())
                        QMetaObject::invokeMethod(self, [self, data] {
                            self->saveImage(data);
                        }, Qt::QueuedConnection);
                    return GST_FLOW_OK;
                }), this);
            gst_object_unref(sink);
        }
    }

    return m_videoSource;
#else
    Q_UNUSED(cameraDevice);
    return nullptr;
#endif
}

bool DroidCameraFactory::takePicture(const QString &filePath)
{
#ifdef HAVE_QGSTREAMER_VIDEO_SOURCE
    auto *source = qobject_cast<QGStreamerVideoSource *>(m_videoSource);
    if (!source || !source->gstElement()) {
        emit imageCaptureError(QStringLiteral("no active droid camera"));
        return false;
    }

    GstElement *cam = gst_bin_get_by_name(GST_BIN(source->gstElement()),
                                          "droidcam");
    if (!cam) {
        emit imageCaptureError(QStringLiteral("droidcamsrc not found"));
        return false;
    }

    m_pendingImagePath = filePath;
    g_signal_emit_by_name(cam, "start-capture");
    gst_object_unref(cam);
    return true;
#else
    Q_UNUSED(filePath);
    return false;
#endif
}

void DroidCameraFactory::saveImage(const QByteArray &data)
{
    const QString path = m_pendingImagePath;
    m_pendingImagePath.clear();
    if (path.isEmpty())
        return;

    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly) || f.write(data) != data.size()) {
        emit imageCaptureError(QStringLiteral("cannot write %1").arg(path));
        return;
    }
    f.close();
    qInfo() << "DroidCameraFactory: saved capture to" << path;
    emit imageSaved(path);
}

bool DroidCameraFactory::recording() const
{
    return m_recBin != nullptr;
}

bool DroidCameraFactory::startRecording(const QString &filePath)
{
#ifdef HAVE_QGSTREAMER_VIDEO_SOURCE
    auto *source = qobject_cast<QGStreamerVideoSource *>(m_videoSource);
    if (!source || !source->gstElement() || m_recBin) {
        emit videoCaptureError(QStringLiteral("cannot start recording"));
        return false;
    }

    GstElement *bin = source->gstElement();
    GstElement *tee = gst_bin_get_by_name(GST_BIN(bin), "vftee");
    if (!tee) {
        emit videoCaptureError(QStringLiteral("viewfinder tee not found"));
        return false;
    }

    QDir().mkpath(QFileInfo(filePath).absolutePath());

    // MPEG-4 part 2 in software: the hardware droidvenc only accepts
    // droid-buffer memory from droidcamsrc's video mode, which conflicts
    // with the raw viewfinder Qt needs. Encode at quarter pixels to keep
    // the CPU load sane. AAC audio from PulseAudio when available.
    const QString avDesc = QStringLiteral(
        "queue name=recentry max-size-buffers=30 leaky=downstream ! "
        "videoconvert ! videoscale ! "
        "video/x-raw,format=I420,width=1344,height=672 ! "
        "avenc_mpeg4 bitrate=8000000 ! mp4mux name=recmux ! "
        "filesink name=recsink async=false location=\"%1\" "
        "pulsesrc ! audioconvert ! avenc_aac ! queue ! recmux.")
        .arg(filePath);
    const QString vDesc = QStringLiteral(
        "queue name=recentry max-size-buffers=30 leaky=downstream ! "
        "videoconvert ! videoscale ! "
        "video/x-raw,format=I420,width=1344,height=672 ! "
        "avenc_mpeg4 bitrate=8000000 ! mp4mux name=recmux ! "
        "filesink name=recsink async=false location=\"%1\"")
        .arg(filePath);

    GError *error = nullptr;
    // Video-only for now: the PulseAudio branch connects but never delivers
    // samples in the app context, and an audio trak that got EOS without
    // data makes mp4mux write a corrupt moov (mdhd timescale 0, empty
    // STSD). Re-enable avDesc once the in-app pulsesrc path is fixed.
    Q_UNUSED(avDesc);
    GstElement *rec = gst_parse_bin_from_description(
        vDesc.toUtf8().constData(), TRUE, &error);
    if (!rec) {
        qWarning() << "DroidCameraFactory: recording bin failed:"
                   << (error ? error->message : "unknown");
        g_clear_error(&error);
        gst_object_unref(tee);
        emit videoCaptureError(QStringLiteral("cannot build recorder"));
        return false;
    }
    gst_element_set_name(rec, "recbin");

    gst_bin_add(GST_BIN(bin), rec);
    if (!gst_element_sync_state_with_parent(rec)) {
        gst_bin_remove(GST_BIN(bin), rec);
        gst_object_unref(tee);
        emit videoCaptureError(QStringLiteral("cannot start recorder"));
        return false;
    }

    GstPad *teepad = gst_element_request_pad_simple(tee, "src_%u");
    GstPad *sinkpad = gst_element_get_static_pad(rec, "sink");
    const bool linked =
        teepad && sinkpad && gst_pad_link(teepad, sinkpad) == GST_PAD_LINK_OK;
    if (sinkpad)
        gst_object_unref(sinkpad);
    gst_object_unref(tee);
    if (!linked) {
        gst_element_set_state(rec, GST_STATE_NULL);
        gst_bin_remove(GST_BIN(bin), rec);
        emit videoCaptureError(QStringLiteral("cannot link recorder"));
        return false;
    }

    m_recBin = rec;
    m_recTeePad = teepad;
    m_pendingVideoPath = filePath;
    qInfo() << "DroidCameraFactory: recording to" << filePath;
    emit recordingChanged();
    return true;
#else
    Q_UNUSED(filePath);
    return false;
#endif
}

void DroidCameraFactory::stopRecording()
{
#ifdef HAVE_QGSTREAMER_VIDEO_SOURCE
    if (!m_recBin || !m_recTeePad)
        return;

    auto *teepad = static_cast<GstPad *>(m_recTeePad);

    // Block the tee branch, unlink it, then run EOS through the encoder so
    // mp4mux writes its moov atom before the branch is torn down.
    gst_pad_add_probe(teepad, GST_PAD_PROBE_TYPE_IDLE,
        [](GstPad *pad, GstPadProbeInfo *, gpointer user) -> GstPadProbeReturn {
            auto *self = static_cast<DroidCameraFactory *>(user);
            auto *rec = static_cast<GstElement *>(self->m_recBin);

            GstPad *sinkpad = gst_element_get_static_pad(rec, "sink");
            gst_pad_unlink(pad, sinkpad);

            // EOS into the video branch; the audio source (if any) gets its
            // own EOS so both tracks finalize.
            GstElement *audiosrc =
                gst_bin_get_by_name(GST_BIN(rec), "pulsesrc0");
            if (audiosrc) {
                gst_element_send_event(audiosrc, gst_event_new_eos());
                gst_object_unref(audiosrc);
            }
            gst_pad_send_event(sinkpad, gst_event_new_eos());
            gst_object_unref(sinkpad);

            // Watch for EOS reaching the file sink.
            GstElement *filesink = gst_bin_get_by_name(GST_BIN(rec), "recsink");
            GstPad *fspad = gst_element_get_static_pad(filesink, "sink");
            gst_pad_add_probe(fspad,
                static_cast<GstPadProbeType>(GST_PAD_PROBE_TYPE_EVENT_DOWNSTREAM),
                [](GstPad *, GstPadProbeInfo *info, gpointer u) -> GstPadProbeReturn {
                    if (GST_EVENT_TYPE(GST_PAD_PROBE_INFO_EVENT(info)) !=
                        GST_EVENT_EOS)
                        return GST_PAD_PROBE_OK;
                    auto *fself = static_cast<DroidCameraFactory *>(u);
                    QMetaObject::invokeMethod(fself, [fself] {
                        fself->finishRecording();
                    }, Qt::QueuedConnection);
                    return GST_PAD_PROBE_REMOVE;
                }, self, nullptr);
            gst_object_unref(fspad);
            gst_object_unref(filesink);
            return GST_PAD_PROBE_REMOVE;
        }, this, nullptr);
#endif
}

void DroidCameraFactory::finishRecording()
{
#ifdef HAVE_QGSTREAMER_VIDEO_SOURCE
    auto *source = qobject_cast<QGStreamerVideoSource *>(m_videoSource);
    auto *rec = static_cast<GstElement *>(m_recBin);
    auto *teepad = static_cast<GstPad *>(m_recTeePad);
    if (!rec)
        return;

    gst_element_set_state(rec, GST_STATE_NULL);
    if (source && source->gstElement()) {
        GstElement *bin = source->gstElement();
        gst_bin_remove(GST_BIN(bin), rec);
        GstElement *tee = gst_bin_get_by_name(GST_BIN(bin), "vftee");
        if (tee) {
            gst_element_release_request_pad(tee, teepad);
            gst_object_unref(tee);
        }
    }
    gst_object_unref(teepad);

    const QString path = m_pendingVideoPath;
    m_pendingVideoPath.clear();
    m_recBin = nullptr;
    m_recTeePad = nullptr;
    emit recordingChanged();
    qInfo() << "DroidCameraFactory: saved recording to" << path;
    emit videoSaved(path);
#endif
}
