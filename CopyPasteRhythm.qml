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
        text: "Done"
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


    function doCopy() {
        Utils.ensureSelectionIsRange();
        sourceRhythm = Utils.getSelectedRhythm();
        return sourceRhythm && sourceRhythm.length;
    }

    function doPaste() {
        // console.log("------------- 1");
        Utils.ensureSelectionIsRange();
        var target = Utils.getSelectedNotes();
        if (!target || !target.notes.length) {
            return "noselection";
        }

        curScore.startCmd();
        curScore.appendMeasures(2);
        curScore.endCmd();
        // console.log("------------- 2");

        var filledDuration = 0;
        var tempMeasure = curScore.lastMeasure.prevMeasure;
        for (var j = 0; j < target.notes.length; j += 1) {
            var targetNote = target.notes[j];
            if (targetNote.tieBack) {
                continue;
            }

            // dumpElement("copying target", targetNote);
            Utils.selectNote(targetNote);
            cmd("copy");
            // console.log("------------- 3");

            curScore.selection.select(Utils.findItemAtOffset(tempMeasure, target.track, filledDuration));
            cmd("paste");
            // console.log("------------- 4");

            var sourceNote = sourceRhythm[j];
            var newNotes = [];
            var prev;
            for (var k = 0; k < sourceNote.durations.length; k += 1) {
                if (k == 0) {
                    var tempItem = Utils.findItemAtOffset(tempMeasure, target.track, filledDuration);
                    // console.log("------------- 5");
                    curScore.selection.select(tempItem);
                    Utils.setItemDuration(sourceNote.durations[k]);
                    filledDuration += sourceNote.durations[k];
                    prev = tempItem;
                    // Utils.dumpElement("prev 1", prev);
                    // console.log("------------- 6");
                } else {
                    if(prev.name === "Rest") {
                        // console.log("------------- 7");

                        var tempRest = Utils.findItemAtOffset(tempMeasure, target.track, filledDuration);
                        curScore.selection.select(tempRest);
                        Utils.setItemDuration(sourceNote.durations[k]);
                        // Utils.dumpElement("prev 2", prev);
                        prev = tempRest;
                    } else {
                        // console.log("------------- 8");
                        curScore.selection.select(prev);
                        cmd("note-input");
                        Utils.setItemDuration(sourceNote.durations[k]);
                        cmd("tie");
                        cmd("escape");
                        prev = Utils.findItemAtOffset(tempMeasure, target.track, filledDuration);
                        // Utils.dumpElement("prev 3", prev);
                    }
                    filledDuration += sourceNote.durations[k];
                }
                newNotes.push(prev);
            }
        }

        // console.log("------------- 9");

        // The temp area now has the exact contents we want.

        // Delete the original target contents
        // console.log("selectRange", target.beginTick, target.endTick, target.staff, target.staff + 1);
        curScore.selection.selectRange(target.beginTick, target.endTick, target.staff, target.staff + 1);
        cmd("delete");

        // Copy the new contents from the temp area
        curScore.selection.selectRange(tempMeasure.firstSegment.tick, tempMeasure.firstSegment.tick + filledDuration,
            target.staff, target.staff + 1);
        cmd("copy");
        // console.log("------------- 10");

        // Paste the new contents into the target area
        // BTW, at this point, the first Rest of the target area is already selected as a non-range selection,
        // perhaps left over from the cmd(delete) above. But why is there both a range and a non-range selection!?
        var newTarget = Utils.findNoteAtTick(target.beginTick, target.track);
        // Utils.dumpElement("newTarget", newTarget);
        // console.log("nt", newTarget);
        curScore.selection.select(newTarget);
        cmd("paste");
        // console.log("------------- 11");

        // Delete the temp area
        curScore.selection.selectRange(tempMeasure.firstSegment.tick, curScore.lastSegment.tick + 1,
            target.staff, target.staff + 1);
        cmd("time-delete");
        // console.log("------------- 12");

        // Select the new contents of the target area
        cmd("escape"); // this seems to make it work better
        // console.log("final selectRange", target.beginTick, target.beginTick + filledDuration,
        //     target.staff, target.staff + 1);
        // curScore.selection.selectRange(target.beginTick, target.beginTick + filledDuration,
        //     target.staff, target.staff + 1);
        //cmd("get-location"); // this seems to scroll the view so that the selection kind-of is visible
        // console.log("------------- 13");

        var updatedTarget = Utils.findNoteAtTick(target.beginTick, target.track);
        // Utils.dumpElement("updatedTarget", updatedTarget);
        curScore.selection.select(updatedTarget);

        // console.log("final selectRange", target.beginTick, target.beginTick + filledDuration,
        //     target.staff, target.staff + 1);
        curScore.selection.selectRange(target.beginTick, target.beginTick + filledDuration,
            target.staff, target.staff + 1);
        cmd("get-location"); // this seems to scroll the view so that the selection kind-of is visible
        // console.log("------------- 14");
        // console.log("final selectRange", target.beginTick, target.beginTick + filledDuration,
        //     target.staff, target.staff + 1);
        curScore.selection.selectRange(target.beginTick, target.beginTick + filledDuration,
            target.staff, target.staff + 1);
        // console.log("------------- 15");
    }

    /*
        startCmd/endCmd

        allow click-select of 1 note, instead of range-select

        after we finished, the score scrolls to the last measure

        chords

        tuplets

        selectRange : to select entire last meaure, endTick must be 1 past the end of score. 
        I get these error messages when doing cmd("time-delete")
            Debug: tick2measureMM 19201 (max 17280) not found
            Debug: tick2leftSegment(): not found tick 19201
        and when I play to end, musescore crashes in MasterScore::setPos - Q_ASSERT(tick <= lastMeasure()->endTick()); 

        ocnl crash in void MuseScore::changeState() when val == STATE_NOTE_ENTRY_METHOD_STEPTIME

        check for sufficient version of MuseScore

        (check target selection)
        (    must have same number of notes as source)
        (    must have same duration as source)
        (    must all be in same track)

        for each target chord (throw away all notes that are tied to each chord)
    */

    onRun: {
        copyMode();
    }
}
