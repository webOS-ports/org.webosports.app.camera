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
 * account the link is for. So does an otpauth-migration:// link, one code
 * of another authenticator's export (Google Authenticator's "Transfer
 * accounts"): the banner says how many accounts are in it and which code
 * of the export it is, and Import hands it to the Authenticator, which
 * shows them and asks before adding any.
 */
Rectangle {
    id: banner

    property string text: ""
    property string format: ""
    readonly property bool isLink: /^(https?|mailto|tel|sms|geo|otpauth|otpauth-migration):/i.test(text)
    readonly property bool isOtpAuth: /^otpauth:/i.test(text)
    readonly property bool isMigration: /^otpauth-migration:/i.test(text)

    // An export code's "data": a protobuf MigrationPayload, base64 in the
    // URL. Only counted - its accounts (field 1) and batch_size (3) and
    // batch_index (4) - never decoded further: the keys stay where they
    // are. { accounts, index, size }, or null when it does not read.
    function migrationSummary(link) {
        var m = /[?&]data=([^&#]*)/.exec(link);
        if (!m)
            return null;
        var b64;
        try {
            b64 = decodeURIComponent(m[1].replace(/ /g, "+"));
        } catch (e) {
            return null;
        }
        b64 = b64.replace(/-/g, "+").replace(/_/g, "/").replace(/=+$/, "");
        var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        var bytes = [];
        var bits = 0, value = 0;
        for (var i = 0; i < b64.length; i++) {
            var v = alphabet.indexOf(b64.charAt(i));
            if (v < 0)
                return null;
            value = ((value << 6) | v) & 0xffff;
            bits += 6;
            if (bits >= 8) {
                bits -= 8;
                bytes.push((value >> bits) & 0xff);
            }
        }
        var pos = 0;
        function varint() {
            var result = 0, scale = 1;
            for (var n = 0; n < 10; n++) {
                if (pos >= bytes.length)
                    return -1;
                var b = bytes[pos++];
                result += (b & 0x7f) * scale;
                if (!(b & 0x80))
                    return result;
                scale *= 128;
            }
            return -1;
        }
        var out = { accounts: 0, index: 0, size: 1 };
        while (pos < bytes.length) {
            var key = varint();
            if (key < 0)
                return null;
            var field = Math.floor(key / 8), wire = key % 8;
            if (wire === 0) {
                var n = varint();
                if (n < 0)
                    return null;
                if (field === 3)
                    out.size = n;
                else if (field === 4)
                    out.index = n;
            } else if (wire === 2) {
                var length = varint();
                if (length < 0 || pos + length > bytes.length)
                    return null;
                pos += length;
                if (field === 1)
                    out.accounts++;
            } else if (wire === 1 || wire === 5) {
                pos += wire === 1 ? 8 : 4;
                if (pos > bytes.length)
                    return null;
            } else {
                return null;
            }
        }
        if (out.size < 1 || out.index >= out.size)
            out = { accounts: out.accounts, index: 0, size: 1 };
        return out;
    }

    // "3 accounts, code 2 of 4", without a key.
    function migrationText(link) {
        var s = migrationSummary(link);
        if (!s)
            return qsTr("An export that does not read");
        var text = s.accounts === 1 ? qsTr("1 account") : qsTr("%1 accounts").arg(s.accounts);
        if (s.size > 1)
            text += qsTr(", code %1 of %2").arg(s.index + 1).arg(s.size);
        return text;
    }

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
                  : banner.isMigration ? qsTr("Two-step verification export")
                  : banner.format === "QR-Code" ? qsTr("QR code") : banner.format
        }

        Text {
            width: parent.width
            color: "white"
            font.pixelSize: FontUtils.sizeToPixels("medium")
            // A link breaks after a "/" where it can, mid-word only
            // where a part is longer than the line.
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: 3
            elide: Text.ElideRight
            text: banner.isOtpAuth ? qsTr("Codes for %1").arg(banner.otpAuthAccount(banner.text))
                  : banner.isMigration ? banner.migrationText(banner.text)
                  : banner.text
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
                text: banner.isMigration ? qsTr("Import") : qsTr("Open")
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
