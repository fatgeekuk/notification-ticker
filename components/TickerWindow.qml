// Bottom news-ticker for notifications. One layer per screen. A tall narrow
// output, such as a portrait info strip, is skipped: a chyron there would
// cover the panel.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

PanelWindow {
  id: window

  required property var modelData
  property var host: null

  readonly property bool eligible: {
    var screen = modelData
    if (!screen) return false
    var width = Number(screen.width || 0)
    var height = Number(screen.height || 0)
    if (width > 0 && width < 800 && height > width * 1.4) return false
    return true
  }

  readonly property real segmentWidth: host ? host.tickerSegmentWidth : 1
  readonly property real scrollOffset: host ? host.tickerOffset : 0
  readonly property string loopText: host ? host.tickerLoopText : ""
  readonly property string textFont: host ? host.tickerFontFamily : Style.font.family
  readonly property int copyCount: {
    var segment = segmentWidth
    if (segment <= 1 || viewport.width <= 0) return 2
    return Math.max(2, Math.ceil(viewport.width / segment) + 1)
  }

  screen: modelData
  visible: host && host.ticker && host.popupModel.count > 0 && eligible
  color: "transparent"
  surfaceFormat.opaque: false
  exclusionMode: ExclusionMode.Ignore

  anchors {
    left: true
    right: true
    bottom: true
  }

  margins.left: host && host.barPosition === "left" ? host.barClearance : Style.gapsOut
  margins.right: host && host.barPosition === "right" ? host.barClearance : Style.gapsOut
  margins.bottom: host && host.barPosition === "bottom" ? host.barClearance : Style.gapsOut
  implicitHeight: Style.font.display + Style.space(20)

  WlrLayershell.namespace: "peterm-notification-ticker"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  HoverHandler {
    id: hover
    onHoveredChanged: if (host) host.noteTickerHover(hovered)
  }

  Component.onDestruction: {
    if (host && hover.hovered) host.noteTickerHover(false)
  }

  BorderSurface {
    id: surface
    anchors.fill: parent
    radius: Style.cornerRadius
    clip: true
    color: Commons.Color.notifications.background
    borderSpec: Border.surfaceSpec(
      "notifications",
      "border",
      window.host && window.host.tickerCritical
        ? Commons.Color.urgent
        : Commons.Color.notifications.border,
      Math.max(1, Style.space(2)))

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: surface.contentLeftInset + Style.space(12)
      anchors.rightMargin: surface.contentRightInset + Style.space(8)
      anchors.topMargin: surface.contentTopInset
      anchors.bottomMargin: surface.contentBottomInset
      spacing: Style.space(10)

      Item {
        id: viewport
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: if (host) host.dismissOldestPopup()
        }

        Repeater {
          model: window.loopText.length > 0 ? window.copyCount : 0

          delegate: Text {
            required property int index

            x: index * window.segmentWidth - window.scrollOffset
            y: Math.round((viewport.height - implicitHeight) / 2)
            text: window.loopText
            textFormat: Text.PlainText
            font.family: window.textFont
            font.pixelSize: Style.font.display
            color: Commons.Color.notifications.text
          }
        }
      }

      Text {
        visible: host && host.popupModel.count > 1
        Layout.alignment: Qt.AlignVCenter
        text: host ? String(host.popupModel.count) : ""
        textFormat: Text.PlainText
        font.family: host ? host.tickerFontFamily : Style.font.family
        font.pixelSize: Style.font.heading
        color: Commons.Color.notifications.countdown
      }

      Text {
        id: dismissAll
        Layout.alignment: Qt.AlignVCenter
        text: "×"
        textFormat: Text.PlainText
        font.family: host ? host.tickerFontFamily : Style.font.family
        font.pixelSize: Style.font.display
        color: Commons.Color.notifications.text

        MouseArea {
          anchors.fill: parent
          anchors.margins: -Style.space(6)
          cursorShape: Qt.PointingHandCursor
          onClicked: if (host) host.clearPopups()
        }
      }
    }
  }
}
