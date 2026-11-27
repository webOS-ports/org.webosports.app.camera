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
            { tag: "export", text: "otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SGEV4YW1wbGU6YWxpY2VAZ29vZ2xlLmNvbRoHRXhhbXBsZTAC", open: true },
            { tag: "plain text", text: "Hello", open: false },
            { tag: "barcode", text: "8710398527370", open: false }
        ];
    }
    function test_open_offered(data) {
        banner.show(data.text, "QR-Code");
        compare(banner.isLink, data.open);
        var open = findButton(banner, "Open") || findButton(banner, "Import");
        compare(open.visible, data.open);
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

    // Google Authenticator's export: the published one-account sample, and
    // code 2 of 3 with three accounts, made with Google's protobuf library
    // (keys with "+" and "/" in their base64).
    readonly property string oneAccount: "otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SGEV4YW1wbGU6YWxpY2VAZ29vZ2xlLmNvbRoHRXhhbXBsZTAC"
    readonly property string threeAccounts: "otpauth-migration://offline?data=CjgKFPv%2F%2FgD7%2F%2F4A%2B%2F%2F%2BAPv%2F%2FgD7%2F%2F4AEhFhbGljZUBleGFtcGxlLmNvbRoHQUNNRSBDbyABKAEwAgopChT7%2F%2F4B%2B%2F%2F%2BAfv%2F%2FgH7%2F%2F4B%2B%2F%2F%2BARIDYm9iGgZHaXRIdWIgASgBMAIKLAoU%2B%2F%2F%2BAvv%2F%2FgL7%2F%2F4C%2B%2F%2F%2BAvv%2F%2FgISBWNhcm9sGgdFeGFtcGxlIAEoATACEAEYAyABKMC7%2BP%2F%2F%2F%2F%2F%2F%2FwE%3D"

    function test_export_counted_without_its_keys_data() {
        return [
            { tag: "one", link: oneAccount, shown: "1 account" },
            { tag: "three, code 2 of 3", link: threeAccounts, shown: "3 accounts, code 2 of 3" },
            { tag: "spaces for +", link: threeAccounts.replace(/%2B/g, " "), shown: "3 accounts, code 2 of 3" },
            { tag: "cut short", link: threeAccounts.slice(0, 120), shown: "An export that does not read" },
            { tag: "no data", link: "otpauth-migration://offline", shown: "An export that does not read" },
            { tag: "not base64", link: "otpauth-migration://offline?data=%21%21", shown: "An export that does not read" }
        ];
    }
    function test_export_counted_without_its_keys(data) {
        banner.show(data.link, "QR-Code");
        var texts = shownTexts(banner, []);
        verify(texts.indexOf(data.shown) >= 0, texts.join("\n"));
        verify(texts.indexOf("Two-step verification export") >= 0, texts.join("\n"));
        // Nothing of the link itself: names nor keys.
        var all = texts.join("\n");
        verify(all.indexOf("data=") < 0 && all.indexOf("Hello") < 0 && all.indexOf("alice") < 0, all);
    }

    function test_export_imports() {
        banner.show(threeAccounts, "QR-Code");
        waitForRendering(banner);
        verify(findButton(banner, "Open") === null, "Open, not Import");
        mouseClick(findButton(banner, "Import"));
        compare(openSpy.count, 1);
        compare(openSpy.signalArguments[0][0], threeAccounts);
        compare(banner.text, "");
    }
}
