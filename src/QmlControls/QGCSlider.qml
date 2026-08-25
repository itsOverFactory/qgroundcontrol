import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Slider {
    property bool zeroCentered: false ///< Value indicator starts display from zero instead of min value
    property bool displayValue: false ///< true: Show value on handle
    property bool showBoundaryValues: false ///< true: Show min/max values at slider ends
    property real _boundaryLabelTopMargin: ScreenTools.defaultFontPixelHeight * 0.3
    property real _contentPadding: ScreenTools.defaultFontPixelWidth * 0.4

    id: control
    implicitHeight: ScreenTools.implicitSliderHeight + topPadding + bottomPadding + (showBoundaryValues ? minLabel.contentHeight + _boundaryLabelTopMargin : 0)
    leftPadding: _contentPadding
    rightPadding: _contentPadding
    topPadding: _contentPadding
    bottomPadding: _contentPadding
    wheelEnabled: false

    property real _implicitBarLength: Math.round(ScreenTools.defaultFontPixelWidth * 20)
    property real _barHeight: Math.round(ScreenTools.defaultFontPixelHeight / 3)

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    background: Rectangle {
        id: sliderBar
        x: control.horizontal ? control.leftPadding : control.leftPadding + control.availableWidth / 2 - width / 2
        y: control.horizontal ? control.topPadding + control.availableHeight / 2 - height / 2 : control.topPadding
        implicitWidth: control.horizontal ? control._implicitBarLength : control._barHeight
        implicitHeight: control.horizontal ? control._barHeight : control._implicitBarLength
        width: control.horizontal ? control.availableWidth : implicitWidth
        height: control.horizontal ? implicitHeight : control.availableHeight
        radius: control._barHeight / 2
        color: qgcPal.button
        border.width: 1
        border.color: qgcPal.buttonText
    }

    handle: Rectangle {
        x: control.horizontal ?
               control.leftPadding + control.visualPosition * (control.availableWidth - width) :
               control.leftPadding + control.availableWidth / 2 - width / 2
        y: control.horizontal ?
               control.topPadding + control.availableHeight / 2 - height / 2 :
               control.topPadding + control.visualPosition * (control.availableHeight - height)
        implicitWidth: _radius * 2
        implicitHeight: _radius * 2
        color: qgcPal.button
        border.color: qgcPal.buttonText
        border.width: 1
        radius: _radius

        property real _radius: ScreenTools.defaultFontPixelHeight / 2

        Label {
            text: control.value.toFixed(control.to <= 1 ? 1 : 0)
            visible: control.displayValue
            anchors.centerIn: parent
            font.family: ScreenTools.normalFontFamily
            font.pointSize: ScreenTools.smallFontPointSize
            color: qgcPal.buttonText
        }
    }

    QGCLabel {
        id: minLabel
        anchors.left: parent.left
        anchors.leftMargin: control.leftPadding
        anchors.top: sliderBar.bottom
        anchors.topMargin: control._boundaryLabelTopMargin
        text: control.from.toFixed(1)
        font.pointSize: ScreenTools.smallFontPointSize
        color: qgcPal.buttonText
        visible: control.showBoundaryValues
    }

    QGCLabel {
        id: maxLabel
        anchors.right: parent.right
        anchors.rightMargin: control.rightPadding
        anchors.top: sliderBar.bottom
        anchors.topMargin: control._boundaryLabelTopMargin
        text: control.to.toFixed(1)
        font.pointSize: ScreenTools.smallFontPointSize
        color: qgcPal.buttonText
        visible: control.showBoundaryValues
    }
}
