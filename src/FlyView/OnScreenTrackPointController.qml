import QtQuick

import QGroundControl

// Sends MAV_CMD_TRACK_POINT with the tapped video position, normalized 0..1 (0,0 top left), black bars excluded.
// Enabled by globals.trackPointEnabled, toggled from the camera panel. While not active a tap does nothing here.
// The mouse functions are called by the FlyViewVideo mouse area, positions are in this item's coordinates.
Item {
    id: rootItem

    required property real videoWidth
    required property real videoHeight

    readonly property bool active: globals.trackPointEnabled

    // Point radius in item pixels, sent normalized to the video width
    readonly property real _pointRadius: 20

    function mouseClicked(mouseX, mouseY) {
        if (!active) {
            return
        }
        const vehicle = QGroundControl.multiVehicleManager.activeVehicle
        if (!vehicle) {
            return
        }
        if (videoWidth <= 0 || videoHeight <= 0) {
            return
        }
        vehicle.sendTrackPoint(_toVideoX(mouseX), _toVideoY(mouseY), Math.min(_pointRadius / videoWidth, 1.0), 0)
    }

    // Video image position normalized 0..1 (0,0 top left) from item position, black bars excluded.
    // Same math as OnScreenCameraTrackingController.mouseClicked.
    function _toVideoX(itemX) {
        const marginH = (rootItem.width - rootItem.videoWidth) / 2
        return Math.max(Math.min((itemX - marginH) / rootItem.videoWidth, 1.0), 0.0)
    }

    function _toVideoY(itemY) {
        const marginV = (rootItem.height - rootItem.videoHeight) / 2
        return Math.max(Math.min((itemY - marginV) / rootItem.videoHeight, 1.0), 0.0)
    }
}
