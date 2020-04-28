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
import QtQuick.Controls 1.1

MuseScore {
    version: "1.0"
    description: "Expands chord symbols into a staff"
    menuPath: "Plugins.Expand Chord Symbols…"
    pluginType: "dialog"
    id: window
    width:  600;
    height: 300;

    // This plugin for MuseScore 3 generates notes for chord symbols. For each chord symbol in the 
    // score, the plugin creates a corresponding set of notes in a designated target staff. Each
    // chord plays until the next chord. There are 2 modes:
    // - raw mode: all the notes of the chord are generated
    // - condensed mode: we generate only the 4 most important notes plus a bass note,
    //   and is inverted so that most of the notes are near or below middle C.
    //   The results are almost identical to Marc Sabatella's proposed voicings at
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
    // 3. in condensed mode, prune() reduces the number of notes in the chordMap to maximum of 4.
    // 4. render() converts the chordMap to an array of real midi notes
    // 5. in condensed mode, findOptimumInversion() modifies the list of midi notes to get the optimum voicing
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

    // Returns a copy of the source object.
    function shallowCopy(source) {
        var result = {};
        for (var i in source) {
            result[i] = source[i];
        }
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

    // Given an array of midi notes, return the number of notes that are above the threshold
    function numNotesAboveThreshold(midiNotes, threshold) {
        var result = 0;
        for(var i in midiNotes) {
            if (midiNotes[i] > threshold) result += 1; // use c#, not c
        }
        return result;
    }

    // Adds a rest to the score, using the current cursor position and duration.
    function addRest(cursor) {
        // Adding a rest to the score requires a little dance ...

        // ... first we add a placeholder note.
        cursor.addNote(0);

        // ... go back to the note we just added
        cursor.prev();

        // ... create a new rest with the same duration as the placeholder object
        var e = newElement(Element.REST);
        e.durationType = cursor.element.durationType;
        e.duration = cursor.element.duration;

        // ... add the rest to the score
        cursor.add(e);

        // ... advance the cursor, because cursor.add() doesn't. (unlike cursor.addNote(), which does).
        cursor.next();
    }

    // Removes all the notes in the given track.
    function clearStaff(track) {
        var cursor = curScore.newCursor();
        cursor.track = track;
        cursor.rewind(Cursor.SCORE_START);
        while (cursor.segment) {
            if (cursor.element.type === Element.CHORD) {
                removeElement(cursor.element);
            }
            cursor.next();
        }
    }

    // Returns a list of all the notes in the selection,
    // in the form [{duration: <num>, tick: <num>, rest: <bool>, bassOnly: <bool>}, ...]
    // "tick" is relative to the start of the selection.
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
                    var resultNote = {duration: durationInTicks, tick: cursor.tick - startTick};

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
                                resultNote = null;
                            }
                            if (!note.tieForward) {
                                // This note is not tied to the next note.
                                firstNote = null;
                            }

                            // If the note is lower than B above middle C,
                            // then this means we should only generate the bass note.
                            if (lowNoteMeansBass.checked && resultNote && note.pitch < 64) {
                                resultNote.bassOnly = true;
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

    // Deletes items from a chordMap object, to make it contain no more than maxLength notes.
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
            chordSpec.sharp = prevSpec.sharp;
            chordSpec.flat = prevSpec.flat;
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
    function findOptimumInversion(midiNotes, chordSpec) {
        function compare(a, b) {return a - b;}

        // To get the best sounding inversion, we need to use a slightly different threshold,
        // depending on the chord root. The threshold varies from middle C to Eb above middle C.
        var root = letterToInterval(chordSpec);
        var threshold = {0:60, 1:61, 2:62, 3:62, 4:63, 5:60, 6:62, 7:61, 8:60, 9:62, 10:62, 11:62}[root];

        switch(numNotesAboveThreshold(midiNotes, threshold)) {
            case 0:
                while(numNotesAboveThreshold(midiNotes, threshold) < 1) {
                    midiNotes[0] += 12;
                    midiNotes.sort(compare);
                }
            case 1:
                return;
            default:
                while(numNotesAboveThreshold(midiNotes, threshold) > 1) {
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
        var chords = {};
        var segment = curScore.firstSegment();
        while (segment) {
            var annotations = segment.annotations; 
            for (var a in annotations) {
                var annotation = annotations[a];
                if (annotation.name == "Harmony") {
                    // Save the chord for this tick. If multiple tracks have a chord at the same tick,
                    // we will only keep the last one we find.
                    chords[segment.tick] = {tick: segment.tick, text: annotation.text};
                }
            }
            segment = segment.next;
        }

        // Calculate the duration of each chord = start time of next chord - start time of this chord.
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
            var scoreDuration = curScore.lastSegment.tick + 1;
            var lastItem = result[result.length - 1];
            lastItem.duration = scoreDuration - lastItem.tick;
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
        if (!raw) findOptimumInversion(midiNotes, chordSpec);
        addBass(chordSpec, midiNotes);
        return midiNotes;
    }

    // Write a bunch of chords to a given track of the current score, starting at time 0.
    // "chords" is an array of score chord symbol objects like {tick: 1234, text: "Db7", duration: 234}.
    // "theRhythm" is an optional array which describes the rhythm to use for each chord. 
    // If theRhythm is not given, we generate a single chord for each chord.
    function writeChords(chords, track, raw, theRhythm) {
        if (chords.length == 0) return;

        clearStaff(track);

        var cursor = curScore.newCursor();
        cursor.track = track;
        cursor.rewind(Cursor.SCORE_START);

        // Move the cursor to the first chord. NOTE: this code doesn't always work perfectly, it fails to
        // position the cursor exactly at the time of the first chord. I don't know why.
        while (cursor.tick <= chords[0].tick) {
            cursor.next();
        }
        cursor.prev();

        // Process each chord
        for (var i in chords) {
            var theChord = chords[i]; // the chord we're working on

            // find the notes we need to write for this chord
            var midiNotes = chordTextToMidiNotes(theChord.text, raw);

            // find the rhythm
            var rhythm;
            if (theRhythm && theRhythm.length > 0) {
                // the rhythm was given to us. Make a copy of it and make the ticks
                // be relative to the beginning of the score.
                rhythm = [];
                var rhythmDuration = 0;
                for (var n = 0; n < theRhythm.length; n += 1) {
                    var item = shallowCopy(theRhythm[n]);
                    item.tick += theChord.tick;
                    rhythmDuration += item.duration;
                    rhythm.push(item);
                    if (rhythmDuration >= theChord.duration) {
                        rhythm[rhythm.length - 1].duration -= rhythmDuration - theChord.duration;
                        break;
                    }
                }
                if (rhythmDuration < theChord.duration) {
                    rhythm[rhythm.length - 1].duration += theChord.duration - rhythmDuration;
                }
            } else {
                // the rhythm was not provided. We'll just do one chord for the whole duration.
                rhythm = [theChord];
            }

            // Loop over the notes in the rhythm pattern. Generate the midiNotes for each note in the pattern.
            for (var k = 0; k < rhythm.length; k += 1) {
                var chord = rhythm[k];

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
                    if (chord.rest) {
                        addRest(cursor);
                    } else {
                        cursor.addNote(midiNotes[0]);
                        if (!chord.bassOnly) {
                            for (var j = 1; j < midiNotes.length; j += 1) {
                                cursor.addNote(midiNotes[j], true);
                            }
                        }
                    }

                    // NOTE: there is a limitation with cursor.addNote(), it sometimes adds a note shorter
                    // than the requested duration. The following workaround adds the missing time 
                    // back into "duration", and then continues looping.
                    // TODO: find a way to tie all these notes together.
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
    }

    // Here is where do all the work. It's easy - we find all the chords, then write them to the score.
    function expandChordSymbols(raw, rhythmFromSelection) {
        curScore.startCmd();
        writeChords(findAllChordSymbols(), curScore.ntracks - 4, raw, rhythmFromSelection && getSelectedRhythm());
        curScore.endCmd();
    }

    // Following is the UI that appears when you run this plugin. 

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

    CheckBox {
        id:   writeCondensed
        text: "Condense chords to 5 notes or less, near or below middle C"
        checked: true
        anchors.left: window.left
        anchors.top: textLabel1.bottom
        anchors.leftMargin: 10
        anchors.topMargin: 10
    }

    CheckBox {
        id:   rhythmFromSelection
        text: "Use the selected notes as the rhythm pattern"
        enabled: false
        opacity: 0.5
        checked: false
        anchors.left: window.left
        anchors.top: writeCondensed.bottom
        anchors.leftMargin: 10
        anchors.topMargin: 10
        onClicked: {
            if (checked) {
                lowNoteMeansBass.enabled = checked;
                lowNoteMeansBass.opacity = checked ? 1.0 : 0.5;
            }
        }
    }

    CheckBox {
        id:   lowNoteMeansBass
        text: "Bass note only if pattern note is below treble clef"
        enabled: false
        opacity: 0.5
        checked: false
        anchors.left: window.left
        anchors.top: rhythmFromSelection.bottom
        anchors.leftMargin: 40
        anchors.topMargin: 10

    }

    Label {
        id: textLabel2
        wrapMode: Text.WordWrap
        text: ""
        font.pointSize:12
        color: "red"
        anchors.left: window.left
        anchors.top: lowNoteMeansBass.bottom
        anchors.leftMargin: 10
        anchors.topMargin: 30
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
            expandChordSymbols(!writeCondensed.checked, rhythmFromSelection.checked);
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
        textLabel1.text = "Notes for all chords in the score will be written to Staff " + staffName + ".";
        if (gotNotes) {
            textLabel2.text = "Warning: this will overwrite the contents of Staff " + staffName;
        }

        if (getSelectedRhythm()) {
            rhythmFromSelection.enabled = true;
            rhythmFromSelection.opacity = 1.0; 
        }
    }
}
