import MuseScore 3.0
import QtQuick 2.1
import QtQuick.Dialogs 1.0
import QtQuick.Controls 1.1
import "Utils.js" as Utils

MuseScore {
    version: "1.0"
    description: ""
    menuPath: "Plugins.Copy/Paste Rhythm…"
    pluginType: "dialog"
    id: window
    width:  500;
    height: 200;
    property var sourceRhythm;

    // -----------------------------------------------------------------------------------------------------
    // The UI
    // -----------------------------------------------------------------------------------------------------

    Label {
        id: textLabel1
        wrapMode: Text.WordWrap
        text: "Select the notes to copy the rhythm from, then click Copy."
        font.pointSize:12
        anchors.left: window.left
        anchors.top: window.top
        anchors.leftMargin: 10
        anchors.topMargin: 10
    }

    Button {
        id : buttonDoIt
        text: "Copy"
        anchors.bottom: window.bottom
        anchors.right: window.right
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        anchors.rightMargin: 10
        onClicked: {
            if (buttonDoIt.text === "Copy") {
                var numNotes = doCopy();
                if (numNotes) {
                    textLabel1.text = "You selected " + numNotes + " notes.\n\nPlease select the notes to paste the rhythm into, then click Paste.";
                    buttonDoIt.text = "Paste";
                } else {
                    textLabel1.text = "There are no notes selected.\n\nPlease select 1 or more notes to copy the rhythm from, them click Copy.";
                }
            } else {
                var err = doPaste();
                if (!err) {
                    Qt.quit();
                } else if (err === "noselection") {
                    textLabel1.text = "There are no notes selected.\n\nPlease select 1 or more notes to paste the rhythm into, them click Paste.";
                }
            }
        }
    }

    Button {
        id : buttonCancel
        text: "Cancel"
        anchors.bottom: window.bottom
        anchors.right: buttonDoIt.left
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        onClicked: {
            Qt.quit();
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

    function findItemAtOffset(measure, track, offset) {
        var segment = measure.firstSegment;
        var startTime = segment.tick;
        var count = 0;
        while (segment) {
            var element = segment.elementAt(track)  ;
            if (((segment.tick - startTime) === offset) && element && (element.type === Element.REST || element.type === Element.CHORD)) {
                if (element.type === Element.CHORD) {
                    element = element.notes[0];
                }

                return element;
            }
            segment = segment.nextInMeasure;
            if (++count > 100) {
                console.log("findItemAtOffset loop!!");
                return null;
            }
        }
        console.log("findItemAtOffset result null");
        return null;
    }

    function setItemDuration(duration) {
        var cmds = {};
        cmds[division * 4]  =  "1";
        cmds[division * 2]  =  "2";
        cmds[division * 1]  =  "4";
        cmds[division / 2]  =  "8";
        cmds[division / 4]  = "16";
        cmds[division / 8]  = "32";
        cmds[division / 16] = "64";

        var dot;
        var result = cmds[duration];
        if (!result) {
            result = cmds[duration * 2 / 3];
            dot = "dot";
        }
        if (!result) {
            result = cmds[duration * 4 / 7];
            dot = "dotdot";
        }
        if (!result) {
            result = cmds[duration * 8 / 15];
            dot = "dot3";
        }
        if (!result) {
            result = cmds[duration * 16 / 31];
            dot = "dot4";
        }
        if (!result) {
            console.log("can't find cmd for duration", duration);
            return;
        }

        var command = "pad-note-" + result;
        cmd(command);
        if (dot) {
            cmd("pad-" + dot);
        }
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
        var measure = curScore.lastMeasure.prevMeasure;
        for (var j = 0; j < target.notes.length; j += 1) {

            // dumpElement("copying target", target.notes[j]);
            Utils.selectNote(target.notes[j]);
            cmd("copy");
            // console.log("------------- 3");

            curScore.selection.select(findItemAtOffset(measure, target.track, filledDuration));
            cmd("paste");
            // console.log("------------- 4");

            var sourceNote = sourceRhythm[j];
            var newNotes = [];
            var prev;
            for (var k = 0; k < sourceNote.durations.length; k += 1) {
                if (k == 0) {
                    var tempItem = findItemAtOffset(measure, target.track, filledDuration);
                    // console.log("------------- 5");
                    curScore.selection.select(tempItem);
                    setItemDuration(sourceNote.durations[k]);
                    filledDuration += sourceNote.durations[k];
                    prev = tempItem;
                    // Utils.dumpElement("prev 1", prev);
                    // console.log("------------- 6");
                } else {
                    if(prev.name === "Rest") {
                        // console.log("------------- 7");

                        var tempRest = findItemAtOffset(measure, target.track, filledDuration);
                        curScore.selection.select(tempRest);
                        setItemDuration(sourceNote.durations[k]);
                        // Utils.dumpElement("prev 2", prev);
                        prev = tempRest;
                    } else {
                        // console.log("------------- 8");
                        curScore.selection.select(prev);
                        cmd("note-input");
                        setItemDuration(sourceNote.durations[k]);
                        cmd("tie");
                        cmd("escape");
                        prev = findItemAtOffset(measure, target.track, filledDuration);
                        // Utils.dumpElement("prev 3", prev);
                    }
                    filledDuration += sourceNote.durations[k];
                }
                newNotes.push(prev);
            }
        }

        // console.log("------------- 9");

        curScore.selection.selectRange(measure.firstSegment.tick, measure.firstSegment.tick + filledDuration,
            target.track / 4, (target.track / 4) + 1);
        cmd("copy");
        // console.log("------------- 10");

        curScore.selection.select(target.notes[0]);
        cmd("paste");
        // console.log("------------- 11");

        curScore.selection.selectRange(measure.firstSegment.tick, curScore.lastSegment.tick + 1,
            target.track / 4, (target.track / 4) + 1);
        cmd("time-delete");
        // console.log("------------- 12");

        console.log("final select",
            Utils.getTick(target.notes[0]), Utils.getTick(target.notes[0]) + filledDuration,
            target.track / 4, (target.track / 4) + 1);
        cmd("escape");
        curScore.selection.selectRange(
            Utils.getTick(target.notes[0]), Utils.getTick(target.notes[0]) + filledDuration,
            target.track / 4, (target.track / 4) + 1);
        // console.log("------------- 13");
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
    }
}
