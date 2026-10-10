import QtQuick 2.0

import LunaNext.Common 0.1

Text {
    id: timeoutText
    opacity: 0
    text: timeOutTimer.nbRepeats
    font.pixelSize: Units.gu(6)
    font.bold: true
    // Over the viewfinder, whatever it shows.
    color: "white"
    style: Text.Outline
    styleColor: "#80000000"

    /// A countdown is under way.
    readonly property bool running: timeOutTimer.running

    function startTimeout(nbSeconds, cb) {
        if(nbSeconds===0) {
            cb();
        }
        else {
            console.log("starting a timeout of "+nbSeconds+" seconds")
            timeOutTimer.nbRepeats = nbSeconds
            timeOutTimer.callback = cb;
            timeoutTextAnimation.start();
            timeOutTimer.start();
        }
    }

    Timer {
        id: timeOutTimer
        property int nbRepeats: 0
        property var callback;
        interval: 1000
        running: false

        onTriggered: {
            console.log("timeout now "+nbRepeats+" seconds")
            nbRepeats = nbRepeats-1
            if(nbRepeats>0) {
                timeoutTextAnimation.start();
                start();
            }
            else
            {
                // do the action
                callback();
            }
        }
    }

    NumberAnimation { id: timeoutTextAnimation; target: timeoutText; properties: "opacity"; from: 1; to: 0; duration: 300 }
}
