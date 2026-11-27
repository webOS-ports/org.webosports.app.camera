LuneOS Camera
==================

Camera application for LuneOS

Summary
-------
The LuneOS camera app, which will be the default camera app for the WebOS Ports LuneOS project.

Note: this app reuses some bits of Ubuntu's camera app: https://launchpad.net/camera-app (rev 683)

Usage with QtCreator
--------------------

In the Project properties, in the Run section:
 - set the executable to "qmlscene"
 - set the arguments to: qml/main.qml -I %{buildDir} -I %{sourceDir}/../luneos-components/modules -I %{sourceDir}/../luneos-components/test/imports
 - set the execution directory to %{sourceDir}


Launch parameters
-----------------

- `{"scan": true}`: opened to read a code (the Authenticator's "Scan a QR
  code" sends it). The back camera, taking photos, and codes are read even
  with "Read QR codes and barcodes" off. The first two-step verification
  code seen - an otpauth:// link, or an otpauth-migration:// one from
  another authenticator's export - goes straight to the app that handles
  it, with no banner, and the request is done; any other code gets the
  banner as usual. Opened for itself, the Camera never does that: a
  two-step code waits in the banner for Open or Import. The back camera
  and photo mode are kept for next time, as the Front / Back button keeps
  its choice.
- `{"capture": {"returnTo": "<app id>"}}`: take a photo for that app
  (Messaging's "Take Photo" sends it). Photos only, with no way off to
  Photos; the photo is shown with Retake and Use Photo. Use Photo relaunches
  the app with `{"cameraCapture": {"path": "<the .jpg>"}}` and closes the
  camera; Back (from the viewfinder) relaunches it with
  `{"cameraCapture": {"cancelled": true}}` and closes it. A photo taken
  again is deleted; the one kept stays in the photo folder. It is not
  geotagged, as it is about to be sent to someone. Photo or video mode is
  as it was afterwards.

Tests
-----

On the build host, with luneos-components checked out next to this
repository:

    tests/run-qml-tests.sh [path to luneos-components]

runs the QML tests and then the app at the mindphone (480x800), Q25
(720x720), TouchPad (1024x768) and FuriPhone FLX1s (radon, 720x1600 with a
notch and rounded corners) sizes, saving each screen as
`build/test-output/ui/<profile>-<screen>.png`. `PROFILES` picks other
luneos-components profiles. See tests/README.md, also for the C++ unit
tests.
