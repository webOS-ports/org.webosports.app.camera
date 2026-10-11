import QtQuick 2.6
import QtQuick.Layouts 1.2
import QtMultimedia

import LunaNext.Common 0.1
import LuneOS.Camera 1.0

import ".."
import "ModeLabels.js" as ModeLabels

/*
 * Camera preferences, as a webOS preferences scene. What the camera offers is
 * what is listed: the controls the camera in use does not have are left out
 * rather than shown and ignored.
 */
Rectangle {
    id: page

    property PreferencesModel prefs
    signal closed()

    color: prefsTheme.backgroundColor

    PrefsTheme { id: prefsTheme }

    readonly property bool droid: DroidCameraFactory.available
    readonly property bool controls: droid && DroidCameraFactory.controlsReady
    readonly property var cameras: droid ? DroidCameraFactory.cameras() : []

    // Swallow everything: the viewfinder is underneath.
    MouseArea { anchors.fill: parent }

    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Units.gu(5)
        color: prefsTheme.headerColor

        Row {
            anchors.centerIn: parent
            spacing: Units.gu(0.8)

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: Units.gu(2.8)
                height: width
                fillMode: Image.PreserveAspectFit
                source: Qt.resolvedUrl("../../icon.png")
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: prefsTheme.textColor
                font.pixelSize: FontUtils.sizeToPixels("large")
                text: qsTr("Camera Preferences")
            }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: prefsTheme.rowDividerColor
        }
    }

    Flickable {
        anchors {
            top: header.bottom; left: parent.left; right: parent.right; bottom: doneBar.top
            margins: Units.gu(1.5)
        }
        contentHeight: column.height
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            spacing: Units.gu(1)

            PrefsGroup {
                Layout.fillWidth: true
                theme: prefsTheme
                title: qsTr("Camera")

                PrefsChoiceRow {
                    theme: prefsTheme
                    label: qsTr("Camera")
                    // Only worth asking where a side has more than one.
                    readonly property var sameSide: page.cameras.filter(function(c) {
                        return c.facing === (prefs.position === CameraDevice.FrontFace ? "front" : "back");
                    })
                    values: sameSide.map(function(c) { return c.index; })
                    // The HAL lists the main camera of a side first.
                    labels: sameSide.map(function(c, i) { return i === 0 ? qsTr("Main") : qsTr("Lens %1").arg(i + 1); })
                    visible: sameSide.length > 1
                    // Unchosen (-1) is the main one.
                    value: values.indexOf(prefs.droidCameraIndex) >= 0 ? prefs.droidCameraIndex : values[0]
                    onChosen: (v) => prefs.droidCameraIndex = v
                }
                PrefsChoiceRow {
                    theme: prefsTheme
                    label: qsTr("Self-timer")
                    values: [0, 3, 5, 10, 15, 30, 60]
                    labels: [qsTr("Off"), qsTr("3 seconds"), qsTr("5 seconds"), qsTr("10 seconds"),
                             qsTr("15 seconds"), qsTr("30 seconds"), qsTr("1 minute")]
                    value: prefs.selfTimerDelay
                    onChosen: (v) => prefs.selfTimerDelay = v
                }
                PrefsChoiceRow {
                    theme: prefsTheme
                    label: qsTr("Picture quality")
                    // The JPEG quality droidcamsrc saves with; not offered elsewhere.
                    visible: DroidCameraFactory.available
                    values: [85, 90, 95]
                    labels: [qsTr("Normal"), qsTr("High"), qsTr("Best")]
                    value: prefs.jpegQuality
                    onChosen: (v) => prefs.jpegQuality = v
                }
                PrefsSwitchRow {
                    theme: prefsTheme
                    label: qsTr("Shutter sound")
                    checked: prefs.playShutterSound
                    onToggled: (on) => prefs.playShutterSound = on
                }
                PrefsSwitchRow {
                    theme: prefsTheme
                    label: qsTr("Tag photos with location")
                    checked: prefs.gpsEnabled
                    onToggled: (on) => prefs.gpsEnabled = on
                }
                PrefsSwitchRow {
                    theme: prefsTheme
                    label: qsTr("Grid")
                    checked: prefs.gridEnabled
                    onToggled: (on) => prefs.gridEnabled = on
                }
                PrefsSwitchRow {
                    theme: prefsTheme
                    label: qsTr("Read QR codes and barcodes")
                    checked: prefs.scanCodes
                    onToggled: (on) => prefs.scanCodes = on
                }
            }

            PrefsGroup {
                Layout.fillWidth: true
                theme: prefsTheme
                title: qsTr("Picture")
                visible: page.controls

                PrefsSwitchRow {
                    theme: prefsTheme
                    label: qsTr("HDR")
                    visible: DroidCameraFactory.hdrSupported
                    checked: prefs.hdrEnabled
                    onToggled: (on) => prefs.hdrEnabled = on
                }
                PrefsSwitchRow {
                    theme: prefsTheme
                    label: qsTr("Zero shutter lag")
                    visible: DroidCameraFactory.zslSupported
                    checked: prefs.zslEnabled
                    onToggled: (on) => prefs.zslEnabled = on
                }
                PrefsChoiceRow {
                    theme: prefsTheme
                    label: qsTr("Scene")
                    values: DroidCameraFactory.supportedSceneModes
                    labels: ModeLabels.labelsFor("scene", values)
                    value: prefs.sceneMode
                    onChosen: (v) => prefs.sceneMode = v
                }
                PrefsChoiceRow {
                    theme: prefsTheme
                    label: qsTr("White balance")
                    values: DroidCameraFactory.supportedWhiteBalanceModes
                    labels: ModeLabels.labelsFor("whiteBalance", values)
                    value: prefs.whiteBalanceMode
                    onChosen: (v) => prefs.whiteBalanceMode = v
                }
                PrefsChoiceRow {
                    theme: prefsTheme
                    label: qsTr("Effect")
                    values: DroidCameraFactory.supportedColorTones
                    labels: ModeLabels.labelsFor("colorTone", values)
                    value: prefs.colorTone
                    onChosen: (v) => prefs.colorTone = v
                }
                PrefsChoiceRow {
                    theme: prefsTheme
                    label: qsTr("ISO")
                    values: [0].concat(DroidCameraFactory.supportedIsoSpeeds.filter(function(v) { return v > 1; }))
                    labels: values.map(function(v) { return v === 0 ? qsTr("Auto") : "" + v; })
                    value: prefs.isoSpeed
                    onChosen: (v) => prefs.isoSpeed = v
                }
                PrefsSliderRow {
                    theme: prefsTheme
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
                PrefsChoiceRow {
                    theme: prefsTheme
                    label: qsTr("Focus")
                    values: DroidCameraFactory.supportedFocusModes
                    labels: ModeLabels.labelsFor("focus", values)
                    value: prefs.focusMode
                    onChosen: (v) => prefs.focusMode = v
                }
                PrefsChoiceRow {
                    theme: prefsTheme
                    label: qsTr("Flicker reduction")
                    values: DroidCameraFactory.supportedFlickerModes
                    labels: ModeLabels.labelsFor("flicker", values)
                    value: prefs.flickerMode
                    onChosen: (v) => prefs.flickerMode = v
                }
            }

            PrefsGroup {
                Layout.fillWidth: true
                theme: prefsTheme
                visible: page.droid && !page.controls
                Text {
                    width: parent.width
                    height: Units.gu(5)
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    color: prefsTheme.secondaryTextColor
                    font.pixelSize: FontUtils.sizeToPixels("small")
                    text: qsTr("The picture settings appear once the camera has started.")
                }
            }
        }
    }

    PrefsDoneBar {
        id: doneBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        theme: prefsTheme
        onClicked: page.closed()
    }
}
