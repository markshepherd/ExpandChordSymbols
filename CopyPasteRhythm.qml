import MuseScore 3.0
import QtQuick 2.1
import QtQuick.Dialogs 1.3
import QtQuick.Controls 2.1
import "Utils.js" as Utils

MuseScore {
    version: "2.0"
    description: ""
    menuPath: "Plugins.Copy/Paste Rhythm…"
    pluginType: "dock"
    dockArea: "left"
    id: window
    width:  400;
    height: 250;
    property var sourceRhythm;
    property var numSourceItems;

    // -----------------------------------------------------------------------------------------------------
    // The UI
    // -----------------------------------------------------------------------------------------------------

    // Copy controls

    Label {
        id: copyPrompt1
        wrapMode: Text.WordWrap
        text: "Click"
        font.pointSize:15
        anchors.top: window.top
        anchors.topMargin: 15
        anchors.left: window.left
        anchors.leftMargin: 10
    }

    Button {
        id : buttonCopy
        text: "Copy"
        anchors.top: window.top
        anchors.topMargin: 10
        anchors.left: copyPrompt1.right
        anchors.leftMargin: 10
        background: Rectangle {
            border.color: buttonCopy.pressed ? "black" : "gray"
            border.width: 1
            radius: 5
        }
        onClicked: {
            var copyResult = doCopy();
            if (typeof copyResult == 'number') {
                copyMessage.text = "Copied " + copyResult + " items.";
                copyMessage.color = "forestgreen";
                numSourceItems = copyResult;
                pasteMessage.text = "";
                curScore.startCmd();
                curScore.selection.clear();
                curScore.endCmd();
            } else {
                copyMessage.text = errorText(copyResult) + ".";
                copyMessage.color = "red";
                numSourceItems = 0;
            }
        }
    }

    Label {
        id: copyPrompt2
        wrapMode: Text.WordWrap
        text: "to copy the rhythm of the selected notes."
        font.pointSize:15
        anchors.top: window.top
        anchors.topMargin: 15
        anchors.left: buttonCopy.right
        anchors.leftMargin: 10
    }

    Label {
        id: copyMessage
        wrapMode: Text.WordWrap
        text: ""
        font.pointSize:15
        anchors.top: copyPrompt1.bottom
        anchors.topMargin: 15
        anchors.left: window.left
        anchors.leftMargin: 10
    }

    ToolSeparator {
        id: separator
        orientation: Qt.Horizontal
        anchors.top: copyMessage.bottom
        anchors.topMargin: 10
        anchors.left: window.left
        anchors.right: window.right
    }

    // Paste controls

    Label {
        id: pastePrompt1
        enabled: !!numSourceItems
        opacity: !!numSourceItems ? 1.0 : 0.3
        wrapMode: Text.WordWrap
        text: "Click"
        font.pointSize:15
        anchors.top: separator.bottom
        anchors.topMargin: 10
        anchors.left: window.left
        anchors.leftMargin: 10
    }

    Button {
        id : buttonPaste
        enabled: !!numSourceItems
        opacity: !!numSourceItems ? 1.0 : 0.3
        text: "Paste"
        anchors.top: separator.bottom
        anchors.topMargin: 5
        anchors.left: pastePrompt1.right
        anchors.leftMargin: 10
        background: Rectangle {
            border.color: buttonPaste.pressed ? "black" : "gray"
            border.width: 1
            radius: 5
        }
        onClicked: {
            var validateResult = validateTarget(Utils.getSelectedNotes());
            if (!validateResult) {
                doPaste();
                pasteMessage.text = "Done.";
                pasteMessage.color = "forestgreen";
            } else if (validateResult === "willOverwrite") {
                overwriteDialog.open();
            } else {
                pasteMessage.text = errorText(validateResult) + ".";
                pasteMessage.color = "red";
            }
        }
    }

    Label {
        id: pastePrompt2
        enabled: !!numSourceItems
        opacity: !!numSourceItems ? 1.0 : 0.3
        wrapMode: Text.WordWrap
        text: "to paste the rhythm into the selected notes."
        font.pointSize:15
        anchors.top: separator.bottom
        anchors.topMargin: 10
        anchors.left: buttonPaste.right
        anchors.leftMargin: 10
    }

    Label {
        id: pasteMessage
        enabled: !!numSourceItems
        opacity: !!numSourceItems ? 1.0 : 0.3
        wrapMode: Text.WordWrap
        text: ""
        font.pointSize:15
        anchors.top: pastePrompt1.bottom
        anchors.topMargin: 15
        anchors.left: window.left
        anchors.leftMargin: 10
    }


    // Other stuff

    Label {
        id: versionLabel
        wrapMode: Text.WordWrap
        font.pointSize:9
        anchors.bottom: window.bottom
        anchors.bottomMargin: 10
        anchors.right: window.right
        anchors.rightMargin: 10
    }

    MessageDialog {
        id: overwriteDialog
        visible: false
        title: "Overwrite?"
        icon: StandardIcon.Question
        text: "One or more notes that follow the paste selection will be overwritten. OK to overwrite?"
        // detailedText: "blah blah blah."
        standardButtons: StandardButton.Yes | StandardButton.No
        Component.onCompleted: visible = true
        onYes: {
            doPaste();
            pasteMessage.text = "Done.";
            pasteMessage.color = "forestgreen";
        }
        onNo: {
            pasteMessage.text = "Paste cancelled";
            pasteMessage.color = "red";
        }
    }

    function errorText(error) {
        if (error === "noSelection") return "The selection must contain at least one item";
        if (error === "hasTuplets") return "The selection may not contain a tuplet";
        if (error === "targetSpansMeasures") return "The result will cross a measure boundary; this is not allowed";
        if (error === "firstTargetTie") return "The first selected note may not be tied to a previous note";
        if (error === "wrongNumItems") return "The selection must contain exactly " + numSourceItems + " items";
        if (error === "differentTracks") return "The selection may not contain multiple staffs or multiple voices";
        if (error === "otherVoices") return "The selected measure may not contain multiple voices";
        return "Unknown error";
    }

    // -----------------------------------------------------------------------------------------------------
    // The Code
    // -----------------------------------------------------------------------------------------------------

    // Captures the rhythm pattern of the current selection into the global variable "sourceRhythm".
    // Returns error if the pattern contains 0 notes, or contains tuplets.
    function doCopy() {
        sourceRhythm = Utils.getSelectedRhythm();
        if (!sourceRhythm || !sourceRhythm.length) {
            return "noSelection"
        }
        if (sourceRhythm[0].hasTuplets) {
            return "hasTuplets";
        }
        return sourceRhythm.length;
    }

    // Validate the target selection.
    function validateTarget(target) {
        // The target must contain at least one item
        if (!target || !target.notes.length) {
            return "wrongNumItems";
        }

        // The first item of the target must not be tied to a previous item
        if (target.notes[0].tieBack) {
            return "firstTargetTie";
        }

        // Updated target must not cross measure boundary
        var firstItem = target.notes[0];
        var sourceDuration = sourceRhythm.reduce(function(acc, x) {return acc + x.duration;}, 0);
        var lastTick = Utils.getTick(firstItem) + sourceDuration - 1;
        var startMeasure = Utils.getMeasure(firstItem);
        var endMeasure = Utils.measureContaining(lastTick);
        if (!startMeasure.is(endMeasure)) {
            return "targetSpansMeasures"
        }

        // Loop over the target items.
        var track;
        var prevTargetNoteTick;
        var numItems = 0;
        for (var i = 0; i < target.notes.length; i += 1) {
            var targetNote = target.notes[i];

            // All notes must in the same track
            if (i > 0 && track !== targetNote.track) {
                return "differentTracks"
            }
            track = targetNote.track;

            // A target item many not be part of a tuplet.
            if (targetNote.tuplet || targetNote.parent.tuplet) { // for notes, we need to check the parent Chord
                return "hasTuplets";
            }

            // Count the target items. We ignore items that are tied to a previous one,
            // or that occur at the same time as the previous one.
            if (!targetNote.tieBack && (prevTargetNoteTick !== Utils.getTick(targetNote))) {
                numItems += 1;
            }
            prevTargetNoteTick = Utils.getTick(targetNote);
        }

        // The number of source and target items must be the same.
        if (numItems !== sourceRhythm.length) {
            return "wrongNumItems";
        }

        // No other voices may exist in the target area
        var segment = startMeasure.firstSegment;
        while (segment) {
            for (var i = 0; i < 4; i += 1) {
                var thisTrack = (target.staff * 4) + i;
                if (track != thisTrack) {
                    if (segment.elementAt(thisTrack)) {
                        return "otherVoices";
                    }
                }
            }
            segment = segment.nextInMeasure;
        }

        // If one or more notes that follow the target will be overwritten, we should
        // warn the user and allow her to cancel.
        var lastItem = target.notes[target.notes.length - 1];
        var segment = Utils.getSegment(lastItem).nextInMeasure;
        while (segment) {
            if (segment.segmentType.toString() === "ChordRest") {
                var element = segment.elementAt(track);
                if (element && element.type === Element.CHORD && segment.tick <= lastTick) {
                    return "willOverwrite";
                }
            }
            segment = segment.nextInMeasure;
        }
    }

    // Pastes the previously-captured rhythm pattern into the current selection.
    function doPaste() {
        // Terminology:
        // "source" is the rhythm pattern that was captured by doing Copy
        // "target" is the set of items to which the rhythm pattern will be Pasted
        // "item" is either a note or a rest. The source and target may contain either kind. 
        // "temp" is the temporary area where we assemble the updated notes

        // Capture the target selection into "target".
        var target = Utils.getSelectedNotes();

        // Create a temp area at the end of the score, where we will assemble the updated target notes.
        // Workaround: we only need one measure, but we insert 2 measures because something wasn't working
        // right when the temp measure was the last measure of the score (I think it failed to delete?).
        curScore.startCmd();
        curScore.appendMeasures(2);
        curScore.endCmd();
        var tempMeasure = curScore.lastMeasure.prevMeasure;

        // keep track of the total duration of all the updated notes, so far
        var filledDuration = 0;

        // Process the target notes one at a time.
        var prevTargetNoteTick;
        var sourceIndex = 0;
        for (var j = 0; j < target.notes.length; j += 1) {
            var targetNote = target.notes[j];

            // If the target note has the same time as the previous target note,
            // then we should skip it - all notes at that time have already been handled.
            if (prevTargetNoteTick && (prevTargetNoteTick === Utils.getTick(targetNote))) {
                continue;
            }
            prevTargetNoteTick = Utils.getTick(targetNote);

            // If several target notes are tied together, we consider them a single note.
            // Therefore, if the current note is tied to a previous note, we ignore it.
            if (targetNote.tieBack) {
                continue;
            }

            // Copy the target  to the clipboard.
            // This includes all the item's attributes, such as articulation, lyrics, etc,
            // and all the notes in the same chord.
            Utils.selectNote(targetNote);
            cmd("copy");

            // Paste the target item to the temp area. This could be either a note or a rest.
            curScore.selection.select(Utils.findItemAtOffset(tempMeasure, target.track, filledDuration));
            cmd("paste");

            // Find the item we just pasted.
            var tempItem = Utils.findItemAtOffset(tempMeasure, target.track, filledDuration);

            // Find the next item in the rhythm pattern. 
            var sourceNote = sourceRhythm[sourceIndex++];

            // The source item might actually be a series of one or more notes tied together,
            // This is specified in "sourceNote.durations".
            // Set the temp item's duration equal to the first item of the source series ...
            curScore.selection.select(tempItem);
            Utils.setItemDuration(sourceNote.durations[0]);
            filledDuration += sourceNote.durations[0];

            // Keep track of our progess through the source series
            var newNotes = [tempItem];
            var prev = tempItem;

            // Append all subsequent items in the source series
            for (var k = 1; k < sourceNote.durations.length; k += 1) {
                if(prev.name !== "Rest") {
                    // The target is a note.

                    // Select the previous note of the series
                    curScore.selection.select(prev);

                    // Now we do a sequence of simulated UI commands...
                    // ... go into note input mode
                    cmd("note-input");
                    // ... click the appropriate note button in the Note Input toolbar
                    Utils.setItemDuration(sourceNote.durations[k]);
                    // ... click the "tie" button to create a note of the desired duration and tie it to prev
                    cmd("tie");
                    // ... get out of note input mode
                    cmd("escape");

                    // grab the note we just created 
                    prev = Utils.findItemAtOffset(tempMeasure, target.track, filledDuration);
                } else {
                    // The target is a rest. We cannot tie rests together, but no problem --
                    // Just grab the rest at the appropriate location...
                    prev = Utils.findItemAtOffset(tempMeasure, target.track, filledDuration);

                    // ...and set its duration
                    curScore.selection.select(prev);
                    Utils.setItemDuration(sourceNote.durations[k]);
                }
                newNotes.push(prev);
                filledDuration += sourceNote.durations[k];
            }
        }

        // The temp area now has the exact contents we want.

        // Delete the original target contents
        curScore.selection.selectRange(target.beginTick, target.endTick, target.staff, target.staff + 1);
        cmd("delete");

        // Copy the new contents from the temp area
        curScore.selection.selectRange(tempMeasure.firstSegment.tick, tempMeasure.firstSegment.tick + filledDuration,
            target.staff, target.staff + 1);
        cmd("copy");

        // Paste the new contents into the target area
        // BTW, at this point, the first Rest of the target area is already selected as a non-range selection,
        // perhaps left over from the cmd(delete) above. But why is there both a range and a non-range selection!?
        var newTarget = Utils.findNoteAtTick(target.beginTick, target.track);
        curScore.selection.select(newTarget);
        cmd("paste");

        // Delete the temp area
        curScore.selection.selectRange(tempMeasure.firstSegment.tick, curScore.lastSegment.tick + 1,
            target.staff, target.staff + 1);
        cmd("time-delete");

        // Select the new contents of the target area. We have to dance around a bit in order to coax
        // the score view to scroll so that the selection is visible
        curScore.selection.selectRange(target.beginTick, target.beginTick + filledDuration,
            target.staff, target.staff + 1);
        cmd("get-location");
        curScore.selection.selectRange(target.beginTick, target.beginTick + filledDuration,
            target.staff, target.staff + 1);
    }

    function okMuseScoreVersion() {
        // console.log("mscoreVersion", mscoreVersion);
        // console.log("mscoreMajorVersion", mscoreMajorVersion);
        // console.log("mscoreMinorVersion", mscoreMinorVersion);
        // console.log("mscoreUpdateVersion", mscoreUpdateVersion);

        // We require MuseScore 3.5 with PR https://github.com/musescore/MuseScore/pull/6091
        return curScore.selection.selectRange !== undefined
            && curScore.selection.select !== undefined
            && curScore.selection.isRange !== undefined;
    }

    onRun: {
        overwriteDialog.visible = false;
        versionLabel.text = "Copy/Paste Rhythm, Version " + version.split(/\./)[0];
        if (!okMuseScoreVersion()) {
            copyPrompt.text = "This plugin requires a newer version of MuseScore.";
            copyPrompt.color = "red";            
            buttonCopy.visible = false;
        }
    }

    /*
    to do:
        analytics
        startCmd/endCmd
        test for tuplets (using build with tuplets AND selections available)
        implement tuplets
        document all bugs and usability issues in MuseScore and in new selection API

    test plan:
        make selection with click-select or shift-select
        after we finished, the updated target should be visible and selected
        Ok to overwrite? message should happen when appropriate

    select bugs:
        selectRange : to select entire last measure, endTick must be 1 past the end of score.

    plugin api issues:
        I get these error messages when doing cmd("time-delete")
            Debug: tick2measureMM 19201 (max 17280) not found
            Debug: tick2leftSegment(): not found tick 19201
        when I play to end, musescore crashes in MasterScore::setPos - Q_ASSERT(tick <= lastMeasure()->endTick()); 
        ocnl crash in void MuseScore::changeState() when val == STATE_NOTE_ENTRY_METHOD_STEPTIME
    */
}
