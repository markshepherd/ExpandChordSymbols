import MuseScore 3.0
import QtQuick 2.1
import QtQuick.Dialogs 1.0
import QtQuick.Controls 1.1
import "Utils.js" as Utils

MuseScore {
    version: "1.0"
    description: ""
    menuPath: "Plugins.Copy/Paste Rhythm…"
    pluginType: "dock"
    dockArea: "left"
    id: window
    width:  200;
    height: 200;
    property var sourceRhythm;
    property var numSourceItems;
    property var mode;

    // -----------------------------------------------------------------------------------------------------
    // The UI
    // -----------------------------------------------------------------------------------------------------

    Label {
        id: textLabel1
        wrapMode: Text.WordWrap
        text: ""
        color: "black"
        font.pointSize:15
        anchors.left: window.left
        anchors.top: window.top
        anchors.leftMargin: 10
        anchors.topMargin: 15
    }

    Label {
        id: textLabel2
        wrapMode: Text.WordWrap
        text: ""
        font.pointSize:15
        anchors.left: window.left
        anchors.top: textLabel1.bottom
        anchors.leftMargin: 10
        anchors.topMargin: 10
    }

    Button {
        id : buttonDoIt
        text: ""
        anchors.bottom: window.bottom
        anchors.right: window.right
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        anchors.rightMargin: 10
        onClicked: {
            if (mode === "copy") {
                var copyResult = doCopy();
                if (typeof copyResult == 'number') {
                    numSourceItems = copyResult;
                    pasteMode();
                } else {
                    textLabel1.text = errorText(copyResult) + ".";
                    textLabel1.color = "red";
                }
            } else { // mode === "paste"
                var pasteResult = doPaste();
                if (!pasteResult) {
                    copyMode();
                } else {
                    textLabel1.text = errorText(pasteResult) + ".";
                    textLabel1.color = "red";
                }
            }
        }
    }

    Button {
        id : buttonCancel
        text: ""
        anchors.bottom: window.bottom
        anchors.right: buttonDoIt.left
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        onClicked: {
            if (text === "Done") {
                Qt.quit();
            } else {
                copyMode();
            }
        }
    }

    Label {
        id: versionLabel
        wrapMode: Text.WordWrap
        text: "Copy/Paste Rhythm, Version " + version.split(/\./)[0];
        font.pointSize:9
        anchors.left: window.left
        anchors.bottom: window.bottom
        anchors.leftMargin: 10
        anchors.bottomMargin: 10
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

    function copyMode() {
        mode = "copy";
        textLabel1.text = "";
        textLabel2.text = "Select the notes to copy the rhythm from, then click Copy.";
        buttonDoIt.text = "Copy";
        buttonCancel.text = "Done";
    }

    function pasteMode() {
        mode = "paste";
        textLabel1.text = "Copied " + numSourceItems + " notes.";
        textLabel1.color = "forestgreen";
        textLabel2.text = "Select the notes to paste the rhythm into, then click Paste.";
        buttonDoIt.text = "Paste";
        buttonCancel.text = "Cancel";
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
            return "noSelection";
        }

        // The first item of the target must not be tied to a previous item
        if (target.notes[0].tieBack) {
            return "firstTargetTie";
        }

        var firstItem = target.notes[0];
        var lastItem = target.notes[target.notes.length - 1];
        var targetDuration = Utils.getTick(lastItem) - Utils.getTick(firstItem) + Utils.getDuration(lastItem);
        if (targetDuration < sourceRhythm.duration) {
            // TODO: 1 or more items that follow the target will be overwritten. If any of these items
            // is a note, we should warn the user and allow them to cancel.
        }

        // Updated target must not cross measure boundary
        var sourceDuration = sourceRhythm.reduce(function(acc, x) {return acc + x.duration;}, 0);
        var startMeasure = Utils.getMeasure(firstItem);
        var endMeasure = Utils.measureContaining(Utils.getTick(firstItem) + sourceDuration - 1);
        if (!startMeasure.is(endMeasure)) {
            return "targetSpansMeasures"
        }

        // Loop over the target items.
        var track;
        var prevTargetNoteTick;
        var numItems = 0;
        for (var i = 0; i < target.notes.length; i += 1) {
            var targetNote = target.notes[i];

            console.log(i, targetNote.track);
            Utils.dumpElement("targetNote", targetNote);
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

        // Validate the target selection.
        var error = validateTarget(target);
        if (error) {
            return error;
        }

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
        return curScore.selection.selectRange
            && curScore.selection.select
            && curScore.selection.isRange;
    }

    onRun: {
        if (okMuseScoreVersion()) {
            copyMode();
        } else {
            textLabel1.text = "This plugin requires a newer version of MuseScore.";
            textLabel1.color = "red";            
            buttonDoIt.visible = false;
            buttonCancel.text = "Done";
        }
    }

    /*
    to implement:
        analytics
        startCmd/endCmd
        test for tuplets (using build with tuplets AND selections available)
        implement tuplets!
        document all bugs and usability issues in MuseScore and in new selection API

    test plan:
        make selection with click-select or shift-select
        after we finished, the updated target should be visible and selected

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
