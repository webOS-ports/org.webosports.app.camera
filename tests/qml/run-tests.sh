#!/bin/sh
#
# Runs the QML test cases in this directory. The camera's own C++ (CameraApp,
# LuneOS.Camera) and QtSensors are replaced by the mocks under imports/; the
# rest comes from luneos-components and its mocks.
#
# Expects luneos-components checked out next to this repository. QMLTESTRUNNER
# may be set to pick a particular Qt's runner; COMPONENTS to point elsewhere
# for luneos-components.

set -e

HERE=$(cd "$(dirname "$0")" && pwd)
COMPONENTS=${COMPONENTS:-$HERE/../../../luneos-components}
QMLTESTRUNNER=${QMLTESTRUNNER:-qmltestrunner}

if [ ! -d "$COMPONENTS/test/imports" ]; then
    echo "luneos-components not found at $COMPONENTS -- set COMPONENTS=<path>" >&2
    exit 1
fi

QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen}
export QT_QPA_PLATFORM
# The tests' settings (PreferencesModel) and recordings go to a directory of
# their own, removed afterwards.
TMPDIR=$(mktemp -d)
XDG_CONFIG_HOME=$TMPDIR/config
export TMPDIR XDG_CONFIG_HOME
trap 'rm -rf "$TMPDIR"' EXIT

# Later imports win, so the mocks come last.
"$QMLTESTRUNNER" -input "$HERE" \
    -import "$COMPONENTS/modules" \
    -import "$COMPONENTS/test/imports" \
    -import "$HERE/imports" \
    "$@"
