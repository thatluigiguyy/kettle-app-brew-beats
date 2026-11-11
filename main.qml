import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Brew Beats: a piano-roll music maker for Kettle Linux.
// Click the grid to add notes and drums, press Play, then Export to make an MP3.
// Sounds and export come from the Kettle SDK (the `kettle` object).

Rectangle {
    id: root
    width: 1060
    height: 700
    color: "#14112a"

    // ---- song layout
    readonly property int steps: 32                 // 16th notes = 2 bars
    readonly property int lowNote: 60               // C4
    readonly property int rows: 24                  // two octaves
    readonly property var names: ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    readonly property var drumNames: ["Kick", "Snare", "Hat", "Clap"]
    readonly property var drumColors: ["#ff7a59", "#ffd27f", "#8ee6a8", "#7fd4ff"]
    readonly property var instruments: ["piano", "synth", "bell", "organ"]
    readonly property var instColors: ({ piano: "#ffb347", synth: "#3fd0c9", bell: "#b98cff", organ: "#ff7a90" })
    readonly property bool hasSound: typeof kettle !== "undefined"

    // ---- song
    property var melody: []          // one entry per cell: "" or an instrument name
    property var beats: []           // one entry per drum cell: true/false
    property int bpm: 110
    property string instrument: "piano"
    property bool loop: true

    // ---- playback
    property int playStep: -1
    property bool playing: false
    readonly property string noSound: "No sound yet: Kettle needs a one-time update. See github.com/thatluigiguyy/kettle-app-brew-beats"
    property string status: hasSound ? "Click the grid to add notes, then press Play." : noSound

    function pitchOf(row) { return lowNote + rows - 1 - row }
    function rowOf(pitch) { return lowNote + rows - 1 - pitch }
    function isBlack(pitch) { return [1, 3, 6, 8, 10].indexOf(pitch % 12) >= 0 }
    function noteName(pitch) { return names[pitch % 12] + (Math.floor(pitch / 12) - 1) }
    function filled(n, value) { var a = []; for (var i = 0; i < n; i++) a.push(value); return a }
    function setCell(list, index, value) { var copy = list.slice(); copy[index] = value; return copy }
    function noteCount() { var n = 0; for (var i = 0; i < melody.length; i++) if (melody[i]) n++; return n }

    function songJson() {
        var notes = [], drums = []
        for (var i = 0; i < rows * steps; i++)
            if (melody[i])
                notes.push({ step: i % steps, pitch: pitchOf(Math.floor(i / steps)), length: 1, inst: melody[i] })
        for (var j = 0; j < 4 * steps; j++)
            if (beats[j])
                drums.push({ step: j % steps, kind: drumNames[Math.floor(j / steps)].toLowerCase() })
        return JSON.stringify({ bpm: bpm, steps: steps, notes: notes, drums: drums })
    }

    function save() {
        if (hasSound)
            kettle.save("song", JSON.stringify({ melody: melody, beats: beats, bpm: bpm, instrument: instrument }))
    }

    function load() {
        if (!hasSound) return false
        var text = kettle.load("song")
        if (!text) return false
        try {
            var s = JSON.parse(text)
            if (s.melody.length !== rows * steps || s.beats.length !== 4 * steps) return false
            melody = s.melody
            beats = s.beats
            bpm = s.bpm
            instrument = s.instrument
            return true
        } catch (e) {
            return false
        }
    }

    function demo() {
        var m = filled(rows * steps, ""), b = filled(4 * steps, false)
        var tune = [[0, 72], [2, 76], [4, 79], [6, 76], [8, 74], [10, 72], [12, 69], [14, 67],
                    [16, 72], [18, 76], [20, 79], [22, 81], [24, 79], [26, 76], [28, 74], [30, 72]]
        for (var i = 0; i < tune.length; i++) m[rowOf(tune[i][1]) * steps + tune[i][0]] = "piano"
        var bass = [[0, 60], [8, 65], [16, 67], [24, 60]]
        for (var j = 0; j < bass.length; j++) m[rowOf(bass[j][1]) * steps + bass[j][0]] = "synth"
        for (var s = 0; s < steps; s++) {
            if (s % 8 === 0) b[s] = true                   // kick
            if (s % 8 === 4) b[steps + s] = true           // snare
            if (s % 2 === 0) b[2 * steps + s] = true       // hat
        }
        b[3 * steps + 28] = true                           // clap
        melody = m
        beats = b
    }

    function clearAll() {
        stop()
        melody = filled(rows * steps, "")
        beats = filled(4 * steps, false)
        save()
        status = "Cleared. Fresh pot!"
    }

    function play() {
        if (!hasSound) { status = noSound; return }
        kettle.stop()
        stepTimer.stop()
        playStep = -1
        status = "Mixing your song..."
        kettle.playSong(songJson())
    }

    function stop() {
        playing = false
        playStep = -1
        stepTimer.stop()
        if (hasSound) kettle.stop()
        if (status.indexOf("Playing") === 0) status = "Stopped."
    }

    Component.onCompleted: {
        melody = filled(rows * steps, "")
        beats = filled(4 * steps, false)
        if (!load()) demo()
    }

    Connections {
        target: root.hasSound ? kettle : null
        function onPlaybackStarted(durationMs) {
            root.playing = true
            root.playStep = 0
            stepTimer.restart()
            root.status = "Playing ♪"
        }
        function onPlaybackFinished() {
            if (root.playing && root.loop) root.play()
            else root.stop()
        }
        function onExportFinished(path, error) {
            root.status = error ? "Export didn't work: " + error : "Saved!  " + path
        }
    }

    Timer {
        id: stepTimer
        interval: 60000 / root.bpm / 4
        repeat: true
        onTriggered: {
            if (root.playStep < root.steps - 1) root.playStep++
            else { root.playStep = -1; stop() }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ---- top bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "🎹  Brew Beats"
                color: "#ffb347"
                font.pixelSize: 22
                font.bold: true
            }
            Item { Layout.fillWidth: true }

            Button {
                text: root.playing ? "■  Stop" : "▶  Play"
                highlighted: true
                onClicked: root.playing ? root.stop() : root.play()
            }
            CheckBox {
                text: "Loop"
                checked: root.loop
                onToggled: root.loop = checked
            }
            Text { text: "BPM"; color: "#c9bfe8" }
            SpinBox {
                from: 60
                to: 200
                value: root.bpm
                editable: true
                onValueModified: { root.bpm = value; root.save() }
            }
            ComboBox {
                model: root.instruments
                currentIndex: root.instruments.indexOf(root.instrument)
                onActivated: { root.instrument = currentText; root.save() }
            }
            Button { text: "Clear"; onClicked: root.clearAll() }
            TextField {
                id: songName
                text: "My Beat"
                Layout.preferredWidth: 120
            }
            Button {
                text: root.hasSound && kettle.canMp3 ? "Export MP3" : "Export WAV"
                enabled: root.hasSound
                onClicked: {
                    root.status = "Exporting..."
                    kettle.exportSong(root.songJson(), songName.text)
                }
            }
        }

        // ---- piano roll + drums
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0d0b1c"
            radius: 10

            Item {
                id: board
                anchors.fill: parent
                anchors.margins: 10
                readonly property int keyW: 64
                readonly property real cellW: (width - keyW) / root.steps
                readonly property int drumH: 26
                readonly property real cellH: Math.max(12, (height - 4 * drumH - 16) / root.rows)
                readonly property real drumTop: root.rows * cellH + 14

                // piano keys: click to hear a note
                Repeater {
                    model: root.rows
                    Rectangle {
                        property int pitch: root.pitchOf(index)
                        x: 0
                        y: index * board.cellH
                        width: board.keyW - 6
                        height: board.cellH - 1
                        radius: 3
                        color: keyArea.pressed ? root.instColors[root.instrument]
                             : (root.isBlack(pitch) ? "#2a2540" : "#e9e6f5")
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.noteName(parent.pitch)
                            font.pixelSize: 10
                            font.bold: parent.pitch % 12 === 0
                            color: root.isBlack(parent.pitch) ? "#a9a3c9" : "#2a2540"
                        }
                        MouseArea {
                            id: keyArea
                            anchors.fill: parent
                            onPressed: if (root.hasSound) kettle.playNote(parent.pitch, root.instrument)
                        }
                    }
                }

                // note grid
                Repeater {
                    model: root.rows * root.steps
                    Rectangle {
                        property int r: Math.floor(index / root.steps)
                        property int s: index % root.steps
                        property string inst: root.melody[index] || ""
                        property bool beatStart: s % 4 === 0
                        x: board.keyW + s * board.cellW + (beatStart ? 1 : 0)
                        y: r * board.cellH
                        width: board.cellW - (beatStart ? 2 : 1)
                        height: board.cellH - 1
                        radius: 2
                        color: inst ? root.instColors[inst]
                             : (root.isBlack(root.pitchOf(r)) ? "#18142d" : (Math.floor(s / 4) % 2 ? "#1f1a3b" : "#241f45"))
                        border.width: inst && root.playStep === s ? 2 : 0
                        border.color: "white"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var on = !parent.inst
                                root.melody = root.setCell(root.melody, index, on ? root.instrument : "")
                                if (on && root.hasSound) kettle.playNote(root.pitchOf(parent.r), root.instrument)
                                root.save()
                            }
                        }
                    }
                }

                // bar lines
                Repeater {
                    model: root.steps / 16 + 1
                    Rectangle {
                        x: board.keyW + index * 16 * board.cellW - 1
                        y: 0
                        width: 2
                        height: board.drumTop + 4 * board.drumH
                        color: "#5b4fa8"
                        opacity: 0.6
                    }
                }

                // drum names: click to hear
                Repeater {
                    model: 4
                    Text {
                        x: 0
                        y: board.drumTop + index * board.drumH
                        width: board.keyW - 12
                        height: board.drumH - 3
                        text: root.drumNames[index]
                        color: root.drumColors[index]
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        MouseArea {
                            anchors.fill: parent
                            onPressed: if (root.hasSound) kettle.playDrum(root.drumNames[index].toLowerCase())
                        }
                    }
                }

                // drum grid
                Repeater {
                    model: 4 * root.steps
                    Rectangle {
                        property int d: Math.floor(index / root.steps)
                        property int s: index % root.steps
                        property bool on: root.beats[index] === true
                        property bool beatStart: s % 4 === 0
                        x: board.keyW + s * board.cellW + (beatStart ? 1 : 0)
                        y: board.drumTop + d * board.drumH
                        width: board.cellW - (beatStart ? 2 : 1)
                        height: board.drumH - 3
                        radius: 4
                        color: on ? root.drumColors[d] : (Math.floor(s / 4) % 2 ? "#1f1a3b" : "#241f45")
                        border.width: on && root.playStep === s ? 2 : 0
                        border.color: "white"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var now = !parent.on
                                root.beats = root.setCell(root.beats, index, now)
                                if (now && root.hasSound) kettle.playDrum(root.drumNames[parent.d].toLowerCase())
                                root.save()
                            }
                        }
                    }
                }

                // playhead
                Rectangle {
                    visible: root.playStep >= 0
                    x: board.keyW + root.playStep * board.cellW
                    y: 0
                    width: board.cellW
                    height: board.drumTop + 4 * board.drumH
                    color: "white"
                    opacity: 0.12
                    radius: 2
                }
            }
        }

        // ---- status bar
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: root.status
                color: "#c9bfe8"
                font.pixelSize: 13
                elide: Text.ElideMiddle
            }
            Text {
                text: root.noteCount() + " notes  ·  click the piano keys to try sounds"
                color: "#7a7499"
                font.pixelSize: 12
            }
        }
    }
}
