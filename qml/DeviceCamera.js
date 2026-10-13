.pragma library

/*
 * Per-device camera mounting, for a device whose camera HAL reports it wrongly.
 *
 * In degrees, on the same scale as PreferencesModel's backSensorRotation and
 * frontSensorRotation; -1 means "nothing known, use the default". This file
 * ships with no overrides. luneos-device-config's 36-camera-app generator
 * shadows it at boot from the adaptation's deviceinfo_camera_back_rotation and
 * deviceinfo_camera_front_rotation, so a device is described in its adaptation
 * and not here.
 */
var backRotation = -1;
var frontRotation = -1;
