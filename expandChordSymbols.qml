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

import MuseScore 3.0

MuseScore {
    version: "0.5"
    description: "Expands chord symbols into a new track"
    menuPath: "Plugins.ExpandChordSymbols"

    /* Chord Symbol features not yet implemented --
        doublesharp/doubleflat
        natural
        commas
        parenthesis
        N.C.
        Cmi(ma7), Cmi(ma9)
        augmented major chord e.g. C+M7, CM7+5, CM7♯5, or Cmaj7aug5 = C – E – G♯ – B
        lowercase root note meaning minor, e.g. c instead of Cm
    */

    function dumpChordInfo(c) {
        var result = "";
        result += c.letter;
        if (c.sharp) result += "#";
        if (c.flat) result += "b";
        if (c.major) result += "ma";
        if (c.minor) result += "mi";
        if (c.diminished) result += "dim";
        if (c.halfdim) result += "ø";
        if (c.augmented) result += "aug";
        if (c.sixnine) result += "6/9";
        if (c.number) result += c.number;
        if (c.alt) result += "alt";
        if (c.sus) result += "sus" + c.sus;
        if (c.add) result += "add" + c.add;
        if (c.nothree) result += "no3";
        if (c.adjustments) {
            for (var i = 0; i < c.adjustments.length; i += 1) {
                var adjustment = c.adjustments[i];
                if (adjustment.number) {
                    if (adjustment.sharp) result += "#";
                    if (adjustment.flat) result += "b";
                    result += adjustment.number;
                }
            }
        }
        if (c.bass && !c.bass.default) {
            result += "/";
            result += c.bass.letter;
            if (c.bass.sharp) result += "#";
            if (c.bass.flat) result += "b";
        }

        // console.log("chord is", result);
    }

    function calcChordInfo(symbol) {
        symbol = symbol.replace(/[()]/g, "");
        var result = symbol.match(
        /^([A-Ga-g])?([#♯])?([b♭])?(Major|major|Maj|maj|Ma|ma|M|j)?(minor|min|mi|m|-|−)?(dim|o|°)?(ø|O|0)?(aug|\+)?([tΔ∆\^])?(69|6-9|6\+9|6\/9)?([0-9]+)?(alt)?(sus([0-9])?)?(add([0-9]+))?(drop3|no3)?(([#♯])?([b♭])?([0-9]+))?(([#♯])?([b♭])?([0-9]+))?(([#♯])?([b♭])?([0-9]+))?(\/([A-G])([#♯])?([b♭])?)?/
        );

        var i = 1;
        var result = {
            letter:     result[i++],
            sharp:      result[i++],
            flat:       result[i++],
            major:      result[i++],
            minor:      result[i++],
            diminished: result[i++],
            halfdim:    result[i++],
            augmented:  result[i++],
            triangle:   result[i++],
            sixnine:    result[i++],
            number:     result[i++],
            alt:        result[i++],
            sus:        result[i++],
            susnumber:  result[i++],
            add:        result[i++],
            addnumber:  result[i++],
            nothree:    result[i++],
            adjustments: [
                {
                    text:   result[i++],
                    sharp:  result[i++],
                    flat:   result[i++],
                    number: result[i++]
                },
                {
                    text:   result[i++],
                    sharp:  result[i++],
                    flat:   result[i++],
                    number: result[i++]
                },
                {
                    text:   result[i++],
                    sharp:  result[i++],
                    flat:   result[i++],
                    number: result[i++]
                }
            ],
            bass: {
                text:   result[i++],
                letter: result[i++],
                sharp:  result[i++],
                flat:   result[i++]
            }
        };

        // If letter was omitted (e.g. "/B"), use the previous chord letter/sharp/flat
        if (!result.letter) {
            result.letter = calcChordInfo.prevLetter || "c";
            result.sharp = calcChordInfo.prevSharp;
            result.flat = calcChordInfo.prevFlat;
        }

        // Fix up the result a bit
        result.letter = result.letter.toUpperCase();
        if (result.bass.letter) {
            result.bass.letter = result.bass.letter.toUpperCase();
        } else {
            result.bass.letter = result.letter;
            result.bass.flat = result.flat;
            result.bass.sharp = result.sharp;
            result.bass.default = true;
        }
        if (result.sus) result.sus = result.susnumber || "4";
        delete result.susnumber;
        if (result.add) result.add = result.addnumber;
        delete result.addnumber;
        if (result.triangle) {
            result.major = true;
            if (!result.number) result.number = "7";
            delete result.triangle;
        }
        for (i = result.adjustments.length - 1; i >= 0; i -= 1) {
            if (!result.adjustments[i].text) {
                result.adjustments.splice(i, 1);
            } else {
                delete result.adjustments[i].text;
            }
        }
        if (result.adjustments.length == 0) {
            delete result.adjustments;
        }

        // Save letter/sharp/flat in case we need it for the next chord
        calcChordInfo.prevLetter = result.letter;
        calcChordInfo.prevSharp = result.sharp;
        calcChordInfo.prevFlat = result.flat;

        return result;
    }

    // result is an object in the form {degree: <adjustment value>, ...}
    function calcAbstractNotes(chordInfo) {
        var result;
        var seventh;
        if (chordInfo.minor) {
            result = {1: 0, 3: -1, 5: 0};
            seventh = -1;

        } else if (chordInfo.diminished) {
            result = {1: 0, 3: -1, 5: -1};
            seventh = -2;
            result[7] = seventh;

        } else if (chordInfo.halfdim) {
            result = {1: 0, 3: -1, 5: -1};
            seventh = -1;
            result[7] = seventh;

        } else if (chordInfo.augmented) {
            result = {1: 0, 3: 0, 5: 1};
            seventh = -1;

        } else { // default is major
            result = {1: 0, 3: 0, 5: 0};
            seventh = chordInfo.major ? 0 : -1;
        }

        if (chordInfo.sixnine) {
            result[6] = 0;
            result[9] = 0;
        }

        if (chordInfo.nothree) {
            delete result[3];
        }

        if (chordInfo.number) {
            switch(chordInfo.number) {
                case "13": result[13] = 0;
                case "11": result[11] = 0;
                case  "9": result[9] = 0;
                case  "7": result[7] = seventh;
                           break;
                case "6":  result[6] = 0;
                           break;
                case "5":  delete result[3];
                           break;
            }
        }

        if (chordInfo.sus) {
            result[chordInfo.sus] = 0;
            delete result[3];
        }
        if (chordInfo.add) {
            result[chordInfo.add] = 0;
        }
        if (chordInfo.alt) {
            // "alt" is intended to be interpreted by the performer. 7#5#9 is a common choice.
            result[7] = -1;            
            result[5] = +1;
            result[9] = +1;
        }
        if (chordInfo.adjustments) {
            for(var i = 0; i < chordInfo.adjustments.length; i += 1) {
                var a = chordInfo.adjustments[i];
                result[a.number] = a.sharp ? 1 : -1;
                result[7] = seventh;
            }
        }

        return result;
    }

    // returns semitones above C
    function letterFlatSharpToSemi(info) {
        var notes = {C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11};

        var result = notes[info.letter];
        if (info.flat) result--;
        if (info.sharp) result++;
        return result;
    }

    // "note" and "tonic" are semis above C
    // function noteToSemisAboveTonic(tonic, note) {
    //     while (note < tonic) {
    //         note += 12;
    //     }
    //     return note - tonic;
    // }

    function calcRoot(info) {
        return letterFlatSharpToSemi(info) + 48;
    }

    function numItems(obj) {
        var result = 0;
        for (var i in obj) result += 1;
        return result;
    }

    function prune(maxLength, abstractNotes, chordInfo) {
        var initialLength = numItems(abstractNotes);
        var limit = 10;
        loop: while (numItems(abstractNotes) > maxLength) {
            if (--limit <= 0) {
                console.log("**** bailout");
                return;
            }
            if (abstractNotes[1] != undefined) {
                // delete the tonic note
                // todo: instead, delete the bass note, which may or may not be the tonic
                delete abstractNotes[1];
                continue loop;
            }

            // delete the perfect 5
            if (abstractNotes[5] == 0) {
                delete abstractNotes[5];
                continue loop;
            }

            // delete 2nd highest note, so e.g. we'll keep 13 but delete 11 and 9
            // todo: don't delete notes that are explictly mentioned in the chord definition
            // (e.g. in Cma13#11sus2, don't delete the major 7, the 13, the #11 or the 2)
            var indices = [];
            for (var i in abstractNotes) indices.push(i);
            delete abstractNotes[indices[indices.length - 2]];
        }
    }

    // returns an array of midi note numbers (e.g. middle C is 60)
    function render(abstractNotes, chordInfo) {
        var notes = [];
        var root = calcRoot(chordInfo);
        var notesemitones = {1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11, 8: 12, 9: 14, 10: 16, 11: 17, 12: 19, 13: 21};
        for (var i in abstractNotes) {
            notes.push(notesemitones[i] + abstractNotes[i] + root);
        }

        return notes;
    }

    function compare(a, b) {
        return a - b;
    }

    function numNotesAboveMiddleC(notes) {
        var result = 0;
        for(var i in notes) {
            if (notes[i] > 60) result += 1; // use c#, not c
        }
        return result;
    }

    function position(notes) {
        switch(numNotesAboveMiddleC(notes)) {
            case 0:
                while(numNotesAboveMiddleC(notes) < 1) {
                    notes[0] += 12;
                    notes.sort(compare);
                }
            case 1:
                return;
            default:
                while(numNotesAboveMiddleC(notes) > 1) {
                    notes[notes.length -1] -= 12;
                    notes.sort(compare);
                }
                return;
        }
    }

    function addBass(chordInfo, notes) {
        var bassNote = calcRoot(chordInfo.bass);
        if (bassNote >= 52) bassNote -= 12;
        if (bassNote != notes[0]) notes.unshift(bassNote);
    }

    function expandChordSymbols() {
        if (!curScore) {
          return;
        }

        var chords = {};
        var cursor = curScore.newCursor();
        for (var trackNumber = 0; trackNumber < curScore.ntracks; trackNumber += 1) {
            cursor.track = trackNumber;        
            cursor.rewind(Cursor.SCORE_START);

            while (cursor.segment) {
                var annotations = cursor.segment.annotations; 
                for (var a in annotations) {
                    var annotation = annotations[a];
                    if (annotation.name == "Harmony") {
                        chords[cursor.tick] = {tick: cursor.tick, text: annotation.text};
                        // console.log("chord: tick", cursor.tick, "text", annotation.text);
                    }
                }
                cursor.next();
            }
        }

        // console.log("chords", JSON.stringify(chords, undefined, 2));

        if (chords.length == 0) {
            return;
        }

        var lastChord;
        for (var i in chords) {
            var chord = chords[i];
            if (lastChord) {
                lastChord.duration = chord.tick - lastChord.tick;
            }
            lastChord = chord;
        }
        lastChord.duration = 960;

        cursor.track = curScore.ntracks - 4;
        cursor.rewind(Cursor.SCORE_START);

        for (var i in chords) {
            var chord = chords[i];
            // console.log("Chord tx", chord.text);

            var chordInfo = calcChordInfo(chord.text);
            dumpChordInfo(chordInfo);
            // console.log("Chord tick", chord.tick, "duration", chord.duration, JSON.stringify(chordInfo));

            var abstractNotes = calcAbstractNotes(chordInfo);
            // console.log("Abstract notes: ", JSON.stringify(abstractNotes));
            prune(4, abstractNotes, chordInfo);
            // console.log("Abstract notes after prune: ", JSON.stringify(abstractNotes));
            var notes = render(abstractNotes, chordInfo);
            // console.log("real notes", JSON.stringify(notes));
            position(notes);
            // console.log("position notes", JSON.stringify(notes));
            addBass(chordInfo, notes);
            // console.log("notes with bass", JSON.stringify(notes));

            var duration = chord.duration;
            var bumpCount = 0;
            while (duration > 0) {
                var endOfThisMeasure = cursor.measure.nextMeasure
                    ? cursor.measure.nextMeasure.firstSegment.tick
                    : cursor.tick + duration;

                var thisDuration = Math.min(duration, endOfThisMeasure - cursor.tick);
                duration -= thisDuration;
                cursor.setDuration(thisDuration / 60, 32);
                var beforeTick = cursor.tick;
                if (notes[0] > 0) {
                    cursor.addNote(notes[0]);
                    for (var j = 1; j < notes.length; j += 1) {
                        cursor.addNote(notes[j], true);
                    }
                } else {
                    cursor.addNote(24);
                }
                var actualDuration = cursor.tick - beforeTick;
                if ((actualDuration != thisDuration) && cursor.measure.nextMeasure) {
                    duration += thisDuration - actualDuration;
                    console.log("** at time", cursor.tick, "didn't get requested duration. Wanted", thisDuration,
                        "got", actualDuration, "Bumping duration", thisDuration - actualDuration, "to", duration);
                    if (++bumpCount > 3) {
                        console.log("bailout!!");
                        duration = 0;
                    }
                }
            }
        }
    }

    onRun: {
        expandChordSymbols();
        Qt.quit();        
    }
}

