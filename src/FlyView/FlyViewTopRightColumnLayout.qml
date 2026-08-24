import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap

ColumnLayout {
    spacing: ScreenTools.defaultFontPixelHeight / 2

    TerrainProgress {
        Layout.fillWidth: true
    }

    // We use a Loader to load the photoVideoControlComponent only when camera controls are enabled and 
    // we have an active vehicle + camera manager.
    // This make it easier to implement PhotoVideoControl without having to check for the mavlink camera
    // to be null all over the place
    Loader {
        property bool showCameraControls: QGroundControl.settingsManager.flyViewSettings.showCameraControls.value
        property bool canShowCameraControls: showCameraControls && globals.activeVehicle && globals.activeVehicle.cameraManager

        id:                 photoVideoControlLoader
        Layout.alignment:   Qt.AlignRight
        visible:            canShowCameraControls
        sourceComponent:    canShowCameraControls ? photoVideoControlComponent : undefined

        property real rightEdgeCenterInset: visible ? parent.width - x : 0

        Component {
            id: photoVideoControlComponent

            PhotoVideoControl {
            }
        }
    }
}
