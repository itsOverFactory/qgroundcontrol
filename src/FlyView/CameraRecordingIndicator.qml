import QtQuick
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    width: cameraVideoTime.width + ScreenTools.defaultFontPixelWidth * 2
    height: ScreenTools.defaultFontPixelHeight * 1.25

    property var _activeVehicle: globals.activeVehicle
    property var _cameraManager: _activeVehicle.cameraManager
    property var _camera: _cameraManager.currentCameraInstance
    property bool _videoCaptureIdle: _camera.captureVideoState === MavlinkCameraControlInterface.CaptureVideoStateIdle

    Rectangle {
        width: parent.width
        height: parent.height
        radius: ScreenTools.defaultFontPixelWidth / 2
        anchors.verticalCenter: parent.verticalCenter
        color: qgcPal.videoCaptureButtonColor
        opacity: 0.75

        QGCLabel {
            id: cameraVideoTime
            anchors.centerIn: parent
            text: _videoCaptureIdle ? "00:00:00" : _camera.recordTimeStr
            color: "white"
            font.bold: true
            font.pointSize: ScreenTools.defaultFontPointSize
        
            SequentialAnimation on opacity {
                running: root.visible
                loops: Animation.Infinite            
                NumberAnimation { from: 1.0; to: 0.35; duration: 1000; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.35; to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
            }
        }
    }
}