
// Returns a list of all the notes in the current score's selection,
// in the form [{duration: <num>, tick: <num>, rest: <bool>, durations: []}, ...]
// "tick" is relative to the start of the selection.
// Each set of tied notes is considered one note, whose "duration" is the sum of all the tied notes.
// "durations" is a list of each individual tied note's duration.
function getSelectedRhythm() {
    var result = [];

    // locate the selection
    var cursor = curScore.newCursor();
    cursor.rewind(Cursor.SELECTION_START);

    if (cursor.segment) {
        // The selection exists. Remember where it begins.
        var startTick = cursor.tick;

        // We will use this variable to consolidate tied notes into a single note
        var firstNote;

        // We will only look at the first staff of the selection.
        var staffId = cursor.staffIdx;

        // Find the end of the selection
        cursor.rewind(Cursor.SELECTION_END);
        var endTick = (cursor.tick !== 0)
            ? cursor.tick                    // Normal case
            : curScore.lastSegment.tick + 1; // The selection includes the end of the last measure.

        // Now go back to the beginning of the selection, and iterate over all the notes.
        // The rewind() function sets the voice to 0, that's the only voice we will look at.
        cursor.rewind(Cursor.SELECTION_START); 
        cursor.staffIdx = staffId;
        while (cursor.segment && cursor.tick < endTick) {
            if (cursor.element) {
                var duration = cursor.element.duration;
                var durationInTicks = (division * 4) * duration.numerator / duration.denominator;
                var resultNote = {duration: durationInTicks, tick: cursor.tick - startTick,
                    durations: [durationInTicks, ]};

                if (cursor.element.type === Element.CHORD) {
                    // TODO: if the note is part of a triplet, adjust the numbers as required.

                    // See if the current note is tied to the previous note, or the next note.
                    if (cursor.element.notes && cursor.element.notes.length > 0) {
                        var note = cursor.element.notes[0];

                        if (note.tieForward && !note.tieBack) {
                            // This is the first note of a tied sequence
                            firstNote = resultNote;
                        }
                        if (note.tieBack && firstNote) {
                            // This is a note of a tied sequence
                            firstNote.duration += resultNote.duration;
                            firstNote.durations.push(resultNote.duration);
                            resultNote = null;
                        }
                        if (!note.tieForward) {
                            // This note is not tied to the next note.
                            firstNote = null;
                        }
                    }
                    if (resultNote) result.push (resultNote);
                } else if (cursor.element.type == Element.REST) {
                    resultNote.rest = true;
                    result.push (resultNote);
                }
            }
            cursor.next();
        }
    }

    return result.length > 0 ? result : null;
}

// Return true iff elements of the specified type have a meaningful "text" property.
function elementTypeHasText(elementType) {
    switch (elementType) {
        case Element.LYRICS:
        case Element.TEXT:
        case Element.HARMONY:
        case Element.DYNAMIC:
        case Element.STAFF_TEXT:
        case Element.REHEARSAL_MARK:
        case Element.TEMPO:
            return true;
    }
    return false;
}

var tuplets = [];

function getTupletId(tuplet) {
    for (var i = 0; i < tuplets.length; i += 1) {
        if (tuplets[i].is(tuplet)) {
            return i;
        }
    }
    tuplets.push(tuplet);
    return tuplets.length - 1;
}

// Returns a JSON-compatible data structure corresponding to an element.
function getElementInfo(element) {
    if (!element) {
        return null;
    }

    var result = {name: element.name};

    if (element.type === Element.REST || element.type === Element.CHORD) {
        result.duration = [element.duration.numerator, element.duration.denominator];

        if (element.tuplet) {
            result.actualDuration = [element.duration.numerator * element.tuplet.normalNotes,
                element.duration.denominator * element.tuplet.actualNotes];
            result.tuplet = {id: getTupletId(element.tuplet), numberType: element.tuplet.numberType, bracketType: element.tuplet.bracketType,
                actualNotes: element.tuplet.actualNotes, normalNotes: element.tuplet.normalNotes,
                p1: element.tuplet.p1, p2: element.tuplet.p2, elementCount: element.tuplet.elements.length};
        }
    }

    if (element.type === Element.CHORD) {
        if (element.notes) {
            result.notes = [];
            for (var i = 0; i < element.notes.length; i += 1) {
                result.notes.push(getElementInfo(element.notes[i]));
            }
        }
        if (element.lyrics && element.lyrics.length > 0) {
            result.lyrics = [];
            for (var j = 0; j < element.lyrics.length; j += 1) {
                result.lyrics.push(getElementInfo(element.lyrics[j]));
            }
        }
        if (element.graceNotes && element.graceNotes.length > 0) {
            result.graceNotes = [];
            for (var k = 0; j < element.graceNotes.length; k += 1) {
                result.graceNotes.push(getElementInfo(element.graceNotes[k]));
            }
        }

    } else if (element.type === Element.NOTE) {
        result.parent = element.parent && element.parent.name;
        result.pitch = element.pitch;
        if (element.tieForward) result.tieForward = true;
        if (element.tieBack) result.tieBack = true;

    } else if (elementTypeHasText(element.type)) {
        result.text = element.text;

    } else if (element.type === Element.KEYSIG) {
        // TODO is there a way to find out more info?

    } else if (element.type === Element.TIMESIG) {
        // TODO is there a way to find out more info?

    } else if (element.type === Element.CLEF) {
        // TODO is there a way to find out more info?
    }

    return result;
}

function durationToTicks(duration) {
    return (division * 4) * duration.numerator / duration.denominator;
}

function getTick(element) {
    if (element.type === Element.NOTE) {
        return element.parent.parent.tick;
    }
    if (element.type === Element.REST) {
        return element.parent.tick;
    }
    console.log("getTick unknown element", element.name)
    return 0;
}

function getDuration(element) {
    if (element.type === Element.NOTE) {
        return durationToTicks(element.parent.duration);
    }
    if (element.type === Element.REST) {
        return durationToTicks(element.duration);
    }
    return 0;
}

function selectNote(note) {
    curScore.selection.selectRange(getTick(note), getTick(note) + getDuration(note), 
        note.track / 4, (note.track / 4) + 1);
}    

function dumpCurrentSelection() {
    var numNotes = 0;
    for (var i in curScore.selection.elements) {
        var e = curScore.selection.elements[i];
        if (e.type === Element.NOTE || e.type === Element.REST) {
            numNotes += 1;
        }
    }
    // console.log("isRange", curScore.selection.isRange, ", numNotes", numNotes);
}

function dumpObject(label, object) {
    console.log(label, JSON.stringify(object, undefined, 4));
}

function dumpSegment(label, segment) {
    console.log(label, segment.name, segment.segmentType.toString(), segment.tick);
}

function dumpElement(label, element) {
    dumpObject(label, Utils.getElementInfo(element));
}

function dumpSelection(label) {
    var selection = curScore.selection.elements;
    if (selection) {
        var selectionInfo = [];
        for (var i in selection) {
            var element = selection[i];
            selectionInfo.push(Utils.getElementInfo(element));
        }
        console.log(label, JSON.stringify(selectionInfo, undefined, 4));
    } else {
        console.log(label, "selection is null");
    }        
}

function selectNotes(notes) {
    var minTick = Number.MAX_VALUE;
    var maxTick = Number.MIN_VALUE;
    var minTrack = Number.MAX_VALUE;
    var maxTrack = Number.MIN_VALUE;
    for (var i in notes) {
        var note = notes[i];
        minTick = Math.min(minTick, getTick(note));
        maxTick = Math.max(maxTick, getTick(note) + getDuration(note));
        minTrack = Math.min(minTrack, note.track);
        maxTrack = Math.max(maxTrack, note.track);
    }
    // console.log("selectRange", minTick, maxTick, minTrack / 4, (maxTrack / 4) + 1);
    curScore.selection.selectRange(minTick, maxTick, minTrack / 4, (maxTrack / 4) + 1);
}

function ensureSelectionIsRange() {
    var sel = curScore.selection;
    if (!sel.isRange) {
        selectNotes(getSelectedNotes().notes);
    }
}

// returns {notes: [<element>, ...], track: <n>, staff: <n>, measure: <measure>, beginTick: <n>, endTick: <n>}
function getSelectedNotes() {
    var result = {notes: [], track: -1, beginTick: Number.MAX_VALUE, endTick: Number.MIN_VALUE};
    var selectedElements = curScore.selection.elements;
    if (selectedElements) {
        for (var i in selectedElements) {
            var element = selectedElements[i];
            if (element.type === Element.NOTE || element.type === Element.REST) {
                if (element.parent.parent.type === Element.CHORD) {
                    // it's a grace note, ignore it
                } else {
                    result.notes.push(element);
                    if (getTick(element) < result.beginTick) {
                        result.beginTick = getTick(element);
                    }
                    var endTick = getTick(element) + getDuration(element);
                    if (endTick > result.endTick) {
                        result.endTick = endTick;
                    }

                    result.track = element.track;
                    result.measure = getMeasure(element);
                }
            }
        }
    }
    result.staff = result.track / 4;

    // console.log("getSelectedNotes", result.notes.length, result.track, result.measure, result.beginTick, result.endTick);
    return result;
}

function getMeasure(element) {
    while (element) {
        if (element.name === "Measure") {
            return element;
        }
        element = element.parent;
    }
    return null;
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

// function firstNoteOfMeasure(measure, track) {
//     var segment = measure.firstSegment();
//     while(segment) {
//         if (segment.type === "ChordRest") {
//             var element = segment.elementAt(track);
//             if (element) {
//                 if (element.type === Element.REST) {
//                     return element;
//                 }
//                 if (element.type === "Chord") {
//                     if (element.notes && element.notes.length > 0) {
//                         return element.notes[0];
//                     }
//                 }
//             }
//         }
//         segment = segment.nextInMeasure;
//     }
// }

function findNoteAtTick(tick, track) {
    // console.log("findNoteAtTick", tick, track);
    var segment = curScore.firstSegment();
    while(segment) {
        // console.log("segment", segment.tick, segment.type);
        if (segment.tick === tick && segment.segmentType.toString() === "ChordRest") {
            // console.log("------- A");
            var element = segment.elementAt(track);
            if (element) {
                // console.log("element", element.name);
                // console.log("------- B");
                if (element.type === Element.REST) {
                    // console.log("------- C");
                    return element;
                }
                if (element.type === Element.CHORD) {
                    // console.log("------- D");
                    if (element.notes && element.notes.length > 0) {
                        // console.log("------- E");
                        return element.notes[0];
                    }
                }
            }
        }
        segment = segment.next;
    }
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
