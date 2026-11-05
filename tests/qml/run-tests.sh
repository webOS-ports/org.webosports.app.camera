#!/bin/sh
#
# The QML test cases in this directory, without the screenshots; see
# ../run-qml-tests.sh, which this runs. COMPONENTS points at luneos-components
# (default: checked out next to this repository), QMLTESTRUNNER at a
# particular Qt's runner.
HERE=$(cd "$(dirname "$0")" && pwd)
SCREENS= exec "$HERE/../run-qml-tests.sh" "${COMPONENTS:-$HERE/../../../luneos-components}" "$@"
