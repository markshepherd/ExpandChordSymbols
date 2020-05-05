// Copyright (c) 2020 Mark Shepherd
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// This file contains the UI for the Expand Chord Symbols plugin.
// All the functional code and documentation is in ExpandChordSymbols.js.

import MuseScore 3.0
import QtQuick 2.1
import QtQuick.Dialogs 1.0
import QtQuick.Controls 2.1
import QtQuick.Layouts 1.1
import "ExpandChordSymbols.js" as ExpandChordSymbols

MuseScore {
    version: "3.0"
    description: "Expands chord symbols into a staff"
    menuPath: "Plugins.Expand Chord Symbols…"
    pluginType: "dialog"
    id: window
    width:  600;
    height: 500;
    property var thePattern: [];
    property var ticksPerQuarter;
    property var selectedRhythm;

    Label {
        id: textLabel1
        wrapMode: Text.WordWrap
        text: ""
        font.pointSize:15
        anchors.left: window.left
        anchors.top: window.top
        anchors.leftMargin: 10
        anchors.topMargin: 15
    }

    CheckBox {
        id:   writeCondensed
        text: "Condense chords to 5 notes or less"
        font.pointSize:15
        checked: true
        anchors.left: window.left
        anchors.top: textLabel1.bottom
        anchors.leftMargin: 10
        anchors.topMargin: 10
    }

    CheckBox {
        id:   useRhythmPattern
        text: "Use a rhythm pattern"
        font.pointSize:15
        enabled: true
        checked: false
        anchors.left: window.left
        anchors.top: writeCondensed.bottom
        anchors.leftMargin: 10
    }

    Text {
        id: addButtonsLabel
        enabled: useRhythmPattern.checked
        opacity: useRhythmPattern.checked ? 1.0 : 0.3
        text: "Click to add notes to the rhythm pattern"
        font.pointSize:12
        anchors.topMargin: 0 
        anchors.horizontalCenter: addButtonBackground.horizontalCenter
        anchors.top: useRhythmPattern.bottom
    }

    Rectangle {
        id: addButtonBackground
        height: 65
        enabled: useRhythmPattern.checked
        opacity: useRhythmPattern.checked ? 1.0 : 0.3
        width: 330
        anchors.horizontalCenter: window.horizontalCenter
        anchors.top: addButtonsLabel.bottom
        anchors.topMargin: 6
        color: "transparent"
        border.color: "black"
        border.width: 2
    }

    RowLayout {
        id: addButtons
        spacing: 20
        enabled: useRhythmPattern.checked
        opacity: useRhythmPattern.checked ? 1.0 : 0.3
        anchors.left: addButtonBackground.left
        anchors.top: addButtonBackground.top
        anchors.leftMargin: 20
        anchors.topMargin: 12
    }

    Button {
        id : buttonUseSelection
        text: "Use selection"
        enabled: !!selectedRhythm && useRhythmPattern.checked
        opacity: !!selectedRhythm && useRhythmPattern.checked ? 1.0 : 0.7
        font.pointSize:15
        anchors.top: addButtonBackground.top
        anchors.left: window.left
        anchors.leftMargin: 15
        onClicked: {
            clearPattern();
            for (var i = 0; i < selectedRhythm.length; i += 1) {
                var duration = selectedRhythm[i].duration;
                var rest = selectedRhythm[i].rest;

                addToPattern(duration, rest ? "rest" : "all");
            }
        }
    }

    Button {
        id : buttonClear
        text: "Clear"
        enabled: useRhythmPattern.checked
        opacity: useRhythmPattern.checked ? 1.0 : 0.7
        font.pointSize:15
        anchors.top: buttonUseSelection.bottom
        anchors.left: window.left
        anchors.leftMargin: 20
        anchors.topMargin: -10
        onClicked: {
            clearPattern();        
        }
    }

    Rectangle {
        id: patternBackground
        height: 100
        enabled: useRhythmPattern.checked
        opacity: useRhythmPattern.checked ? 1.0 : 0.3
        anchors.left: window.left
        anchors.right: window.right
        anchors.top: addButtonBackground.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 10
        color: "white"
        border.color: "black"
        border.width: 2
    }

    RowLayout {
        id: patternView
        spacing: 10
        enabled: useRhythmPattern.checked
        opacity: useRhythmPattern.checked ? 1.0 : 0.3
        anchors.left: patternBackground.left
        anchors.top: patternBackground.top
        anchors.leftMargin: 20
        anchors.topMargin: 8
    }

    Text {
        id: label3
        enabled: useRhythmPattern.checked
        opacity: useRhythmPattern.checked && patternView.children.length > 0 ? 1.0 : 0.3
        text: "Click on the chords to change voicing"
        font.pointSize:12
        anchors.horizontalCenter: patternBackground.horizontalCenter
        anchors.top: patternBackground.bottom
        anchors.topMargin: 5
    }

    ColumnLayout {
        id: patternRestartControl
        anchors.left: window.left
        anchors.top: label3.bottom
        anchors.leftMargin: 0
        anchors.topMargin: 0
        enabled: useRhythmPattern.checked
        opacity: useRhythmPattern.checked ? 1.0 : 0.3
        spacing: -5

        RadioButton {
            id: useEntirePattern
            checked: true
            text: qsTr("Repeat pattern over entire score")
        }
        RadioButton {
            id: restartPatternForEverySymbol
            text: qsTr("Restart pattern for every chord symbol")
        }
    }

    // Every "Add Note" button is an instance of this component
    Component {
        id: addNoteButton
    
        Image {
            id: image
            opacity: 0.6
            signal clicked(int duration)
            property int duration
            source: durationToSource(duration)

            MouseArea {
                ToolTip.delay: 1000
                ToolTip.timeout: 5000
                ToolTip.visible: containsMouse
                ToolTip.text: qsTr("Click to add this note to the pattern")
                cursorShape: Qt.PointingHandCursor                
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    if (patternView.children.length < 16) {
                        parent.opacity = 1.0;
                    }
                }
                onExited: {
                    parent.opacity = 0.6;
                }
                onClicked: {
                    if (patternView.children.length < 16) {
                        image.clicked(image.duration);
                    }
                }
            }
        }
    }

    // Every item in the rhythm pattern is an instance of this component
    Component {
        id: noteStack

        Item {
            id: item
            property string source: durationToSource(ref.duration)
            property var ref
            signal clicked(var ref)
            width: 25
            height: 88
            opacity: mouseArea.containsMouse ? 1.0 : 0.6

            MouseArea {
                id: mouseArea
                ToolTip.delay: 1000
                ToolTip.timeout: 5000
                ToolTip.visible: containsMouse
                ToolTip.text: qsTr("Click to change the chord's voicing")
                cursorShape: Qt.PointingHandCursor                
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    parent.clicked(item.ref);
                }
            }

            Image {
                visible: ref.voicing !== "bass" && ref.voicing !== "rest"
                y: 0
                source: parent.source
            }

            Image {
                visible: ref.voicing !== "bass" && ref.voicing !== "rest"
                y: 12
                source: parent.source.replace(/eighth/, "quarter") // to hide the eighth note's flag
            }

            Image {
                visible: ref.voicing !== "bass" && ref.voicing !== "rest"
                y: 24
                source: parent.source.replace(/eighth/, "quarter") // to hide the eighth note's flag
            }

            Image {
                visible: ref.voicing !== "nonbass" && ref.voicing !== "rest"
                y: 45
                source: ref.voicing === "bass" ? parent.source : parent.source.replace(/eighth/, "quarter")
            }

            Image {
                visible: ref.voicing === "rest"
                y: 24
                source: parent.source.replace(/\./, " rest.")
            }
        }   
    }

    Label {
        id: textLabel2
        wrapMode: Text.WordWrap
        text: ""
        font.pointSize:12
        color: "red"
        anchors.left: window.left
        anchors.bottom: buttonExpand.top
        anchors.leftMargin: 10
    }

    Button {
        id : buttonExpand
        text: "OK"
        anchors.bottom: window.bottom
        anchors.right: window.right
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        anchors.rightMargin: 10
        onClicked: {
            var raw = !writeCondensed.checked;
            var pattern = (useRhythmPattern.checked && thePattern.length > 0) ? thePattern : null;
            ExpandChordSymbols.expandChordSymbols(pattern, 
                {raw: raw, useEntirePattern: useEntirePattern.checked});
            Qt.quit();            
        }
    }

    Button {
        id : buttonCancel
        text: "Cancel"
        anchors.bottom: window.bottom
        anchors.right: buttonExpand.left
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        onClicked: {
            Qt.quit();
        }
    }

    Label {
        id: versionLabel
        wrapMode: Text.WordWrap
        text: "Expand Chord Symbols, Version " + version.split(/\./)[0];
        font.pointSize:9
        anchors.left: window.left
        anchors.bottom: window.bottom
        anchors.leftMargin: 10
        anchors.bottomMargin: 10
    }

    // Advance to the next voicing option: all -> bass -> nonbass -> rest -> all
    function incrementVoicing(voicing) {
        if (voicing === "all") return "bass";
        if (voicing === "bass") return "nonbass";
        if (voicing === "nonbass") return "rest";
        return "all";
    }

    // Remove all notes from the rhythm pattern
    function clearPattern() {
        thePattern = [];
        patternView.children = [];
    }

    // Change the voicing of a chord in the rhythm pattern. Each click advances to the 
    // next voicing value
    function changeVoicing(sequenceItem) {
        sequenceItem.voicing = incrementVoicing(sequenceItem.voicing);
        patternView.children[sequenceItem.index].ref = sequenceItem;
    }

    // Adds a note to the rhythm pattern
    function addToPattern(duration, voicing) {
        var tick = thePattern.length > 0 
            ? thePattern[thePattern.length - 1].tick + thePattern[thePattern.length - 1].duration
            : 0;
        var sequenceItem = {index: thePattern.length, tick: tick, duration: duration, voicing: voicing || "all"};
        thePattern.push(sequenceItem);        
        noteStack.createObject(patternView, {ref: sequenceItem}).clicked.connect(changeVoicing);
    }

    // Given a fraction duration such as 1/4 or 3/8, return the corresponding number of ticks.
    function calcDuration(numerator, denominator) {
        return (ticksPerQuarter * 4) * numerator / denominator;
    }

    // Fetch the filepath to the image that corresponds to the given duration, which is in ticks.
    function durationToSource(duration) {
        if (duration === calcDuration(1, 8)) return "images/eighth.png";
        if (duration === calcDuration(3, 16)) return "images/eighth dotted.png";
        if (duration === calcDuration(1, 4)) return "images/quarter.png";
        if (duration === calcDuration(3, 8)) return "images/quarter dotted.png";
        if (duration === calcDuration(1, 2)) return "images/half.png";
        if (duration === calcDuration(3, 4)) return "images/half dotted.png";
        if (duration === calcDuration(1, 1)) return "images/whole.png";

        return "images/unknown.png";
    }

    function createAddButton(duration) {
        addNoteButton.createObject(addButtons, {duration: duration}).clicked.connect(addToPattern);
    }

    // Initialize all the UI items relating to Rhythm Patterns
    function setupRhythmPatternUI() {
        createAddButton(calcDuration(1, 8));
        createAddButton(calcDuration(3, 16));
        createAddButton(calcDuration(1, 4));
        createAddButton(calcDuration(3, 8));
        createAddButton(calcDuration(1, 2));
        createAddButton(calcDuration(3, 4));
        createAddButton(calcDuration(1, 1));

        // Fetch the pattern in the current score selection, just in case the user wants it.
        selectedRhythm = ExpandChordSymbols.getSelectedRhythm();

        // Initialize the rhythm pattern to the last pattern used in this score.
        // If the user doesn't want this, she can simply clear it.
        var savedPattern = fetchSavedPattern();
        if (savedPattern) {
            for (var i = 0; i < savedPattern.length; i += 1) {
                var item = savedPattern[i];
                addToPattern(item.duration, item.voicing);
            }
        }
    }

    // Retrieve a pattern from Score Properties.chordrhythmpattern
    function fetchSavedPattern() {
        var savedPattern;
        try {
            savedPattern = JSON.parse(curScore.metaTag("chordrhythmpattern"));
            if (!Array.isArray(savedPattern)) {
                savedPattern = [];
            }
        } catch (e) {
            savedPattern = [];
        }

        return savedPattern.length > 0 ? savedPattern : null;
    }

    // Save a pattern to Score Properties.chordrhythmpattern
    function savePattern (pattern) {
        var trimmed = [];
        for (var i = 0; i < pattern.length; i += 1) {
            var item = pattern[i];
            trimmed.push({duration: item.duration, voicing: item.voicing});
        }
        curScore.setMetaTag("chordrhythmpattern", JSON.stringify(trimmed));
    }

    // This code runs when the plugin is invoked, before the dialog appears.
    // We initialize various items in the UI.
    onRun: {
        ticksPerQuarter = division; // take our own copy of "division" to avoid runtime warnings

        // Find out if there are any notes in the target track, which is the first voice of the last staff.
        var cursor = curScore.newCursor();
        cursor.track = curScore.ntracks - 4;
        cursor.rewind(Cursor.SCORE_START);
        var gotNotes = false;
        while (cursor.segment) {
            var e = cursor.element;
            gotNotes = cursor.element && (cursor.element.type == Element.CHORD);
            if (gotNotes) break;
            cursor.next();
        }

        // Find out which part contains the target staff.
        var partName = "???";
        for (var i = 0; i < curScore.parts.length; i++) {
            var part = curScore.parts[i];
            if ((part.startTrack <= cursor.track) && (cursor.track < part.endTrack)) {
                partName = part.longName;
            }
        }

        // Update the messages in the dialog.
        var staffName = "#" + (cursor.staffIdx + 1) + " \"" + partName + "\"";
        textLabel1.text = "Expanding chords into Staff " + staffName + ".";
        if (gotNotes) {
            textLabel2.text = "Warning: this will overwrite the contents of Staff " + staffName;
        }

        setupRhythmPatternUI();
    }
}