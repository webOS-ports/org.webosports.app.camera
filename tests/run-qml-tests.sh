#!/bin/sh
# Runs the QML tests on the build host (tests/qml), with luneos-components'
# modules and desktop stand-ins.
#
#   tests/run-qml-tests.sh [path to luneos-components [qmltestrunner arguments]]
set -e
cd "$(dirname "$0")/.."
LC=${1:-../luneos-components}
[ $# -gt 0 ] && shift
QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen} \
QT_QUICK_CONTROLS_STYLE=QtQuick.Controls.LuneOS \
    ${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner} \
    -import "$LC/modules" -import "$LC/test/imports" \
    -input tests/qml "$@"
