import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.landgraf.org-agenda"

  property var snapshot: Model.emptySnapshot()

  readonly property int refreshSec: Math.max(30, parseInt(setting("refreshIntervalSec", 300), 10) || 300)
  readonly property int days: Math.min(31, Math.max(1, parseInt(setting("days", 7), 10) || 7))
  readonly property string nextKeyword: String(setting("nextKeyword", "NEXT"))
  readonly property string collector: Model.fileUrlToPath(Qt.resolvedUrl("collect.sh"))
  readonly property bool collecting: collectProc.running
  readonly property bool urgent: Model.urgentCount(root.snapshot) > 0

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("snapshot" in target) target.snapshot = root.snapshot
  }

  function applySnapshot(raw) {
    var next = Model.parseSnapshot(raw)
    if (!next) return
    root.snapshot = next
    if (panelLoader.item && "snapshot" in panelLoader.item)
      panelLoader.item.snapshot = next
  }

  function refresh() {
    if (!collectProc.running) collectProc.running = true
  }

  function openAgenda() {
    Quickshell.execDetached(["emacsclient", "-n", "-c", "-a", "", "--eval", "(progn (org-agenda-list) (delete-other-windows))"])
  }

  function handlePress(buttonId) {
    if (buttonId === Qt.MiddleButton) {
      root.refresh()
      return
    }
    if (buttonId === Qt.RightButton) {
      root.openAgenda()
      return
    }
    root.togglePanel()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onSnapshotChanged: injectPanel()

  Process {
    id: collectProc
    command: [root.collector, String(root.days), root.nextKeyword]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySnapshot(text)
    }
    stderr: StdioCollector {
      id: collectStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        console.warn("org-agenda collector failed", exitCode, String(collectStderr.text || "").trim())
    }
  }

  Timer {
    interval: root.refreshSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Org files are saved by Emacs; pick the change up without waiting for the timer.
  Process {
    id: watchProc
    running: true
    command: [Model.fileUrlToPath(Qt.resolvedUrl("watch.sh"))]
    stdout: SplitParser {
      onRead: debounce.restart()
    }
  }

  Timer {
    id: debounce
    interval: 1500
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.landgraf.org-agenda"

    function refresh(): void { root.refresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.barText(root.snapshot)
    tooltipText: Model.tooltip(root.snapshot)
    useActiveColor: true
    active: root.urgent

    onPressed: function(b) { root.handlePress(b) }
  }
}
