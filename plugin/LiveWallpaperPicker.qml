import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtMultimedia
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Live wallpaper picker (omarchy-live-wallpaper): a carousel of every installed wallpaper scene.
//
// The big card in the middle plays the real wallpaper video; smaller cards on each side show
// posters. Clicking a side card (or the arrow keys / scroll wheel) slides it into the middle.
// Nothing changes until Save. The follow button hands control back to the pack's schedule.
//
// Data comes from `live-wallpaper list --json`, which discovers every video in every installed
// pack - so a new wallpaper appears here with no change to this file.
// Opened via `live-wallpaper` / SUPER+SPACE > Style > Live wallpaper.
Item {
  id: root

  readonly property string pluginId: "io.github.vienjunaid.live-wallpaper"
  readonly property string cli: Quickshell.env("HOME") + "/.local/bin/live-wallpaper"

  property bool opened: false
  property bool loaded: false
  property string errorText: ""
  property var scenes: []
  property int selectedIndex: 0
  property string current: ""     // scene playing on the desktop right now
  property string mode: "auto"    // "auto" (follows the schedule) or "pinned"
  property string scheduleLabel: "Follow schedule"
  property bool videoShown: false  // video layer visible (hidden instantly while sliding)

  readonly property var selected: scenes.length > 0 ? scenes[selectedIndex] : null

  // ---- theme
  readonly property color fg: Commons.Color.imagePicker.text
  readonly property color accent: Commons.Color.imagePicker.selectedBorder
  readonly property color dim: Commons.Color.background
  readonly property color subtle: Commons.Color.imagePicker.unselectedBorder

  // ---- lifecycle (called by omarchy-shell summon / hide)
  function open(payload) {
    opened = true
    loaded = false
    errorText = ""
    // Always re-read the list, even if a previous load is still in flight, so the picker opens
    // on whatever is playing right now.
    listProc.running = false
    listProc.running = true
  }

  function close() {
    player.stop()
    player.source = ""
    opened = false
  }

  // Close and let the host unload the plugin, which frees the video decoder.
  function dismiss() {
    close()
    Quickshell.execDetached(["omarchy-shell", "shell", "hide", pluginId])
  }

  function save() {
    if (!selected) return
    Quickshell.execDetached([cli, "set", selected.id])
    dismiss()
  }

  function followPrayerTimes() {
    Quickshell.execDetached([cli, "auto"])
    dismiss()
  }

  // `omarchy-shell shell call io.github.vienjunaid.live-wallpaper status ""` - for troubleshooting.
  function status(arg) {
    return JSON.stringify({ opened: opened, loaded: loaded, selected: selected ? selected.id : "",
      source: String(player.source), playback: player.playbackState, media: player.mediaStatus,
      error: player.errorString, position: player.position, videoShown: videoShown })
  }

  function select(i) {
    if (scenes.length === 0) return
    selectedIndex = Math.max(0, Math.min(scenes.length - 1, i))
  }

  function loadList(text) {
    try {
      var data = JSON.parse(text)
      scenes = data.scenes || []
      current = data.current || ""
      mode = data.mode || "auto"
      scheduleLabel = data.scheduleLabel || "Follow schedule"
      var start = 0
      for (var i = 0; i < scenes.length; i++)
        if (scenes[i].id === current) start = i
      selectedIndex = start
      loaded = true
      errorText = scenes.length ? "" : "No live wallpapers installed. Add a pack: see docs/creating-a-pack.md"
      keys.forceActiveFocus()
    } catch (e) {
      errorText = "Couldn't read the wallpaper list: " + e
    }
  }

  Process {
    id: listProc
    command: [root.cli, "list", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadList(String(text || ""))
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim()) root.errorText = String(text).trim()
    }
  }

  // The selected card's video (and its gold frame, which sits fixed over the middle slot) only
  // appears once the slide animation has fully finished AND the selected scene's own video is the
  // one playing. Every step re-checks both, so a late "playing" signal from the previous video, or
  // a reveal that was already scheduled, can never show the frame while a card is still moving.
  onSelectedIndexChanged: restartPreview()
  function restartPreview() {
    videoShown = false
    fadeInDelay.stop()
    player.stop()
    player.source = ""
    slideSettle.restart()
  }
  function selectedVideoUrl() {
    return root.selected ? String(Util.fileUrl(root.selected.video)) : ""
  }
  function previewReady() {
    return root.opened && !slideSettle.running && String(player.source) !== ""
      && String(player.source) === selectedVideoUrl()
      && player.playbackState === MediaPlayer.PlayingState
  }
  // Slightly longer than the 320 ms card animation, so the card is home before the video starts.
  Timer {
    id: slideSettle
    interval: 380
    onTriggered: {
      if (!root.opened || !root.selected) return
      player.source = root.selectedVideoUrl()
      player.play()
    }
  }

  MediaPlayer {
    id: player
    loops: MediaPlayer.Infinite
    videoOutput: videoOut
    // No audioOutput: previews are always silent.
    onPlaybackStateChanged: if (root.previewReady()) fadeInDelay.restart()
  }
  Timer { id: fadeInDelay; interval: 120; onTriggered: if (root.previewReady()) root.videoShown = true }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-live-wallpaper-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // ---- geometry: big 16:9 card in the middle, small cards flanking it
    readonly property real bigW: Math.min(width * 0.5, height * 0.5 * 16 / 9)
    readonly property real bigH: bigW * 9 / 16
    readonly property real smallW: bigW * 0.34
    readonly property real smallH: smallW * 9 / 16
    readonly property real gap: Math.max(16, bigW * 0.035)
    readonly property real centerX: width / 2
    readonly property real centerY: height * 0.45

    function slotX(rel) {
      if (rel === 0) return centerX - bigW / 2
      if (rel > 0) return centerX + bigW / 2 + gap + (rel - 1) * (smallW + gap)
      return centerX - bigW / 2 - gap - smallW + (rel + 1) * (smallW + gap)
    }

    Rectangle {
      anchors.fill: parent
      color: Util.alpha(root.dim, 0.96)
    }

    // Clicking empty space cancels.
    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
      onWheel: function(wheel) {
        var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x
        if (d < 0) root.select(root.selectedIndex + 1)
        else if (d > 0) root.select(root.selectedIndex - 1)
      }
    }

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) root.dismiss()
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.save()
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_L) root.select(root.selectedIndex + 1)
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab || event.key === Qt.Key_H) root.select(root.selectedIndex - 1)
        else if (event.key === Qt.Key_Home) root.select(0)
        else if (event.key === Qt.Key_End) root.select(root.scenes.length - 1)
        else if (event.key === Qt.Key_A) root.followPrayerTimes()
        else return
        event.accepted = true
      }
    }

    // ---- title
    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      y: panel.centerY - panel.bigH / 2 - height - Style.space(28)
      spacing: Style.space(4)
      visible: root.loaded
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Live Wallpaper"
        color: root.fg
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        font.weight: Font.DemiBold
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "←  →  browse     Enter  save     A  " + root.scheduleLabel.toLowerCase() + "     Esc  cancel"
        color: root.fg
        opacity: 0.55
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    // ---- loading / error
    Text {
      anchors.centerIn: parent
      visible: !root.loaded || root.errorText !== ""
      width: Math.min(parent.width - 80, 720)
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      text: root.errorText !== "" ? root.errorText : "Loading live wallpapers…"
      color: root.fg
      font.family: Style.font.family
      font.pixelSize: Style.font.title
    }

    // ---- carousel cards
    Repeater {
      model: root.loaded ? root.scenes : []

      delegate: Item {
        id: card
        required property var modelData
        required property int index

        readonly property int rel: index - root.selectedIndex
        readonly property bool isSelected: rel === 0
        readonly property bool isCurrent: modelData.id === root.current

        visible: Math.abs(rel) <= 5
        z: 100 - Math.abs(rel)
        x: panel.slotX(rel)
        y: panel.centerY - height / 2
        width: isSelected ? panel.bigW : panel.smallW
        height: isSelected ? panel.bigH : panel.smallH
        opacity: Math.abs(rel) <= 2 ? 1 : (Math.abs(rel) === 3 ? 0.45 : 0)

        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220 } }

        readonly property real cornerRadius: isSelected ? 16 : 10

        Rectangle {
          id: cardMask
          anchors.fill: parent
          radius: card.cornerRadius
          visible: false
          layer.enabled: true
        }

        Item {
          anchors.fill: parent
          layer.enabled: true
          layer.smooth: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: cardMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
          }

          Image {
            anchors.fill: parent
            source: Util.fileUrl(card.modelData.poster)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            sourceSize.width: 960
          }

          // Side cards are dimmed so the middle one reads as the focus.
          Rectangle {
            anchors.fill: parent
            color: root.dim
            opacity: card.isSelected ? 0 : 0.45
            Behavior on opacity { NumberAnimation { duration: 220 } }
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: card.cornerRadius
          color: "transparent"
          border.width: card.isSelected ? 3 : (hover.containsMouse ? 2 : 1)
          border.color: card.isSelected || hover.containsMouse ? root.accent : root.subtle
        }

        // Small label on side cards.
        Text {
          visible: !card.isSelected
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
          text: card.modelData.label
          color: root.fg
          style: Text.Outline
          styleColor: Util.alpha(root.dim, 0.8)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }

        // "Now playing" marker for whatever is on the desktop right now.
        Rectangle {
          visible: card.isCurrent
          anchors { top: parent.top; right: parent.right; margins: card.isSelected ? 12 : 6 }
          radius: height / 2
          color: Util.alpha(root.dim, 0.75)
          border.color: root.accent
          border.width: 1
          width: nowText.implicitWidth + 16
          height: nowText.implicitHeight + 6
          Text {
            id: nowText
            anchors.centerIn: parent
            text: card.isSelected ? "● Now playing" : "●"
            color: root.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        MouseArea {
          id: hover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: card.isSelected ? Qt.ArrowCursor : Qt.PointingHandCursor
          onClicked: root.select(card.index)
          onDoubleClicked: if (card.isSelected) root.save()
        }
      }
    }

    // ---- live video, layered over the middle card once the slide has settled
    Item {
      id: videoStage
      x: panel.centerX - panel.bigW / 2
      y: panel.centerY - panel.bigH / 2
      width: panel.bigW
      height: panel.bigH
      z: 200
      // Hidden instantly while the carousel slides; fades in once the new video is playing.
      visible: root.loaded && root.scenes.length > 0 && root.videoShown
      opacity: root.videoShown ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 250 } }

      Rectangle { id: videoMask; anchors.fill: parent; radius: 16; visible: false; layer.enabled: true }

      Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: videoMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 1.0
        }
        VideoOutput {
          id: videoOut
          anchors.fill: parent
          fillMode: VideoOutput.PreserveAspectCrop
        }
      }
      Rectangle {
        anchors.fill: parent
        radius: 16
        color: "transparent"
        border.width: 3
        border.color: root.accent
      }
      Rectangle {
        visible: root.selected && root.selected.id === root.current
        anchors { top: parent.top; right: parent.right; margins: 12 }
        radius: height / 2
        color: Util.alpha(root.dim, 0.75)
        border.color: root.accent
        border.width: 1
        width: nowText2.implicitWidth + 16
        height: nowText2.implicitHeight + 6
        Text {
          id: nowText2
          anchors.centerIn: parent
          text: "● Now playing"
          color: root.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
      MouseArea { anchors.fill: parent; onDoubleClicked: root.save() }
    }

    // ---- caption, dots and buttons under the middle card
    Column {
      id: footer
      visible: root.loaded && root.selected !== null
      anchors.horizontalCenter: parent.horizontalCenter
      y: panel.centerY + panel.bigH / 2 + Style.space(18)
      spacing: Style.space(8)
      width: panel.bigW

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.selected ? root.selected.label : ""
        color: root.fg
        font.family: Style.font.family
        font.pixelSize: Style.font.display
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: {
          if (!root.selected) return ""
          var pack = root.selected.packLabel || ""
          return root.selected.subtitle ? root.selected.subtitle + "  ·  " + pack : pack
        }
        color: root.fg
        opacity: 0.65
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      // position dots
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        Repeater {
          model: root.scenes.length
          delegate: Rectangle {
            required property int index
            width: index === root.selectedIndex ? 18 : 6
            height: 6
            radius: 3
            color: index === root.selectedIndex ? root.accent : root.subtle
            Behavior on width { NumberAnimation { duration: 200 } }
            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.select(parent.index) }
          }
        }
      }

      Item { width: 1; height: Style.space(6) }

      Item {
        width: parent.width
        height: saveButton.implicitHeight

        Button {
          id: followButton
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: root.mode === "auto" ? root.scheduleLabel.replace("Follow", "Following") + " ✓" : root.scheduleLabel
          iconText: "󰥔"
          bordered: true
          selected: root.mode === "auto"
          onClicked: root.followPrayerTimes()
        }

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)

          Button {
            text: "Cancel"
            bordered: true
            onClicked: root.dismiss()
          }
          Button {
            id: saveButton
            text: "Save"
            iconText: "󰄬"
            bordered: true
            background: root.accent
            foreground: root.dim
            accent: root.dim
            onClicked: root.save()
          }
        }
      }
    }
  }
}
