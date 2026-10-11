import QtQuick 2.6
import QtQuick.Controls 2.2
import QtMultimedia

import QtQuick.Controls.LuneOS 2.0
import LunaNext.Common 0.1
import LuneOS.Camera 1.0
import LuneOS.Forms 1.0

import ".."
import "ModeLabels.js" as ModeLabels

/*
 * Camera preferences, in the look of the settings apps: the light header
 * with Done on the right, and groups of LuneOS.Forms rows. What the camera
 * offers is what is listed: the controls the camera in use does not have are
 * left out rather than shown and ignored.
 */
AppPage {
    id: page

    property PreferencesModel prefs
    signal closed()

    readonly property bool droid: DroidCameraFactory.available
    readonly property bool controls: droid && DroidCameraFactory.controlsReady
    readonly property var cameras: droid ? DroidCameraFactory.cameras() : []

    // Swallow everything: the viewfinder is underneath.
    MouseArea {
        parent: page
        anchors.fill: parent
        z: -1
    }

    // Done sits at the foot, as in every webOS preferences scene
    footer: DoneBar { onClicked: page.closed() }

    header: AppHeader {
        height: Units.gu(7.5)
        title: qsTr("Camera Preferences")
        icon: Qt.resolvedUrl("../../icon.png")
        compact: width < Units.gu(50)
    }

    SettingsPageContent {
        FormGroup {
            title: qsTr("Camera")

            LabelAndSelector {
                label: qsTr("Camera")
                // Only worth asking where a side has more than one.
                readonly property var sameSide: page.cameras.filter(function(c) {
                    return c.facing === (prefs.position === CameraDevice.FrontFace ? "front" : "back");
                })
                values: sameSide.map(function(c) { return c.index; })
                // The HAL lists the main camera of a side first.
                model: sameSide.map(function(c, i) { return i === 0 ? qsTr("Main") : qsTr("Lens %1").arg(i + 1); })
                visible: sameSide.length > 1
                // Unchosen (-1) is the main one.
                value: values.indexOf(prefs.droidCameraIndex) >= 0 ? prefs.droidCameraIndex : values[0]
                onChosen: (v) => prefs.droidCameraIndex = v
            }
            LabelAndSelector {
                label: qsTr("Self-timer")
                values: [0, 3, 5, 10, 15, 30, 60]
                model: [qsTr("Off"), qsTr("3 seconds"), qsTr("5 seconds"), qsTr("10 seconds"),
                        qsTr("15 seconds"), qsTr("30 seconds"), qsTr("1 minute")]
                value: prefs.selfTimerDelay
                onChosen: (v) => prefs.selfTimerDelay = v
            }
            LabelAndSelector {
                label: qsTr("Picture quality")
                // The JPEG quality droidcamsrc saves with; not offered elsewhere.
                visible: DroidCameraFactory.available
                values: [85, 90, 95]
                model: [qsTr("Normal"), qsTr("High"), qsTr("Best")]
                value: prefs.jpegQuality
                onChosen: (v) => prefs.jpegQuality = v
            }
            LabelAndSwitch {
                label: qsTr("Shutter sound")
                checked: prefs.playShutterSound
                onToggled: prefs.playShutterSound = checked
            }
            LabelAndSwitch {
                label: qsTr("Tag photos with location")
                checked: prefs.gpsEnabled
                onToggled: prefs.gpsEnabled = checked
            }
            LabelAndSwitch {
                label: qsTr("Grid")
                checked: prefs.gridEnabled
                onToggled: prefs.gridEnabled = checked
            }
            LabelAndSwitch {
                label: qsTr("Read QR codes and barcodes")
                checked: prefs.scanCodes
                onToggled: prefs.scanCodes = checked
            }
        }

        FormGroup {
            title: qsTr("Picture")
            visible: page.controls

            LabelAndSwitch {
                label: qsTr("HDR")
                visible: DroidCameraFactory.hdrSupported
                checked: prefs.hdrEnabled
                onToggled: prefs.hdrEnabled = checked
            }
            LabelAndSwitch {
                label: qsTr("Zero shutter lag")
                visible: DroidCameraFactory.zslSupported
                checked: prefs.zslEnabled
                onToggled: prefs.zslEnabled = checked
            }
            LabelAndSelector {
                label: qsTr("Scene")
                values: DroidCameraFactory.supportedSceneModes
                model: ModeLabels.labelsFor("scene", values)
                // A choice of one is no choice.
                visible: values.length > 1
                value: prefs.sceneMode
                onChosen: (v) => prefs.sceneMode = v
            }
            LabelAndSelector {
                label: qsTr("White balance")
                values: DroidCameraFactory.supportedWhiteBalanceModes
                model: ModeLabels.labelsFor("whiteBalance", values)
                visible: values.length > 1
                value: prefs.whiteBalanceMode
                onChosen: (v) => prefs.whiteBalanceMode = v
            }
            LabelAndSelector {
                label: qsTr("Effect")
                values: DroidCameraFactory.supportedColorTones
                model: ModeLabels.labelsFor("colorTone", values)
                visible: values.length > 1
                value: prefs.colorTone
                onChosen: (v) => prefs.colorTone = v
            }
            LabelAndSelector {
                label: qsTr("ISO")
                values: [0].concat(DroidCameraFactory.supportedIsoSpeeds.filter(function(v) { return v > 1; }))
                model: values.map(function(v) { return v === 0 ? qsTr("Auto") : "" + v; })
                visible: values.length > 1
                value: prefs.isoSpeed
                onChosen: (v) => prefs.isoSpeed = v
            }
            LabelAndSlider {
                label: qsTr("Exposure")
                visible: DroidCameraFactory.maximumExposureCompensation > DroidCameraFactory.minimumExposureCompensation
                from: DroidCameraFactory.minimumExposureCompensation
                to: DroidCameraFactory.maximumExposureCompensation
                // Only the values the camera takes: whole multiples of its step
                // (0.5 EV on the Q25), a third of an EV where it reports none.
                readonly property real evStep: DroidCameraFactory.exposureCompensationStep > 0
                                               ? DroidCameraFactory.exposureCompensationStep : 1 / 3
                function snap(v) { return Math.round(v / evStep) * evStep; }
                stepSize: evStep
                value: prefs.exposureCompensation
                format: function(v) {
                    var r = snap(v);
                    var tenths = Math.abs(r * 10 - Math.round(r * 10)) < 1e-6;
                    return (r > 0 ? "+" : "") + r.toFixed(tenths ? 1 : 2) + " EV";
                }
                onMoved: (v) => prefs.exposureCompensation = snap(v)
            }
            LabelAndSelector {
                label: qsTr("Focus")
                values: DroidCameraFactory.supportedFocusModes
                model: ModeLabels.labelsFor("focus", values)
                visible: values.length > 1
                value: prefs.focusMode
                onChosen: (v) => prefs.focusMode = v
            }
            LabelAndSelector {
                label: qsTr("Flicker reduction")
                values: DroidCameraFactory.supportedFlickerModes
                model: ModeLabels.labelsFor("flicker", values)
                visible: values.length > 1
                value: prefs.flickerMode
                onChosen: (v) => prefs.flickerMode = v
            }
        }

        ExplanationText {
            visible: page.droid && !page.controls
            text: qsTr("The picture settings appear once the camera has started.")
        }
    }
}
