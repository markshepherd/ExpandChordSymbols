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
import QtQuick 2.1
import QtQuick.Dialogs 1.0
import QtQuick.Controls 1.0

MuseScore {
    version: "0.9"
    description: "Expands chord symbols into a staff"
    menuPath: "Plugins.ExpandChordSymbols"
    pluginType: "dialog"
    id: window
    width:  400;
    height: 300;

    // This plugin for MuseScore 3 generates notes for chord symbols. For each chord symbol in the 
    // score, the plugin creates a corresponding set of notes in a designated target staff. Each
    // chord plays until the next chord. There are 2 modes:
    // - raw mode: all the notes of the chord are generated
    // - normal mode: the chord has only the 4 most important notes plus a bass note,
    //   and is inverted so that most of the notes are near or below middle C.
    //   The results are very similar to Marc Sabatella's proposed voicings at
    //   https://musescore.com/marcsabatella/chord-symbol-voicings-for-playback

    // In the following code, we use various data structures to represent notes and chords.
    //   string - a simple string
    //      e.g. "Cmin7"
    //   score chord symbol array - an array with one element for each chord symbol that appears in the score.
    //      e.g. [{tick: 1440, text: "Cmin7", duration: 480}, ...]
    //   chord specification - a detailed specification of a single chord
    //      e.g. {letter: "C", number: "7", minor: true}
    //   chordMap - an object that represents all the notes in a chord
    //      e.g. {"1": 0, "3": -1, "5": 0, "7": -1} for Cmin7 = tonic, flat 3rd, perfect 5th, flat 7th.
    //   interval - the number of semitones between two notes.
    //      e.g. the interval between C and D is 2, the interval between tonic and perfect fifth is 7
    //   midi note - a number that describes a certain pitch. Arrays of midiNotes should always be sorted ascending.
    //      e.g. [48, 51, 55, 58] = C3, Eb3, G3, Bb3 = Cmin7

    // To generate the chords, we start with the text chord symbols that appear in the score,
    // and perform a series of transformations.
    // 0. findAllChordSymbols() searches all tracks of the score to produce a score chord symbol array. 
    // 1. parseChordSymbol() parse the text chord symbol, and produces a chord specification.
    // 2. expandChordSpec() uses the chord specification to create an chordMap object.
    // 3. in normal mode, prune() reduces the number of notes in the chordMap to maximum of 4.
    // 4. render() converts the chordMap to an array of real midi notes
    // 5. in normal mode, findOptimumInversion() modifies the list of midi notes to get the optimum voicing
    //      e.g. [55, 58, 60, 63] = Cmin7 (notes 48 and 51 got bumped up an octave)
    // 6. [addBass] add the bass note to the chord.
    //      e.g. [48, 55, 58, 60, 63]

    // Returns the interval above C that corresponds to the letter/sharp/flat fields in "spec"
    function letterToInterval(spec) {
        var letterToSemi = {C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11};
        var result = letterToSemi[spec.letter.toUpperCase()];
        if (spec.flat) result--;
        if (spec.sharp) result++;
        if (result > 11) result -= 12;
        if (result < 0) result += 12;
        return result;
    }

    // Returns a midiNote in the octave below middle C that corresponds to the letter/sharp/flat fields in "spec".
    function letterToMidiNote(spec) {
        return letterToInterval(spec) + 48;
    }

    // Returns the number of properties in an object. E.g. for {a: 1, b: true} we return 2.
    function countProperties(obj) {
        var result = 0;
        for (var i in obj) result += 1;
        return result;
    }

    // Given an array of midi notes, return the number of notes that are above middle C
    function numNotesAboveMiddleC(midiNotes) {
        var result = 0;
        for(var i in midiNotes) {
            if (midiNotes[i] > 60) result += 1; // use c#, not c
        }
        return result;
    }

    // Given a string representing a chord (e.g. "C#ma7b9"), returns a chord specification.
    function parseChordSymbol(symbol) {
        // Use a regex to split the chord symbol into an array of tokens.
        var tokens = symbol.match(
        /^([A-Ga-g])?([#♯])?([b♭])?(Major|major|Maj|maj|Ma|ma|M|j)?(minor|min|mi|m|-|−)?(dim|o|°)?(ø|O|0)?(aug|\+)?([tΔ∆\^])?(69|6-9|6\+9|6\/9)?([0-9]+)?(\((Major|major|Maj|maj|Ma|ma|M|j)([0-9]+)\))?(alt)?(sus([0-9])?)?(add([0-9]+))?(drop3|no3)?(([#♯])?([b♭])?([0-9]+))?(([#♯])?([b♭])?([0-9]+))?(([#♯])?([b♭])?([0-9]+))?(\/([A-G])([#♯])?([b♭])?)?/
        );

        // Assign each token to the appropriate field of a chord specification object.
        // If a token is empty, the field is simply undefined.
        var i = 1;
        var result = {
            letter:      tokens[i++],
            sharp:       tokens[i++],
            flat:        tokens[i++],
            major:       tokens[i++],
            minor:       tokens[i++],
            diminished:  tokens[i++],
            halfdim:     tokens[i++],
            augmented:   tokens[i++],
            triangle:    tokens[i++],
            sixnine:     tokens[i++],
            number:      tokens[i++],
            majoralttext:tokens[i++],
            majoralt:    tokens[i++],
            majoraltnum: tokens[i++],
            alt:         tokens[i++],
            sus:         tokens[i++],
            susnumber:   tokens[i++],
            add:         tokens[i++],
            addnumber:   tokens[i++],
            nothree:     tokens[i++],
            adjustments: [
                {
                    text:   tokens[i++],
                    sharp:  tokens[i++],
                    flat:   tokens[i++],
                    number: tokens[i++]
                },
                {
                    text:   tokens[i++],
                    sharp:  tokens[i++],
                    flat:   tokens[i++],
                    number: tokens[i++]
                },
                {
                    text:   tokens[i++],
                    sharp:  tokens[i++],
                    flat:   tokens[i++],
                    number: tokens[i++]
                }
            ],
            bass: {
                text:   tokens[i++],
                letter: tokens[i++],
                sharp:  tokens[i++],
                flat:   tokens[i++]
            }
        };

        // Uncomment the following line to see what the chord specification looks like.
        // console.log(symbol, JSON.stringify(result));
        return result;
    }

    // Given a chord specification, return an chordMap object containing all the notes of the chord.
    function expandChordSpec(chordSpec) {
        var result;
        var seventh;
        if (chordSpec.minor) {
            result = {1: 0, 3: -1, 5: 0};
            seventh = -1;

        } else if (chordSpec.diminished) {
            result = {1: 0, 3: -1, 5: -1};
            seventh = -2;
            result[7] = seventh;

        } else if (chordSpec.halfdim) {
            result = {1: 0, 3: -1, 5: -1};
            seventh = -1;
            result[7] = seventh;

        } else if (chordSpec.augmented) {
            result = {1: 0, 3: 0, 5: 1};
            seventh = -1;

        } else { // default is major
            result = {1: 0, 3: 0, 5: 0};
            seventh = chordSpec.major ? 0 : -1;
        }
        
        if (chordSpec.triangle) {
            seventh = 0;
            result[7] = seventh;
        }

        if (chordSpec.sixnine) {
            result[6] = 0;
            result[9] = 0;
        }

        if (chordSpec.nothree) {
            delete result[3];
        }

        if (chordSpec.majoraltnum) {
            seventh = 0;
            chordSpec.number = chordSpec.majoraltnum;
        }

        if (chordSpec.number) {
            switch(chordSpec.number) {
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

        if (chordSpec.sus) {
            result[chordSpec.susnumber || "4"] = 0;
            delete result[3];
        }

        if (chordSpec.add) {
            result[chordSpec.addnumber] = 0;
        }

        if (chordSpec.alt) {
            // "alt" is intended to be interpreted by the performer. Here we use 7#5#9 because that is a common choice.
            result[7] = -1;            
            result[5] = +1;
            result[9] = +1;
        }

        for(var i = 0; i < chordSpec.adjustments.length; i += 1) {
            var a = chordSpec.adjustments[i];
            if (a.text) {
                result[a.number] = a.sharp ? 1 : -1;
                result[7] = seventh;
            }
        }
        
        return result;
    }

    // Deletes items from an chordMap object, to make it contain no more than maxLength notes.
    // Eliminates notes that are less important harmonically, in this order: tonic, perfect 5,
    // then secondary color notes (e.g. the 11th and 9th in a 13th chord).
    function prune(maxLength, chordMap) {
        var initialLength = countProperties(chordMap);

        // Keep deleting items until we have the right number of items.
        loop: while (countProperties(chordMap) > maxLength) {
            // delete the tonic note if it exists
            if (chordMap[1] != undefined) {
                delete chordMap[1];
                continue loop;
            }

            // delete the perfect 5 if it exists
            if (chordMap[5] == 0) {
                delete chordMap[5];
                continue loop;
            }

            // delete 2nd highest note, so e.g. we'll keep 13 but delete 11 and 9
            var indices = [];
            for (var i in chordMap) indices.push(i);
            delete chordMap[indices[indices.length - 2]];
        }
    }

    // Given a chordMap object, returns the corresponding array of midi notes,
    // based on the root note from "chordSpec".
    function render(chordMap, chordSpec) {
        var midiNotes = [];

        // If this chord has no letter (e.g. "/B"), use the previous chord
        if (!chordSpec.letter) {
            var prevSpec = render.lastChordSpec || {letter: "C"};
            chordSpec.letter = prevSpec.letter;
            chordSpec.sharp = prevSpec.prevSharp;
            chordSpec.flat = prevSpec.prevFlat;
        }

        // Save the current chord in a static variable, in case we need it next time.
        render.lastChordSpec = chordSpec;

        // Find the tonic midi for this chord.
        var tonicMidiNote = letterToMidiNote(chordSpec);

        // For each note in chordMap, determine the corresponding midi note.
        var notesemitones = {1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11, 8: 12, 9: 14, 10: 16, 11: 17, 12: 19, 13: 21};
        for (var i in chordMap) {
            // the midi note = tonic midi note + the number of semitones above the tonic + adjustment (-1,0,+1).
            midiNotes.push(tonicMidiNote + notesemitones[i] + chordMap[i]);
        }

        return midiNotes;
    }

    // Given an array of midiNotes, adjust the notes up or down by octaves, in order to find
    // the inversion in which exactly one note is higher than middle C.
    function findOptimumInversion(midiNotes) {
        function compare(a, b) {return a - b;}

        switch(numNotesAboveMiddleC(midiNotes)) {
            case 0:
                while(numNotesAboveMiddleC(midiNotes) < 1) {
                    midiNotes[0] += 12;
                    midiNotes.sort(compare);
                }
            case 1:
                return;
            default:
                while(numNotesAboveMiddleC(midiNotes) > 1) {
                    midiNotes[midiNotes.length -1] -= 12;
                    midiNotes.sort(compare);
                }
                return;
        }
    }

    // To an array of midi notes, add the bass note defined by the chord specification.
    function addBass(chordSpec, midiNotes) {
        var bassNote = letterToMidiNote(chordSpec.bass.letter ? chordSpec.bass : chordSpec);
        if (bassNote >= 52) bassNote -= 12; // Maybe adjust the octave. We can go as low as E below the bass clef.
        if (bassNote != midiNotes[0]) midiNotes.unshift(bassNote);
    }

    // Search the current score for all the chord symbols in all tracks.
    // Returns an array of score chord symbol objects like {tick: 1440, duration: 960, text: "Db7"}.
    function findAllChordSymbols() {
        var cursor = curScore.newCursor();
        var chords = {};
        for (var trackNumber = 0; trackNumber < cursor.score.ntracks; trackNumber += 1) {
            cursor.track = trackNumber;        
            cursor.rewind(Cursor.SCORE_START);

            while (cursor.segment) {
                var annotations = cursor.segment.annotations; 
                for (var a in annotations) {
                    var annotation = annotations[a];
                    if (annotation.name == "Harmony") {
                        // Save the chord for this tick. If multiple tracks have a chord at the same tick,
                        // we will only keep the last one we find.
                        chords[cursor.tick] = {tick: cursor.tick, text: annotation.text};
                    }
                }
                cursor.next();
            }
        }

        // Now calculate the duration of each chord (duration = start time of next chord - start time of this chord).
        // Also, copy all the chords to an Array, we no longer need them to be in an Object.
        var result = [];
        for (var i in chords) {
            var chord = chords[i];
            if (result.length > 0) {
                result[result.length - 1].duration = chord.tick - result[result.length - 1].tick;
            }
            result.push(chord);
        }
        if (result.length > 0) {
            result[result.length - 1].duration = 960; // I don't know how to find the duration of the very last chord :(
        }
        return result;
    }

    // Given a text chord symbol (e.g. "C7b9"), return an array of midi notes (e.g. [60, 64, 67, 70, 73]).
    // If raw = true, you get all the notes of the chord, which can be 9 or 10 notes for complex chords.
    // If raw = false, you get at most 5 notes, in an inversion that puts most of the notes near or below middle C.
    function chordTextToMidiNotes(text, raw) {
        var chordSpec = parseChordSymbol(text);
        var chordMap = expandChordSpec(chordSpec);
        if (!raw) prune(4, chordMap);
        var midiNotes = render(chordMap, chordSpec);
        if (!raw) findOptimumInversion(midiNotes);
        addBass(chordSpec, midiNotes);
        return midiNotes;
    }

    // Write a bunch of chords to a given track of the current score, starting at time 0.
    // Chords is an array of score chord symbol objects like {tick: 1234, text: "Db7", duration: 234}.
    function writeChords(chords, track, raw) {
        if (chords.length == 0) return;

        var cursor = curScore.newCursor();
        cursor.track = track;
        cursor.rewind(Cursor.SCORE_START);

        // Move the cursor to the first chord. NOTE: due to limitations of the Muse API, it may not be
        // possible to position the cursor exactly at the time of the first chord. Instead, we'll look for
        // the nearest available position at or before the chord.
        while (cursor.tick <= chords[0].tick) {
            cursor.next();
        }
        cursor.prev();

        // Process each chord
        for (var i in chords) {
            var chord = chords[i]; // the chord we're working on

            // find the notes we need to write for this chord
            var midiNotes = chordTextToMidiNotes(chord.text, raw);

            // find the chord's duration. Adjust the duration if the cursor is not exactly at the desired time.
            var duration = chord.duration + (chord.tick - cursor.tick); // in midi ticks
            var bumpCount = 0; // see below for explanation

            // If the chord's duration is long, we will write several shorter notes, rather than
            // one long note. We will loop until the entire duration has been used up.
            while (duration > 0) {
                // Find out when the current measure ends. This is awkward code, do you know a better way?
                var endOfThisMeasure = cursor.measure.nextMeasure
                    ? cursor.measure.nextMeasure.firstSegment.tick
                    : cursor.tick + duration;

                // Set the note's duration so that the note ends no later than the end of the measure.
                var thisDuration = Math.min(duration, endOfThisMeasure - cursor.tick);
                duration -= thisDuration;
                cursor.setDuration(thisDuration / 60, 32);

                // Add all the midi notes to the score.
                var beforeTick = cursor.tick; 
                cursor.addNote(midiNotes[0]);
                for (var j = 1; j < midiNotes.length; j += 1) {
                    cursor.addNote(midiNotes[j], true);
                }

                // NOTE: there is a bug in cursor.addNote(), it sometimes adds a note shorter
                // than the requested duration. The following workaround adds the missing time 
                // back into "duration", and then continues looping.
                var actualDuration = cursor.tick - beforeTick;
                if ((actualDuration != thisDuration) && cursor.measure.nextMeasure) {
                    duration += thisDuration - actualDuration;
                    console.log("** at time", cursor.tick, "didn't get requested duration. Wanted", thisDuration,
                        "got", actualDuration, "Bumping duration", thisDuration - actualDuration, "to", duration);
                    if (++bumpCount > 3) {
                        console.log("bailout!!"); // avoid an infinite loop in case this workaround goes awry
                        duration = 0;
                    }
                }
            }
        }
    }

    // Here is where do all the work. It's easy - we find all the chords, then write them to the score.
    function expandChordSymbols(raw) {
        curScore.startCmd();
        writeChords(findAllChordSymbols(), curScore.ntracks - 4, raw);
        curScore.endCmd();
    }

    // Following is the UI of the dialog that appears when you run this plugin. 

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

    Label {
        id: textLabel2
        wrapMode: Text.WordWrap
        text: ""
        font.pointSize:12
        anchors.left: window.left
        anchors.top: textLabel1.bottom
        anchors.leftMargin: 10
        anchors.topMargin: 10
    }

    CheckBox {
        id:   writeCondensed
        text: "Condense chords to 5 notes or less, at or below middle C"
        checked: true
        anchors.left: window.left
        anchors.top: textLabel2.bottom
        anchors.leftMargin: 10
        anchors.topMargin: 10
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
            expandChordSymbols(!writeCondensed.checked);
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

    // This code runs when the plugin is invoked, before the dialog appears. All we do is update the dialog text.
    onRun: {
        // Find out if there are any notes in the target track, which is the first voice of the last staff.
        var cursor = curScore.newCursor();
        cursor.track = curScore.ntracks - 4;
        cursor.rewind(Cursor.SCORE_START);
        var gotNotes = false;
        while (cursor.segment) {
            var e = cursor.element;
            gotNotes = gotNotes || (cursor.element && (cursor.element.type == Element.CHORD));
            cursor.next();
        }

        // Update the messages in the dialog.
        textLabel1.text = "The chords will be placed in Staff #" + (cursor.staffIdx + 1) + " \""
            + curScore.parts[cursor.staffIdx].longName + "\".";
        if (gotNotes) {
            textLabel2.text = "Is it OK to overwrite all notes in that staff?";
        }
    }
}
