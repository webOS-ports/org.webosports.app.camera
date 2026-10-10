.pragma library

// What the Android camera parameter values gst-droid uses are called in the
// preferences. A value missing here is shown as it is.
var labels = {
    flash: { "auto": qsTr("Auto"), "on": qsTr("On"), "off": qsTr("Off"), "red-eye": qsTr("Red-eye") },
    focus: { "auto": qsTr("Tap / on shutter"), "continuous": qsTr("Continuous"), "macro": qsTr("Macro"),
             "infinity": qsTr("Infinity"), "fixed": qsTr("Fixed"), "edof": qsTr("Extended depth"),
             "manual": qsTr("Manual") },
    whiteBalance: { "auto": qsTr("Auto"), "daylight": qsTr("Daylight"), "cloudy-daylight": qsTr("Cloudy"),
                    "twilight": qsTr("Twilight"), "incandescent": qsTr("Incandescent"),
                    "fluorescent": qsTr("Fluorescent"), "warm-fluorescent": qsTr("Warm fluorescent"),
                    "shade": qsTr("Shade"), "manual": qsTr("Manual") },
    scene: { "auto": qsTr("Off"), "asd": qsTr("Automatic"), "portrait": qsTr("Portrait"),
             "landscape": qsTr("Landscape"), "sports": qsTr("Sports"), "night": qsTr("Night"),
             "action": qsTr("Action"), "night-portrait": qsTr("Night portrait"), "theatre": qsTr("Theatre"),
             "beach": qsTr("Beach"), "snow": qsTr("Snow"), "sunset": qsTr("Sunset"),
             "steadyphoto": qsTr("Steady photo"), "fireworks": qsTr("Fireworks"), "party": qsTr("Party"),
             "candlelight": qsTr("Candlelight"), "barcode": qsTr("Barcode"), "backlight": qsTr("Backlight"),
             "flowers": qsTr("Flowers"), "AR": qsTr("AR") },
    colorTone: { "none": qsTr("None"), "mono": qsTr("Black & white"), "sepia": qsTr("Sepia"),
                 "negative": qsTr("Negative"), "vivid": qsTr("Vivid"), "solarize": qsTr("Solarize"),
                 "still-sky-blue": qsTr("Sky blue"), "still-grass-green": qsTr("Grass green"),
                 "still-skin-whiten-medium": qsTr("Skin whiten"), "posterize": qsTr("Posterize"),
                 "whiteboard": qsTr("Whiteboard"), "blackboard": qsTr("Blackboard"), "aqua": qsTr("Aqua"),
                 "emboss": qsTr("Emboss"), "sketch": qsTr("Sketch"), "neon": qsTr("Neon") },
    flicker: { "auto": qsTr("Auto"), "50hz": qsTr("50 Hz"), "60hz": qsTr("60 Hz"), "off": qsTr("Off") }
};

function labelsFor(kind, values) {
    var table = labels[kind] || {};
    return values.map(function(v) { return table[v] !== undefined ? table[v] : v; });
}
