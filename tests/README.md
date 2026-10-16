# Camera app tests

## QML tests (`qml/`), on the build host

    tests/run-qml-tests.sh [path to luneos-components]

- `tst_codebanner.qml`: the QR code banner offers Open for web, mail,
  phone, SMS, map and otpauth:// links and not for plain text or a
  product barcode; an otpauth:// link (two-step verification) is shown
  as the account it is for, never with its key, and Open hands the whole
  link on.

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
