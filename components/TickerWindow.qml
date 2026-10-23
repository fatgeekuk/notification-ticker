// Bottom news-ticker for notifications. One layer per screen. A tall narrow
// output, such as a portrait info strip, is skipped: a chyron there would
// cover the panel.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

  // The picture sits still while the line scrolls behind it, then leaves just
  // before the ticker does. It rises from below the screen, bounces, and later
  // hops and drops back off the bottom. The plate is clear, so only the
  // picture's own pixels cover the line. Its lowest pixel sits on the middle
  // of the text. A right-to-left language parks it on the right and runs the
  // line the other way.

  readonly property real stripHeight: Style.font.display + Style.space(20)
  readonly property real thumbSize: Math.round(stripHeight * 1.9)
  readonly property real thumbBounce: Style.space(18)
  readonly property real thumbLeft: Style.space(8)
  // Middle of the text line, measured up from the bottom of the window.
  readonly property real textMidFromBottom: (stripHeight - surface.contentTopInset + surface.contentBottomInset) / 2
  readonly property real infoMargin: Math.max(thumbPlate.borderTop, Style.space(4))
  // Distance from the frame's bottom edge up to the picture's lowest pixel.
  // The information mark is a ring inside a 24-unit box, so the frame hangs
  // below the ring. A photo fills the frame.
  readonly property real thumbInkInset: {
    var photo = thumbSource.length > 0 && thumbImage.status !== Image.Error
    if (photo) return Math.max(thumbPlate.borderLeft, thumbPlate.borderTop)
    var margin = infoMargin
    var inner = Math.max(0, thumbSize - margin * 2)
    var ringBottom = 12 + 9 + 1.7 / 2
    return margin + inner * (24 - ringBottom) / 24
  }
  readonly property real thumbBottomMargin: Math.max(0, textMidFromBottom - thumbInkInset)

  function rtlLetter(cp) {
    return (cp >= 0x0590 && cp <= 0x08FF)
      || (cp >= 0xFB1D && cp <= 0xFDFF)
      || (cp >= 0xFE70 && cp <= 0xFEFF)
      || (cp >= 0x1E900 && cp <= 0x1E95F)
  }

  function ltrLetter(cp) {
    if ((cp >= 0x41 && cp <= 0x5A) || (cp >= 0x61 && cp <= 0x7A)) return true
    if (cp >= 0x00C0 && cp <= 0x024F) return true
    if (cp >= 0x0370 && cp <= 0x058F) return true
    if (cp >= 0x0900 && cp <= 0x1FFF) return true
    if (cp >= 0x3040 && cp <= 0x30FF) return true
    if (cp >= 0x3400 && cp <= 0x9FFF) return true
    if (cp >= 0xAC00 && cp <= 0xD7AF) return true
    return false
  }

  // First strong letter of the line. Neutrals and digits do not decide.
  function textReadsRtl(value) {
    var s = String(value || "")
    var i = 0
    while (i < s.length) {
      var cp = s.codePointAt(i)
      if (!isFinite(cp)) break
      i += cp > 0xFFFF ? 2 : 1
      if (rtlLetter(cp)) return true
      if (ltrLetter(cp)) return false
    }
    return false
  }

  readonly property bool rtl: {
    var line = loopText
    if (Qt.application.layoutDirection === Qt.RightToLeft) return true
    if (Qt.locale().textDirection === Qt.RightToLeft) return true
    return textReadsRtl(line)
  }
  readonly property bool thumbReady: thumbImage.status === Image.Ready
  // No attached picture, or the picture failed: draw the information mark.
  readonly property bool showInfo: thumbSource.length === 0 || thumbImage.status === Image.Error
  readonly property color infoColor: host && host.tickerCritical
    ? Commons.Color.urgent
    : Commons.Color.notifications.text
  readonly property color infoFill: Commons.Color.notifications.background
  property string infoTemplate: ""

  readonly property string infoSvgPath: {
    var url = Qt.resolvedUrl("assets/info.svg").toString()
    if (url.slice(0, 7) === "file://") url = url.slice(7)
    try { url = decodeURIComponent(url) } catch (e) {}
    return url
  }

  function svgHex(color) {
    function byte(channel) {
      var n = Math.round(Number(channel) * 255)
      if (!isFinite(n)) n = 0
      if (n < 0) n = 0
      if (n > 255) n = 255
      var s = n.toString(16)
      return s.length < 2 ? "0" + s : s
    }
    var rgb = "#" + byte(color.r) + byte(color.g) + byte(color.b)
    var alpha = byte(color.a)
    return alpha === "ff" ? rgb : rgb + alpha
  }

  // Paint the SVG from the notification scheme so a theme change restyles the mark.
  readonly property string infoSource: {
    var raw = infoTemplate
    if (!raw) return ""
    var colored = raw.split("#SCHEME_BACKGROUND").join(svgHex(infoFill))
    colored = colored.split("#SCHEME_COLOR").join(svgHex(infoColor))
    return "data:image/svg+xml;charset=utf-8," + encodeURIComponent(colored)
  }

  function imageUrl(value) {
    var image = String(value || "")
    if (image.length === 0) return ""
    if (image.indexOf("file://") === 0 || image.indexOf("image://") === 0) return image
    if (image.charAt(0) === "/") return Util.fileUrl(image)
    return ""
  }

  readonly property string thumbSource: host ? imageUrl(host.tickerImage) : ""

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
  implicitHeight: Math.max(stripHeight, thumbBottomMargin + thumbSize) + thumbBounce

  // The window grows above the strip for the picture. Only the strip and the
  // picture take clicks; the clear area beside the picture stays click-through.
  mask: Region {
    item: surface
    Region {
      item: thumbFrame.shift < Style.space(8) ? thumbFrame : null
    }
  }

  WlrLayershell.namespace: "peterm-notification-ticker"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  FileView {
    id: infoSvgFile
    path: window.infoSvgPath
    watchChanges: true
    printErrors: true
    preload: true
    onLoaded: window.infoTemplate = text()
    onFileChanged: reload()
  }

  HoverHandler {
    id: hover
    onHoveredChanged: if (host) host.noteTickerHover(hovered)
  }

  Component.onDestruction: {
    if (host && hover.hovered) host.noteTickerHover(false)
  }

  readonly property bool hostLeaving: host ? host.tickerThumbLeaving : false
  readonly property int hostCancel: host ? host.tickerThumbCancel : 0

  function playThumbIn() {
    if (!visible || hostLeaving) return
    thumbFrame.exitArmed = false
    thumbOut.stop()
    thumbIn.restart()
  }

  function playThumbOut() {
    thumbFrame.exitArmed = true
    thumbIn.stop()
    thumbOut.restart()
  }

  onHostLeavingChanged: if (hostLeaving) playThumbOut()
  onHostCancelChanged: if (visible) playThumbIn()
  onVisibleChanged: {
    if (visible) playThumbIn()
    else thumbFrame.shift = thumbFrame.offscreen
  }
  Component.onCompleted: if (visible) playThumbIn()

  SequentialAnimation {
    id: thumbIn
    NumberAnimation {
      target: thumbFrame
      property: "shift"
      to: -Style.space(16)
      duration: 420
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: thumbFrame
      property: "shift"
      to: 0
      duration: 180
      easing.type: Easing.OutQuad
    }
  }

  SequentialAnimation {
    id: thumbOut
    NumberAnimation {
      target: thumbFrame
      property: "shift"
      to: -Style.space(18)
      duration: 140
      easing.type: Easing.OutQuad
    }
    NumberAnimation {
      target: thumbFrame
      property: "shift"
      to: thumbFrame.offscreen
      duration: 320
      easing.type: Easing.InCubic
    }
    onFinished: if (thumbFrame.exitArmed && host) host.finishTickerThumbExit()
  }

  BorderSurface {
    id: surface
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: window.stripHeight
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
      // Keeps the count and the × on the opposite side from the picture.
      LayoutMirroring.enabled: window.rtl
      LayoutMirroring.childrenInherit: false
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

            x: {
              var travel = index * window.segmentWidth - window.scrollOffset
              if (!window.rtl) return travel
              var span = implicitWidth > 1 ? implicitWidth : window.segmentWidth
              return viewport.width - travel - span
            }
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

  Item {
    id: thumbFrame
    visible: true
    z: 2
    // Positive shift drops the picture. It starts below the screen.
    property real shift: 800
    property bool exitArmed: false
    readonly property real offscreen: window.thumbSize + window.stripHeight
    width: window.thumbSize
    height: window.thumbSize
    x: window.rtl ? parent.width - width - window.thumbLeft : window.thumbLeft
    anchors.bottom: parent.bottom
    anchors.bottomMargin: window.thumbBottomMargin
    transform: Translate { y: thumbFrame.shift }

    BorderSurface {
      id: thumbPlate
      anchors.fill: parent
      radius: Math.max(Style.cornerRadius, Style.space(8))
      clip: true
      color: "transparent"
      borderSpec: Border.none()

      Image {
        id: infoImage
        anchors.fill: parent
        anchors.margins: window.infoMargin
        visible: window.showInfo && status === Image.Ready
        source: window.infoSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        sourceSize.width: Math.round(width * Screen.devicePixelRatio)
        sourceSize.height: Math.round(height * Screen.devicePixelRatio)
      }

      Image {
        id: thumbImage
        anchors.fill: parent
        anchors.margins: Math.max(thumbPlate.borderLeft, thumbPlate.borderTop)
        visible: window.thumbReady
        source: window.thumbSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        sourceSize.width: Math.round(window.thumbSize * Screen.devicePixelRatio)
        sourceSize.height: Math.round(window.thumbSize * Screen.devicePixelRatio)
      }
    }
  }
}
