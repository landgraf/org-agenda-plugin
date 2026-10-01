import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.landgraf.org-agenda"
  ipcTarget: ""
  manageIpc: false

  property var snapshot: Model.emptySnapshot()
  property var anchorItem: null
  property var hostWidget: null
  property double nowMs: Date.now()
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Color.muted
  readonly property color hoverFill: Style.hoverFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string error: snapshot ? String(snapshot.error || "") : ""
  readonly property var days: Model.visibleDays(root.snapshot)
  readonly property var nextItems: snapshot && Array.isArray(snapshot.next) ? snapshot.next : []
  readonly property string nextKeyword: hostWidget ? hostWidget.nextKeyword : "NEXT"
  readonly property bool collecting: hostWidget ? hostWidget.collecting === true : false
  readonly property string checkedLabel: {
    var age = snapshot ? Model.relativeTime(snapshot.generatedAt, root.nowMs) : ""
    return age === "" ? "Not loaded yet" : "Updated " + age
  }

  function itemColor(item) {
    if (item.done === true) return root.dim
    if (Model.isUrgent(item)) return root.urgent
    if (item.type === "upcoming-deadline") return root.accent
    return root.foreground
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function refresh() {
    if (root.hostWidget && root.hostWidget.refresh) root.hostWidget.refresh()
  }

  function openAgenda() {
    if (root.hostWidget && root.hostWidget.openAgenda) root.hostWidget.openAgenda()
    root.close()
  }

  function openItem(item) {
    if (!item || !item.file) return
    Quickshell.execDetached(["emacsclient", "-n", "-c", "-a", "", "+" + (parseInt(item.line, 10) || 1), String(item.file)])
    root.close()
  }

  onOpenedChanged: {
    if (root.opened) {
      root.nowMs = Date.now()
      root.refresh()
    }
  }

  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  component ItemRow: Rectangle {
    id: row

    required property var modelData

    width: content.width
    implicitHeight: rowLabels.implicitHeight + Style.space(10)
    radius: Style.space(6)
    color: rowMouse.containsMouse ? root.hoverFill : "transparent"

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.openItem(row.modelData)
    }

    Text {
      id: rowGlyph
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(20)
      horizontalAlignment: Text.AlignHCenter
      text: Model.glyph(row.modelData)
      textFormat: Text.PlainText
      color: root.itemColor(row.modelData)
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Column {
      id: rowLabels
      anchors.left: rowGlyph.right
      anchors.leftMargin: Style.space(8)
      anchors.right: rowWord.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      Text {
        width: parent.width
        text: String(row.modelData.title || "")
        textFormat: Text.PlainText
        color: row.modelData.done === true ? root.dim : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.strikeout: row.modelData.done === true
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: Model.meta(row.modelData)
        textFormat: Text.PlainText
        color: Model.isUrgent(row.modelData) ? root.urgent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Text {
      id: rowWord
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: String(row.modelData.todo || "")
      textFormat: Text.PlainText
      color: root.itemColor(row.modelData)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 0.8
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem ? root.anchorItem : root
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: root.openAgenda()
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        else if (t === "a" || t === "A") root.openAgenda()
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: content
          width: scroll.width
          spacing: Style.space(10)

          Item {
            width: parent.width
            implicitHeight: heroLabels.implicitHeight

            Column {
              id: heroLabels
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: "Org Agenda"
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                width: parent.width
                text: (Model.tooltip(root.snapshot).replace(/^Org agenda: /, "") + " · " + root.checkedLabel).toUpperCase()
                textFormat: Text.PlainText
                color: root.error !== "" ? root.urgent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
              }
            }
          }

          Repeater {
            model: root.error === "" ? root.days : []

            delegate: Column {
              id: dayBlock
              required property var modelData
              width: content.width
              spacing: Style.space(2)

              PanelSeparator { width: parent.width }

              PanelSectionHeader {
                width: parent.width
                text: Model.dayLabel(dayBlock.modelData).toUpperCase()
                foreground: root.foreground
                fontFamily: root.fontFamily
                bottomPadding: Style.space(4)
              }

              Repeater {
                model: dayBlock.modelData.items || []
                delegate: ItemRow {}
              }

              Text {
                visible: !dayBlock.modelData.items || dayBlock.modelData.items.length === 0
                width: parent.width
                text: "Nothing scheduled"
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                leftPadding: Style.space(8)
              }
            }
          }

          Column {
            visible: root.error === "" && root.nextItems.length > 0
            width: parent.width
            spacing: Style.space(2)

            PanelSeparator { width: parent.width }

            PanelSectionHeader {
              width: parent.width
              text: (root.nextKeyword + " actions").toUpperCase()
              foreground: root.foreground
              fontFamily: root.fontFamily
              bottomPadding: Style.space(4)
            }

            Repeater {
              model: root.nextItems
              delegate: ItemRow {}
            }
          }

          PanelSeparator { width: parent.width }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Refresh · R"
              iconText: "↻"
              iconSpinning: root.collecting
              foreground: root.foreground
              fontFamily: root.fontFamily
              focusable: true
              bordered: true
              enabled: !root.collecting
              onClicked: root.refresh()
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Open agenda · A"
              iconText: ""
              foreground: root.foreground
              fontFamily: root.fontFamily
              focusable: true
              bordered: true
              onClicked: root.openAgenda()
            }
          }
        }
      }
    }
  }
}
