import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

RowLayout {

    property var _activeVehicle: globals.activeVehicle
    property var _cameraManager: _activeVehicle ? _activeVehicle.cameraManager : null
    property var _camera: _cameraManager ? _cameraManager.currentCameraInstance : null
    property bool _cameraIsRecording: _camera ? _camera.captureVideoState === 2 : false
    property bool _fallbackIsRecording: _cameraManager ? _cameraManager.mountIsRecording: false

    Item {
        id:                         statusCluster
        Layout.alignment:           Qt.AlignLeft | Qt.AlignBottom
        Layout.preferredWidth:      statusColumn.implicitWidth
        Layout.preferredHeight:     statusColumn.implicitHeight

        ColumnLayout {
            id:                 statusColumn
            anchors.left:       parent.left
            anchors.bottom:     parent.bottom
            spacing:            ScreenTools.defaultFontPixelHeight * 0.15

            CameraRecordingIndicator {
                id:                     recordingIndicator
                Layout.alignment:       Qt.AlignRight | Qt.AlignBottom
                Layout.rightMargin:     ScreenTools.defaultFontPixelWidth * 0.5
                visible:                _cameraIsRecording ? true : _fallbackIsRecording
            }

            TelemetryValuesBar {
                id:                     telemetryValuesBar
                extraWidth:             instrumentPanel.extraValuesWidth
                settingsGroup:          factValueGrid.telemetryBarSettingsGroup
                specificVehicleForCard: null // Tracks active vehicle
            }
        }
    }

    FlyViewInstrumentPanel {
        id:                 instrumentPanel
        Layout.alignment:   Qt.AlignBottom
        visible:            QGroundControl.corePlugin.options.flyView.showInstrumentPanel && _showSingleVehicleUI
    }
}
