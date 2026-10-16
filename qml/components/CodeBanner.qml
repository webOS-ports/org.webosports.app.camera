import QtQuick 2.6
import QtQuick.Controls 2.0
import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1

/*
 * Shows what a scanned QR code or barcode says, with what can be done with it:
 * open a web address, or copy the text.
 *
 * An otpauth:// link - the QR code a site shows to set up two-step
 * verification - opens too, in whatever app handles the scheme (the
 * Authenticator). Its key is not put on the screen: the banner shows the
 * account the link is for.
 */
Rectangle {
    id: banner

    property string text: ""
    property string format: ""
    readonly property bool isLink: /^(https?|mailto|tel|sms|geo|otpauth):/i.test(text)
    readonly property bool isOtpAuth: /^otpauth:/i.test(text)

    // "otpauth://totp/Example:alice?secret=..." as "Example:alice", without
    // the key.
    function otpAuthAccount(link) {
        var m = /^otpauth:\/\/[^\/?#]*\/([^?#]*)/i.exec(link);
        var name = "";
        if (m) {
            try {
                name = decodeURIComponent(m[1]);
            } catch (e) {
                name = m[1];
            }
        }
        return name !== "" ? name : qsTr("an account");
    }

    signal openRequested(string url)

    function show(text, format) {
        banner.text = text;
        banner.format = format;
        hideTimer.restart();
    }

    visible: text.length > 0
    height: column.height + Units.gu(2)
    radius: Units.gu(1)
    color: "#e0202020"
    border.color: "#60ffffff"
    border.width: 1

    Timer {
        id: hideTimer
        interval: 12000
        onTriggered: banner.text = ""
    }

    // QML has no clipboard API of its own; a text field does.
    TextEdit {
        id: clipboardHelper
        visible: false
    }

    Column {
        id: column
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            margins: Units.gu(1)
        }
        spacing: Units.gu(1)

        Text {
            width: parent.width
            color: "#a0a0a0"
            font.pixelSize: FontUtils.sizeToPixels("small")
            text: banner.isOtpAuth ? qsTr("Two-step verification")
                  : banner.format === "QR-Code" ? qsTr("QR code") : banner.format
        }

        Text {
            width: parent.width
            color: "white"
            font.pixelSize: FontUtils.sizeToPixels("medium")
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 3
            elide: Text.ElideRight
            text: banner.isOtpAuth ? qsTr("Codes for %1").arg(banner.otpAuthAccount(banner.text)) : banner.text
        }

        Row {
            anchors.right: parent.right
            spacing: Units.gu(1)

            Button {
                text: qsTr("Copy")
                onClicked: {
                    clipboardHelper.text = banner.text;
                    clipboardHelper.selectAll();
                    clipboardHelper.copy();
                    banner.text = "";
                }
            }
            Button {
                visible: banner.isLink
                text: qsTr("Open")
                LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                onClicked: {
                    banner.openRequested(banner.text);
                    banner.text = "";
                }
            }
            Button {
                text: qsTr("Close")
                onClicked: banner.text = ""
            }
        }
    }
}
