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

    // -----------------------------------------------------------------------------------------------------
    // The UI
    // -----------------------------------------------------------------------------------------------------

    function copyMode() {
        textLabel1.text = "Select the notes to copy the rhythm from, then click Copy.";
        buttonDoIt.text = "Copy";
        buttonCancel.text = "Done";
    }

    function pasteMode() {
        buttonDoIt.text = "Paste";
        buttonCancel.text = "Cancel";
    }

    Label {
        id: textLabel1
        wrapMode: Text.WordWrap
        text: ""
        font.pointSize:12
        anchors.left: window.left
        anchors.top: window.top
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
            if (buttonDoIt.text === "Copy") {
                var numNotes = doCopy();
                if (numNotes) {
                    pasteMode();
                    textLabel1.text = "Copied " + numNotes + " notes.\n\nNow select the notes to paste the rhythm into, then click Paste.";
                } else {
                    textLabel1.text = "There are no notes selected.\n\nPlease select 1 or more notes to copy the rhythm from, them click Copy.";
                }
            } else {
                var err = doPaste();
                if (!err) {
                    copyMode();
                } else if (err === "noselection") {
                    textLabel1.text = "There are no notes selected.\n\nPlease select 1 or more notes to paste the rhythm into, them click Paste.";
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

    // -----------------------------------------------------------------------------------------------------
    // The Code
    // -----------------------------------------------------------------------------------------------------

    // Captures the rhythm pattern of the current selection into the global variable "sourceRhythm".
    // Returns true iff the pattern contains at least 1 note.
    function doCopy() {
        sourceRhythm = Utils.getSelectedRhythm();
        return sourceRhythm && sourceRhythm.length;
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
        if (!target || !target.notes.length) {
            return "noselection";
        }

        // Validate the target selection.
        // ... TODO ...
        // first note must not be tieback
        // updated target must not cross measure boundary
        // all target notes must be in same track
        // no other voices can exist in the target area
        // must have same number of notes as source
        // no tuplets in target
        // no tuplets in source
        // warn if we will overwrite 1 or more notes that follow the target

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

    onRun: {
        copyMode();
    }

    /*
    to implement:
        validation of source/target
        startCmd/endCmd
        check for sufficient version of MuseScore
        better UI layout, larger font

    test plan:
        make selection with click-select or shift-select
        after we finished, the updated target should be visible and selected
        test all validation violations

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
