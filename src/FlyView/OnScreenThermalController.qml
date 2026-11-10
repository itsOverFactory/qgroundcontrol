import QtQuick

import QGroundControl
import QGroundControl.Controls

// Thermal camera temperatures drawn over the Fly View video:
//  - point temperature: tap the video (CAMERA_POINT_TEMPERATURE)
//  - region temperature: press and hold, then drag a rectangle (CAMERA_REGION_TEMPERATURE)
//  - frame max and min from the thermal range stream (CAMERA_THERMAL_RANGE), toggled from the camera panel
// A tap on a shown point or region clears it.
// The mouse functions are called by the FlyViewVideo mouse area, positions are in this item's coordinates.
Item {
    id: rootItem

    required property var  camera
    required property real videoWidth
    required property real videoHeight

    // true if the current camera is thermal capable (CAMERA_CAP_FLAGS_HAS_THERMAL_RANGE in its CAMERA_INFORMATION).
    // Point and region temperatures are only requested from a thermal capable camera.
    readonly property bool thermalCapable: !!camera && camera.hasThermalRange

    onThermalCapableChanged: {
        if (!thermalCapable) {
            pointTemperature.clear()
            regionTemperature.clear()
        }
    }

    // Smallest region selection that is sent, in pixels. Anything smaller is treated as no selection.
    readonly property real _minRegionSize: 10

    // true if the tap was on a shown point or region temperature, which is then cleared
    function clearAt(mouseX, mouseY) {
        if (pointTemperature.isAt(mouseX, mouseY)) {
            pointTemperature.clear()
            return true
        }
        if (regionTemperature.isAt(mouseX, mouseY)) {
            regionTemperature.clear()
            return true
        }
        return false
    }

    // Tap: request the point temperature. One point at a time, replaces the shown one.
    function mouseClicked(mouseX, mouseY) {
        if (!thermalCapable) {
            return
        }
        pointTemperature.clear()

        // This only works if there is a vehicle because we use FCU as a camera/gimbal component.
        const vehicle = QGroundControl.multiVehicleManager.activeVehicle
        if (!vehicle) {
            return
        }
        if (videoWidth <= 0 || videoHeight <= 0) {
            return
        }
        vehicle.requestPointTemperature(_toVideoX(mouseX), _toVideoY(mouseY), true)
        pointRefresh.requestSent()
    }

    // Press and hold, then drag: select a region. The region temperature is requested on release.
    function mouseHoldStart(mouseX, mouseY) {
        regionSelection.start(mouseX, mouseY)
    }

    function mouseHoldPositionChanged(mouseX, mouseY) {
        regionSelection.update(mouseX, mouseY)
    }

    function mouseHoldEnd() {
        regionSelection.finish()
    }

    // Video image position normalized 0..1 (0,0 top left) <-> item position, black bars excluded.
    // Same math as OnScreenCameraTrackingController.mouseClicked.
    function _toVideoX(itemX) {
        const marginH = (rootItem.width - rootItem.videoWidth) / 2
        return Math.max(Math.min((itemX - marginH) / rootItem.videoWidth, 1.0), 0.0)
    }

    function _toVideoY(itemY) {
        const marginV = (rootItem.height - rootItem.videoHeight) / 2
        return Math.max(Math.min((itemY - marginV) / rootItem.videoHeight, 1.0), 0.0)
    }

    function _fromVideoX(videoX) {
        const marginH = (rootItem.width - rootItem.videoWidth) / 2
        return marginH + videoX * rootItem.videoWidth
    }

    function _fromVideoY(videoY) {
        const marginV = (rootItem.height - rootItem.videoHeight) / 2
        return marginV + videoY * rootItem.videoHeight
    }

    // Tap target for clearing a temperature marker: what is drawn, grown by this margin so a finger can hit it
    readonly property real _temperatureTapMargin: ScreenTools.defaultFontPixelHeight / 2

    // true if the point is inside the rectangle grown by _temperatureTapMargin
    function _inRect(pointX, pointY, rectX, rectY, rectWidth, rectHeight) {
        const insideX = pointX >= rectX - _temperatureTapMargin && pointX <= rectX + rectWidth + _temperatureTapMargin
        const insideY = pointY >= rectY - _temperatureTapMargin && pointY <= rectY + rectHeight + _temperatureTapMargin
        return insideX && insideY
    }

    // Point and region temperature refresh, two timers:
    //  - nextRefreshTimer: 1s after a reply, emits refresh() so the overlay requests again
    //  - replyTimeoutTimer: 3s after that request with no reply (a dropped reply), sets stale and emits refresh() again.
    //    3s is past the command ack timeout, so a request is never sent while the previous one waits (duplicate command).
    // The overlay only accepts a reply while waitingForReply is true, so a reply that arrives after cancel() does not
    // bring the overlay back.
    component TemperatureRefresh: Item {
        id: temperatureRefresh

        property bool stale:            false   // the last refresh got no reply
        property bool waitingForReply:  false   // a request was sent and its reply has not arrived

        signal refresh()

        // the overlay sent its first request
        function requestSent() {
            waitingForReply = true
        }

        // the overlay accepted the reply
        function replyReceived() {
            waitingForReply = false
            stale = false
            replyTimeoutTimer.stop()
            nextRefreshTimer.restart()
        }

        function cancel() {
            waitingForReply = false
            stale = false
            replyTimeoutTimer.stop()
            nextRefreshTimer.stop()
        }

        function _requestAgain() {
            waitingForReply = true
            replyTimeoutTimer.restart()
            temperatureRefresh.refresh()
        }

        Timer {
            id:             nextRefreshTimer
            interval:       1000
            repeat:         false
            onTriggered:    temperatureRefresh._requestAgain()
        }

        Timer {
            id:             replyTimeoutTimer
            interval:       3000
            repeat:         false
            onTriggered: {
                temperatureRefresh.stale = true
                temperatureRefresh._requestAgain()
            }
        }
    }

    // Temperature in app settings units on a dark background
    component TemperatureLabel: Rectangle {
        id: temperatureLabel

        property real   temperature:    0       // degC
        property string prefix:         ""

        width:          labelText.contentWidth + ScreenTools.defaultFontPixelWidth
        height:         labelText.contentHeight
        radius:         ScreenTools.defaultFontPixelWidth / 2
        color:          Qt.rgba(0, 0, 0, 0.6)
        border.width:   2
        border.color:   "transparent"   // set to tie the label to a ring's color

        QGCLabel {
            id:                 labelText
            anchors.centerIn:   parent
            color:              "white"
            text:               (temperatureLabel.prefix ? temperatureLabel.prefix + " " : "") +
                                QGroundControl.unitsConversion.celsiusToAppSettingsTemperatureUnits(temperatureLabel.temperature).toFixed(1) +
                                " °" + QGroundControl.unitsConversion.appSettingsTemperatureUnitsString
        }
    }

    // Ring centered on the item position, optionally with its temperature label to the right.
    // The label is kept inside boundsWidth x boundsHeight (same coordinates as x, y): to the left of the ring near the
    // right edge, shifted up or down near the top or bottom. The ring stays on the point.
    component TemperatureMarker: Item {
        id: temperatureMarker

        property real   temperature:    0       // degC
        property string prefix:         ""
        property color  markerColor:    "white"
        property bool   showLabel:      true
        property real   boundsWidth:    0
        property real   boundsHeight:   0

        readonly property real _markerSize: ScreenTools.defaultFontPixelHeight

        readonly property alias label: markerLabel     // for tap targets, position is relative to the ring center

        Rectangle {
            x:              -width / 2
            y:              -height / 2
            width:          temperatureMarker._markerSize
            height:         width
            radius:         width / 2
            color:          "transparent"
            border.color:   temperatureMarker.markerColor
            border.width:   2
        }

        TemperatureLabel {
            id:             markerLabel
            visible:        temperatureMarker.showLabel
            x: {
                // right of the ring, or left of it when the right side has no room
                const fitsRight = temperatureMarker.x + temperatureMarker._markerSize + width <= temperatureMarker.boundsWidth
                const labelX = fitsRight ? temperatureMarker._markerSize : -temperatureMarker._markerSize - width
                // keep inside the bounds, label position is relative to the ring center
                const minX = -temperatureMarker.x
                const maxX = temperatureMarker.boundsWidth - temperatureMarker.x - width
                return Math.max(minX, Math.min(maxX, labelX))
            }
            y: {
                // vertically centered on the ring, kept inside the bounds
                const minY = -temperatureMarker.y
                const maxY = temperatureMarker.boundsHeight - temperatureMarker.y - height
                return Math.max(minY, Math.min(maxY, -height / 2))
            }
            temperature:    temperatureMarker.temperature
            prefix:         temperatureMarker.prefix
        }
    }

    // Point temperature measured by the camera (CAMERA_POINT_TEMPERATURE), shown at the measured point
    Item {
        id:         pointTemperature
        visible:    pointTemperature._shown
        opacity:    pointRefresh.stale ? 0.4 : 1   // faded: last refresh got no reply

        property bool _shown:       false
        property real _pointX:      0   // normalized 0..1, 0 is left
        property real _pointY:      0   // normalized 0..1, 0 is top
        property real _temperature: 0   // degC

        function show(pointX, pointY, temperature) {
            if (!pointRefresh.waitingForReply) {
                return  // cleared while the request was outstanding: ignore the reply
            }
            pointRefresh.replyReceived()
            _pointX = pointX
            _pointY = pointY
            _temperature = temperature
            _shown = true
        }

        function clear() {
            _shown = false
            pointRefresh.cancel()
        }

        // Request the shown point again so the temperature follows the scene
        TemperatureRefresh {
            id: pointRefresh
            onRefresh: {
                const vehicle = QGroundControl.multiVehicleManager.activeVehicle
                if (vehicle) {
                    vehicle.requestPointTemperature(pointTemperature._pointX, pointTemperature._pointY, false)
                }
            }
        }

        // true if the tap at mouseX, mouseY (video coordinates) is on the ring or its label, see _temperatureTapMargin
        function isAt(mouseX, mouseY) {
            if (!_shown) {
                return false
            }
            const ringSize = pointMarker._markerSize
            const label = pointMarker.label
            const onRing = rootItem._inRect(mouseX, mouseY, pointMarker.x - ringSize / 2, pointMarker.y - ringSize / 2, ringSize, ringSize)
            const onLabel = rootItem._inRect(mouseX, mouseY, pointMarker.x + label.x, pointMarker.y + label.y, label.width, label.height)
            return onRing || onLabel
        }

        TemperatureMarker {
            id:             pointMarker
            x:              rootItem._fromVideoX(pointTemperature._pointX)
            y:              rootItem._fromVideoY(pointTemperature._pointY)
            boundsWidth:    rootItem.width
            boundsHeight:   rootItem.height
            temperature:    pointTemperature._temperature
        }
    }

    // Rectangle drawn while selecting a region (press and hold, then drag), in item coordinates
    Rectangle {
        id:             regionSelection
        visible:        false
        color:          "transparent"
        border.color:   "white"
        border.width:   1

        property real _startX: 0
        property real _startY: 0

        function start(itemX, itemY) {
            _startX = itemX
            _startY = itemY
            update(itemX, itemY)
            visible = true
        }

        function update(itemX, itemY) {
            x = Math.min(_startX, itemX)
            y = Math.min(_startY, itemY)
            width = Math.abs(itemX - _startX)
            height = Math.abs(itemY - _startY)
        }

        // Request the selected region, one region at a time: replaces the shown one
        function finish() {
            visible = false
            const vehicle = QGroundControl.multiVehicleManager.activeVehicle
            if (!vehicle || width < rootItem._minRegionSize || height < rootItem._minRegionSize) {
                return
            }
            const topLeftX = rootItem._toVideoX(x)
            const topLeftY = rootItem._toVideoY(y)
            const bottomRightX = rootItem._toVideoX(x + width)
            const bottomRightY = rootItem._toVideoY(y + height)
            if (topLeftX >= bottomRightX || topLeftY >= bottomRightY) {
                return  // selection is outside the video image
            }
            regionTemperature.clear()
            vehicle.requestRegionTemperature(topLeftX, topLeftY, bottomRightX, bottomRightY, true)
            regionRefresh.requestSent()
        }
    }

    // Region temperature measured by the camera (CAMERA_REGION_TEMPERATURE): measured rectangle with its max and min points
    Item {
        id:         regionTemperature
        visible:    regionTemperature._shown
        opacity:    regionRefresh.stale ? 0.4 : 1  // faded: last refresh got no reply

        property bool _shown:           false
        property real _topLeftX:        0   // positions normalized 0..1, 0,0 is top left
        property real _topLeftY:        0
        property real _bottomRightX:    0
        property real _bottomRightY:    0
        property real _max:             0   // degC
        property real _maxX:            0
        property real _maxY:            0
        property real _min:             0   // degC
        property real _minX:            0
        property real _minY:            0

        function show(topLeftX, topLeftY, bottomRightX, bottomRightY, max, maxX, maxY, min, minX, minY) {
            if (!regionRefresh.waitingForReply) {
                return  // cleared while the request was outstanding: ignore the reply
            }
            regionRefresh.replyReceived()
            _topLeftX = topLeftX
            _topLeftY = topLeftY
            _bottomRightX = bottomRightX
            _bottomRightY = bottomRightY
            _max = max
            _maxX = maxX
            _maxY = maxY
            _min = min
            _minX = minX
            _minY = minY
            _shown = true
        }

        function clear() {
            _shown = false
            regionRefresh.cancel()
        }

        // true if the tap at mouseX, mouseY (video coordinates) is on the shown region or its max or min label
        function isAt(mouseX, mouseY) {
            if (!_shown) {
                return false
            }
            const onFrame = rootItem._inRect(mouseX, mouseY, regionFrame.x, regionFrame.y, regionFrame.width, regionFrame.height)
            const onMaxLabel = rootItem._inRect(mouseX, mouseY, regionMaxLabel.x, regionMaxLabel.y, regionMaxLabel.width, regionMaxLabel.height)
            const onMinLabel = rootItem._inRect(mouseX, mouseY, regionMinLabel.x, regionMinLabel.y, regionMinLabel.width, regionMinLabel.height)
            return onFrame || onMaxLabel || onMinLabel
        }

        // Request the shown region again so the temperatures follow the scene
        TemperatureRefresh {
            id: regionRefresh
            onRefresh: {
                const vehicle = QGroundControl.multiVehicleManager.activeVehicle
                if (vehicle) {
                    vehicle.requestRegionTemperature(regionTemperature._topLeftX, regionTemperature._topLeftY,
                                                     regionTemperature._bottomRightX, regionTemperature._bottomRightY, false)
                }
            }
        }

        Rectangle {
            id:             regionFrame
            x:              rootItem._fromVideoX(regionTemperature._topLeftX)
            y:              rootItem._fromVideoY(regionTemperature._topLeftY)
            width:          rootItem._fromVideoX(regionTemperature._bottomRightX) - x
            height:         rootItem._fromVideoY(regionTemperature._bottomRightY) - y
            color:          "transparent"
            border.color:   "white"
            border.width:   2
        }

        // Rings at the measured points. Their labels go outside the rectangle (max above, min below, bordered in the ring's
        // color) so they don't overlap each other or cover the region when it is small. Kept inside the video item.
        TemperatureMarker {
            x:              rootItem._fromVideoX(regionTemperature._maxX)
            y:              rootItem._fromVideoY(regionTemperature._maxY)
            markerColor:    "red"
            showLabel:      false
        }

        TemperatureMarker {
            x:              rootItem._fromVideoX(regionTemperature._minX)
            y:              rootItem._fromVideoY(regionTemperature._minY)
            markerColor:    "deepskyblue"
            showLabel:      false
        }

        TemperatureLabel {
            id:             regionMaxLabel
            x:              Math.max(0, Math.min(regionFrame.x, rootItem.width - width))
            y:              Math.max(0, regionFrame.y - height - ScreenTools.defaultFontPixelHeight / 4)
            border.color:   "red"
            temperature:    regionTemperature._max
            prefix:         qsTr("max")
        }

        TemperatureLabel {
            id:             regionMinLabel
            x:              Math.max(0, Math.min(regionFrame.x, rootItem.width - width))
            y:              Math.min(rootItem.height - height, regionFrame.y + regionFrame.height + ScreenTools.defaultFontPixelHeight / 4)
            border.color:   "deepskyblue"
            temperature:    regionTemperature._min
            prefix:         qsTr("min")
        }
    }

    // Frame max and min from the camera's thermal range stream (CAMERA_THERMAL_RANGE), when it reports their positions
    Item {
        id:         thermalRangePoints
        visible:    globals.showThermalRangeMarkers && !!thermalRangePoints._camera && thermalRangePoints._camera.thermalRangeAvailable

        readonly property var _camera: rootItem.camera

        // true if the camera reported this temperature and its position
        function _hasPoint(temperature, point) {
            return !isNaN(temperature) && !isNaN(point.x) && !isNaN(point.y)
        }

        readonly property bool _hasMax: !!_camera && _hasPoint(_camera.thermalRangeMax, _camera.thermalRangeMaxPoint)
        readonly property bool _hasMin: !!_camera && _hasPoint(_camera.thermalRangeMin, _camera.thermalRangeMinPoint)

        TemperatureMarker {
            visible:        thermalRangePoints._hasMax
            x:              thermalRangePoints._hasMax ? rootItem._fromVideoX(thermalRangePoints._camera.thermalRangeMaxPoint.x) : 0
            y:              thermalRangePoints._hasMax ? rootItem._fromVideoY(thermalRangePoints._camera.thermalRangeMaxPoint.y) : 0
            temperature:    thermalRangePoints._hasMax ? thermalRangePoints._camera.thermalRangeMax : 0
            prefix:         qsTr("Frame max")
            boundsWidth:    rootItem.width
            boundsHeight:   rootItem.height
            markerColor:    "orange"
        }

        TemperatureMarker {
            visible:        thermalRangePoints._hasMin
            x:              thermalRangePoints._hasMin ? rootItem._fromVideoX(thermalRangePoints._camera.thermalRangeMinPoint.x) : 0
            y:              thermalRangePoints._hasMin ? rootItem._fromVideoY(thermalRangePoints._camera.thermalRangeMinPoint.y) : 0
            temperature:    thermalRangePoints._hasMin ? thermalRangePoints._camera.thermalRangeMin : 0
            prefix:         qsTr("Frame min")
            boundsWidth:    rootItem.width
            boundsHeight:   rootItem.height
            markerColor:    "cyan"
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager.activeVehicle
        function onCameraPointTemperatureReceived(x, y, temperature) {
            pointTemperature.show(x, y, temperature)
        }
        function onCameraRegionTemperatureReceived(topLeftX, topLeftY, bottomRightX, bottomRightY, max, maxX, maxY, min, minX, minY) {
            regionTemperature.show(topLeftX, topLeftY, bottomRightX, bottomRightY, max, maxX, maxY, min, minX, minY)
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged(activeVehicle) {
            pointTemperature.clear()
            regionTemperature.clear()
        }
    }
}
