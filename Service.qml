import QtQuick
import Quickshell
import Quickshell.Io

// Applies a theme that was queued while Vivaldi was open, once it has closed,
// and says once if setup hasn't been run yet.
Item {
  id: root

  property var shell: null
  readonly property string home: Quickshell.env("HOME")
  readonly property string tool: home + "/.config/omarchy/plugins/io.github.danxignat.vivaldi/bin/vivaldi-omarchy"
  readonly property string marker: home + "/.local/state/vivaldi-omarchy/pending.json"

  Process {
    command: [root.tool, "first-run"]
    running: true
  }

  Process {
    id: apply
    command: ["sh", "-c", '[ -e "$1" ] && exec "$2" theme apply', "sh", root.marker, root.tool]
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!apply.running) apply.running = true
  }
}
