import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import qs.Ui

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: home + "/.local/state"
  readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"

  property string currentBackground: ""
  property string displayedBackground: ""
  property string incomingBackground: ""
  property string oldBackground: ""
  property bool finishingTransition: false
  property int backgroundVersion: 0
  property int revealStartedVersion: -1
  property int pendingThemeVersion: -1
  property string pendingColorsRaw: ""
  property string pendingShellRaw: ""
  property real revealProgress: 1

  // Per-monitor rotation: every rotationInterval, each screen gets its own
  // random image from rotationDir. An explicit theme/background switch clears
  // the map (the global pick shows), and the next tick resumes rotation.
  readonly property string rotationDir: home + "/.config/omarchy/backgrounds/catppuccin"
  readonly property int rotationInterval: 60000
  readonly property string rotationStatePath: stateHome + "/omarchy/wall-rotation.json"
  property var screenBackgrounds: ({})

  // Rotation state (image map + timestamp) is persisted so plugin reloads and
  // shell restarts resume the current wallpapers instead of rotating early.
  function restoreRotation() {
    var restored = false
    try {
      var state = JSON.parse(rotationStateFile.text())
      var age = Date.now() - Number(state.ts || 0)
      if (state.map && age >= 0 && age < rotationInterval) {
        var complete = true
        var screens = Quickshell.screens
        for (var s = 0; s < screens.length; s++) {
          if (!state.map[screens[s].name]) complete = false
        }
        if (complete) {
          screenBackgrounds = state.map
          restored = true
          rotationTimer.interval = Math.max(1000, rotationInterval - age)
          rotationTimer.restart()
        }
      }
    } catch (e) {}
    if (!restored) rotateNow()
  }

  function rotateNow() {
    if (!rotationScanProc.running) rotationScanProc.running = true
  }

  function applyRotation(lines) {
    if (rotationTimer.interval !== rotationInterval) {
      rotationTimer.interval = rotationInterval
      rotationTimer.restart()
    }
    var imgs = lines.filter(function(l) { return l.length > 0 })
    if (imgs.length === 0) return
    // shuffle so monitors get distinct images when possible
    for (var i = imgs.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1))
      var tmp = imgs[i]; imgs[i] = imgs[j]; imgs[j] = tmp
    }
    var map = {}
    var screens = Quickshell.screens
    for (var s = 0; s < screens.length; s++) {
      map[screens[s].name] = imgs[s % imgs.length]
    }
    screenBackgrounds = map
    rotationStateFile.setText(JSON.stringify({ ts: Date.now(), map: map }))
  }

  Timer {
    id: rotationTimer
    interval: root.rotationInterval
    repeat: true
    running: true
    onTriggered: root.rotateNow()
  }

  FileView {
    id: rotationStateFile
    path: root.rotationStatePath
    printErrors: false
    onLoaded: root.restoreRotation()
    onLoadFailed: root.rotateNow()
  }

  Process {
    id: rotationScanProc
    command: ["find", root.rotationDir, "-type", "f",
              "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg",
              "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
    stdout: StdioCollector {
      onStreamFinished: root.applyRotation(String(text || "").split("\n"))
    }
  }

  function imageUrl(path) {
    return Util.fileUrl(path)
  }

  function refreshBackground() {
    if (!readlinkProc.running) readlinkProc.running = true
  }

  function setBackground(path, instant) {
    transitionBackground("", path, path, instant, false)
  }

  function transitionBackground(fromPath, path, finalPath, instant, force) {
    path = String(path || "").trim()
    finalPath = String(finalPath || path).trim()
    fromPath = String(fromPath || "").trim()
    if (!path || (!force && finalPath === currentBackground)) return
    currentBackground = finalPath
    backgroundVersion += 1
    revealStartedVersion = -1

    revealAnimation.stop()
    finishingTransition = false

    if (instant || !displayedBackground) {
      oldBackground = ""
      incomingBackground = ""
      displayedBackground = path
      revealProgress = 1
      return
    }

    oldBackground = fromPath || displayedBackground
    incomingBackground = path
    revealProgress = 0
  }

  function setPendingTheme(colorsB64, shellB64) {
    pendingColorsRaw = Util.decodeBase64(colorsB64)
    pendingShellRaw = Util.decodeBase64(shellB64)
    pendingThemeVersion = backgroundVersion
    pendingThemeFallbackTimer.restart()
  }

  function applyPendingTheme() {
    // Background polling can advance backgroundVersion while a theme switch is
    // pending; the latest theme payload should still apply.
    if (pendingThemeVersion < 0) return
    pendingThemeFallbackTimer.stop()
    Color.loadColors(pendingColorsRaw)
    // Color.loadShell also refreshes Style so the type scale flips with the
    // background reveal instead of waiting for a separate reload path.
    Color.loadShell(pendingShellRaw)
    Style.scheduleRefresh()
    pendingThemeVersion = -1
    pendingColorsRaw = ""
    pendingShellRaw = ""
  }

  function transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64) {
    transitionBackground(fromPath, path, finalPath, false, true)
    setPendingTheme(colorsB64, shellB64)
    if (!incomingBackground || revealProgress >= 1) applyPendingTheme()
  }

  function startReveal(panel) {
    if (!incomingBackground) return
    panel.maskReady = true
    if (revealStartedVersion === backgroundVersion) return
    revealStartedVersion = backgroundVersion
    applyPendingTheme()
    revealAnimation.restart()
  }

  function openSelector() {
    if (!bgSwitchProc.running) bgSwitchProc.running = true
  }

  function openThemeSwitcher() {
    if (!themeSwitchProc.running) themeSwitchProc.running = true
  }

  Process {
    id: bgSwitchProc
    command: ["bash", "-c", "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\""]
    onExited: root.refreshBackground()
  }

  Process {
    id: themeSwitchProc
    command: ["bash", "-c", "theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set \"$theme\" >/dev/null 2>&1 &"]
    onExited: root.refreshBackground()
  }

  Process {
    id: readlinkProc
    command: ["readlink", "-f", root.currentBackgroundLink]
    stdout: StdioCollector {
      onStreamFinished: root.setBackground(String(text || "").trim(), false)
    }
  }

  IpcHandler {
    target: "background"

    function refresh(): void {
      root.refreshBackground()
    }

    function set(path: string): void {
      root.screenBackgrounds = ({})
      root.setBackground(path, false)
    }

    function setInstant(path: string): void {
      root.screenBackgrounds = ({})
      root.setBackground(path, true)
    }

    function transition(fromPath: string, path: string): void {
      root.screenBackgrounds = ({})
      root.transitionBackground(fromPath, path, path, false, false)
    }

    function themeTransition(fromPath: string, path: string, finalPath: string, colorsB64: string, shellB64: string): void {
      root.screenBackgrounds = ({})
      root.transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64)
    }
  }

  Timer {
    id: pendingThemeFallbackTimer
    interval: 300
    repeat: false
    onTriggered: root.applyPendingTheme()
  }

  NumberAnimation {
    id: revealAnimation
    target: root
    property: "revealProgress"
    from: 0
    to: 1
    duration: 420
    easing.type: Easing.InOutCubic
    onFinished: {
      if (root.incomingBackground) {
        root.displayedBackground = root.currentBackground || root.incomingBackground
        root.finishingTransition = true
      }
      root.revealProgress = 1
    }
  }

  Component.onCompleted: refreshBackground()

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: !remapGuard.remapping
      anchors { top: true; bottom: true; left: true; right: true }

      ScreenMoveRemap {
        id: remapGuard
        window: panel
      }
      color: "transparent"
      // Keep render updates enabled. The background layer has been observed to
      // lose its committed buffer while parked with updatesEnabled=false,
      // leaving a black desktop until omarchy-shell is restarted. The wallpaper
      // itself is static, so this favors correctness over a small render-loop
      // optimization.
      updatesEnabled: true

      property bool maskReady: false
      readonly property string rotatedBackground: root.screenBackgrounds[modelData.name] || ""

      // Crossfade between rotation picks: the settled image stays in `base`
      // while the next one loads invisibly in `fadeFrame` and fades in.
      property string shownBackground: ""
      property string fadingBackground: ""

      onRotatedBackgroundChanged: {
        if (!rotatedBackground) {
          fadeIn.stop()
          fadeFrame.opacity = 0
          fadingBackground = ""
          shownBackground = ""
          return
        }
        if (rotatedBackground === shownBackground || rotatedBackground === fadingBackground) return
        if (!shownBackground) {
          // First assignment (startup/restore): show instantly, no fade.
          shownBackground = rotatedBackground
          return
        }
        fadingBackground = rotatedBackground
      }

      onFadingBackgroundChanged: {
        fadeIn.stop()
        fadeFrame.opacity = 0
      }

      function maybeStartReveal() {
        if (!root.incomingBackground || root.revealProgress !== 0 || maskReady) return
        if (incomingFrame.status !== Image.Ready) return
        Qt.callLater(function() {
          if (!root.incomingBackground || root.revealProgress !== 0 || maskReady) return
          if (incomingFrame.status !== Image.Ready) return
          root.startReveal(panel)
        })
      }

      WlrLayershell.namespace: "omarchy-background"
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      Image {
        id: base
        anchors.fill: parent
        source: root.imageUrl(panel.shownBackground || root.displayedBackground)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        onStatusChanged: {
          if (status === Image.Ready && root.finishingTransition) {
            root.incomingBackground = ""
            root.oldBackground = ""
            root.finishingTransition = false
          }
          // The settled image now shows underneath; retire the fade overlay.
          if (status === Image.Ready && panel.fadingBackground && panel.fadingBackground === panel.shownBackground) {
            panel.fadingBackground = ""
          }
        }
      }

      Image {
        id: fadeFrame
        anchors.fill: parent
        source: root.imageUrl(panel.fadingBackground)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        opacity: 0
        visible: panel.fadingBackground !== ""
        onStatusChanged: {
          if (status === Image.Ready && panel.fadingBackground && panel.fadingBackground !== panel.shownBackground) {
            fadeIn.restart()
          }
        }

        NumberAnimation {
          id: fadeIn
          target: fadeFrame
          property: "opacity"
          from: 0
          to: 1
          duration: 1200
          easing.type: Easing.InOutQuad
          onFinished: panel.shownBackground = panel.fadingBackground
        }
      }

      Image {
        id: oldFrame
        anchors.fill: parent
        source: root.imageUrl(root.oldBackground)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        visible: root.oldBackground !== "" && root.revealProgress < 1
        onStatusChanged: panel.maybeStartReveal()
      }

      Item {
        id: incomingLayer
        anchors.fill: parent
        visible: root.incomingBackground !== "" && incomingFrame.status === Image.Ready && (root.revealProgress >= 1 || panel.maskReady)
        layer.enabled: root.incomingBackground !== "" && root.revealProgress < 1
        layer.smooth: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: revealMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 0.02
        }

        Image {
          id: incomingFrame
          anchors.fill: parent
          source: root.imageUrl(root.incomingBackground)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          smooth: true
          mipmap: true
          onStatusChanged: panel.maybeStartReveal()
        }
      }

      Item {
        id: revealMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        readonly property real slant: -0.18
        readonly property real centerTop: width / 2 - slant * height / 2
        readonly property real centerBottom: width / 2 + slant * height / 2
        readonly property real reach: width / 2 + Math.abs(slant) * height / 2 + 4
        readonly property real spread: reach * root.revealProgress

        Shape {
          anchors.fill: parent
          antialiasing: true
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "white"
            strokeColor: "transparent"
            startX: revealMask.centerTop - revealMask.spread; startY: 0
            PathLine { x: revealMask.centerTop + revealMask.spread; y: 0 }
            PathLine { x: revealMask.centerBottom + revealMask.spread; y: revealMask.height }
            PathLine { x: revealMask.centerBottom - revealMask.spread; y: revealMask.height }
            PathLine { x: revealMask.centerTop - revealMask.spread; y: 0 }
          }
        }
      }

      Connections {
        target: root
        function onIncomingBackgroundChanged() {
          panel.maskReady = false
          panel.maybeStartReveal()
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onDoubleClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) root.openThemeSwitcher()
          else root.openSelector()
          mouse.accepted = true
        }
      }
    }
  }
}
