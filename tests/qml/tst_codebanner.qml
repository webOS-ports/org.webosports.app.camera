import QtQuick
import QtQuick.Controls
import QtTest

import "../../qml/components"

/*
 * The QR code banner: which codes offer Open, and that an otpauth:// link
 * opens without its key being shown. Run by tests/run-qml-tests.sh.
 */
TestCase {
    id: test
    name: "CodeBanner"
    when: windowShown
    // Shown, so the buttons' visibility means something.
    visible: true
    width: 480
    height: 400

    CodeBanner {
        id: banner
        width: 460
    }

    SignalSpy {
        id: openSpy
        target: banner
        signalName: "openRequested"
    }

    function findButton(item, label) {
        if (!item)
            return null;
        if (item.text === label && item.clicked !== undefined)
            return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) {
            var found = findButton(kids[i], label);
            if (found)
                return found;
        }
        return null;
    }

    // What is drawn: the visible items' texts under the banner (its own
    // text property is the whole code, not something drawn).
    function shownTexts(item, out) {
        if (item !== banner && item.text !== undefined && item.visible && typeof item.text === "string")
            out.push(item.text);
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++)
            shownTexts(kids[i], out);
        return out;
    }

    function init() {
        openSpy.clear();
    }

    function test_open_offered_data() {
        return [
            { tag: "https", text: "https://webos-ports.org", open: true },
            { tag: "tel", text: "tel:+31201234567", open: true },
            { tag: "otpauth", text: "otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&issuer=Example", open: true },
            { tag: "OTPAUTH", text: "OTPAUTH://TOTP/x?secret=JBSWY3DPEHPK3PXP", open: true },
            { tag: "plain text", text: "Hello", open: false },
            { tag: "barcode", text: "8710398527370", open: false }
        ];
    }
    function test_open_offered(data) {
        banner.show(data.text, "QR-Code");
        compare(banner.isLink, data.open);
        compare(findButton(banner, "Open").visible, data.open);
        verify(findButton(banner, "Copy").visible);
    }

    function test_otpauth_opens_without_showing_the_key() {
        var link = "otpauth://totp/ACME%20Co:alice%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=ACME%20Co";
        banner.show(link, "QR-Code");
        var texts = shownTexts(banner, []).join("\n");
        verify(texts.indexOf("JBSWY3DPEHPK3PXP") < 0, texts);
        verify(texts.indexOf("ACME Co:alice@example.com") >= 0, texts);
        verify(texts.indexOf("Two-step verification") >= 0, texts);
        waitForRendering(banner);
        mouseClick(findButton(banner, "Open"));
        compare(openSpy.count, 1);
        // The whole link goes to the app that handles it.
        compare(openSpy.signalArguments[0][0], link);
        compare(banner.text, "");
    }

    function test_web_address_still_shown_as_is() {
        banner.show("https://webos-ports.org", "QR-Code");
        verify(shownTexts(banner, []).indexOf("https://webos-ports.org") >= 0);
    }
}
