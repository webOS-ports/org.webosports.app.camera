# Camera app tests

## QML tests (`qml/`, `screens/`), on the build host

    tests/run-qml-tests.sh [path to luneos-components]

`tests/qml/run-tests.sh` runs the same without the screenshots.

- `tst_codebanner.qml`: the QR code banner offers Open for web, mail,
  phone, SMS, map and otpauth:// links and not for plain text or a
  product barcode; an otpauth:// link (two-step verification) is shown
  as the account it is for, never with its key, and Open hands the whole
  link on.

- `screens/tst_screens.qml`: the whole app (`qml/main.qml`) on each of
  the screens in `PROFILES` - by default `mindphone` (480x800), `q25`
  (720x720), `tp` (1024x768) and `radon` (720x1600, with its notch and
  rounded corners), luneos-components' desktop profiles. It opens the
  photo and video modes, a recording, the code banner for a link and for
  an otpauth:// code, the preferences (top and bottom), the app menu and
  the camera switch notice, checks that the viewfinder fills the window and
  the shutter, gallery, mode, preferences and front / back buttons are
  shown, inside the window and clear of each other, and that the
  preferences do not scroll sideways. A photo taken for another app
  (`{"capture": ...}`): photos only, no gallery or mode button, the photo
  shown with Retake and Use Photo, Retake deleting it, Use Photo and Back
  relaunching the app with the photo or with none, no geotag, and the
  mode it was in afterwards. Each screen is saved as
  `build/test-output/ui/<profile>-<screen>.png`; on radon the parts the
  panel does not show are drawn over in red. The host has no camera: the
  phones' droid camera is stood in by the mock in `qml/imports` (a back
  camera with a second lens, a front one, flash and the HAL's picture
  controls), so the viewfinder stays black.

The profile is read once, as luneos-components' stand-ins load, so the
script runs `screens/` once per profile against a copy of
`LunaNext.Common` set to it. `PROFILES=q25` picks one, `SCREENS=` leaves
the screenshots out, `TESTS=` runs only them. Settings and recordings go
to a throwaway folder.

luneos-components needs its desktop build (`CONFIG+=desktop`) for the
LuneOS style.

## Unit tests (`unit/`)

gtest, for the C++ that needs no camera:

- `test_jpegexif.cpp`: finding, adding and replacing a JPEG's EXIF segment
  (and refusing broken files), degrees to EXIF degrees/minutes/seconds, the
  EXIF Orientation for a turn, and writing GPS and Orientation with libexif
  while keeping what the camera wrote. The last test checks that Qt turns a
  picture tagged this way.
- `test_imagetools.cpp`: the post-processing of a saved photo (turn, geotag,
  centre crop for a digital zoom), that a photo it refuses is left exactly as
  it was, and the hand-back from the worker thread.

Build with the app:

    cmake -DBUILD_TESTING=ON ...
    ninja camera-app-tests

It needs googletest in the sysroot. Run the x86-64 build on the build host
with its recipe sysroot:

    <sysroot>/usr/lib/ld-linux-x86-64.so.2 --library-path <sysroot>/usr/lib \
        ./camera-app-tests

## QML tests (`qml/`)

qmltestrunner cases for the QML, run on the build host:

- `tst_VideoLight.qml`: without the Android camera HAL, the flash LED is on
  while a recording runs with the video light on, follows the light's
  button, and is off when the recording stops, however it stops. The host
  has no camera, so it records the screen.
- `tst_FocusPoint.qml`: the tap-to-focus point rests in the middle of the
  view and follows its size until the user taps, stays where they tapped,
  and goes back to the middle on a reset.

The camera's own C++ (`CameraApp`, `LuneOS.Camera`) and QtSensors are
replaced by the mocks in `qml/imports/`; the rest comes from luneos-components
checked out next to this repository (see above for how to run them).

## Sanitizers and valgrind

The image toolchain ships no sanitizer runtimes, so build the tests with the
host compiler. ThreadSanitizer needs the suppressions in `tsan.supp`: Qt's
own synchronisation is invisible to it, and `tsan.supp` says which reports
that explains.

    TSAN_OPTIONS=suppressions=tests/tsan.supp ./camera-app-tests
    valgrind --leak-check=full --errors-for-leak-kinds=definite ./camera-app-tests

## Static analysis

`static-analysis.sh` runs gcc `-fanalyzer`, the clang analyzer, clang-tidy,
cppcheck and flawfinder over `CameraApp/jpegexif.cpp` and `imagetools.cpp`:

    APP_SYSROOT=<.../recipe-sysroot> LIBEXIF_INCLUDE=<libexif include dir> \
        tests/static-analysis.sh
