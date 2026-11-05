#!/bin/sh
# Runs the QML tests on the build host, with luneos-components' modules and
# desktop stand-ins, and the camera's own mocks (tests/qml/imports) for its
# C++ (CameraApp, LuneOS.Camera) and QtSensors:
#
#   tests/qml/      the logic and single parts, once
#   tests/screens/  the whole app, once per screen in PROFILES - by default
#                   the mindphone, the Q25, the TouchPad and the FuriPhone
#                   FLX1s (radon) - with each screen saved as
#                   build/test-output/ui/<profile>-<screen>.png
#
#   tests/run-qml-tests.sh [path to luneos-components [qmltestrunner arguments]]
#
# The stand-ins read their profile (and with it the grid unit) once, as they
# load, and qmltestrunner takes no --profile, so each screen runs against a
# copy of LunaNext.Common whose default profile is that screen. Settings and
# recordings go to a throwaway folder, removed afterwards.
#
#   PROFILES=q25 tests/run-qml-tests.sh       one screen only
#   SCREENS= tests/run-qml-tests.sh           no screenshots
#   TESTS= tests/run-qml-tests.sh             only the screenshots
set -e
cd "$(dirname "$0")/.."
LC=${1:-${COMPONENTS:-../luneos-components}}
[ $# -gt 0 ] && shift
if [ ! -d "$LC/test/imports" ]; then
    echo "luneos-components not found at $LC -- pass its path" >&2
    exit 1
fi
LC=$(cd "$LC" && pwd)
PROFILES=${PROFILES:-mindphone q25 tp radon}
TESTS=${TESTS-tests/qml}
SCREENS=${SCREENS-tests/screens/tst_screens.qml}

CONF=$(mktemp -d)
trap 'rm -rf "$CONF"' EXIT
mkdir -p build/test-output/ui

run() {
    rm -rf "$CONF/config" "$CONF/tmp"
    mkdir -p "$CONF/config" "$CONF/tmp" "$CONF/Videos" "$CONF/Pictures"
    # Qt Multimedia records to the Videos folder when not told where.
    printf 'XDG_VIDEOS_DIR="%s"\nXDG_PICTURES_DIR="%s"\n' "$CONF/Videos" "$CONF/Pictures" \
        > "$CONF/config/user-dirs.dirs"
    TMPDIR=$CONF/tmp XDG_CONFIG_HOME=$CONF/config QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen} \
    QT_QUICK_CONTROLS_STYLE=QtQuick.Controls.LuneOS \
        ${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner} \
        -import "$LC/modules" -import "$LC/test/imports" "$@"
}

status=0
for t in $TESTS; do
    # Later imports win, so the mocks come last.
    run -import tests/qml/imports -input "$t" "$@" || status=1
done
[ -n "$SCREENS" ] || exit $status
for profile in $PROFILES; do
    common=$CONF/profile-$profile/LunaNext/Common
    mkdir -p "$common"
    cp "$LC"/test/imports/LunaNext/Common/* "$common/"
    sed -i "s/^var defaultProfile = .*/var defaultProfile = \"$profile\";/" "$common/SettingsStub.js"
    if ! grep -q "^var defaultProfile = \"$profile\";" "$common/SettingsStub.js"; then
        echo "could not select profile $profile in SettingsStub.js" >&2
        status=1
        continue
    fi
    for t in $SCREENS; do
        run -import "$CONF/profile-$profile" -import tests/qml/imports -input "$t" "$@" || status=1
    done
done
exit $status
