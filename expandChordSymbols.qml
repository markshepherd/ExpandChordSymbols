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
    version: "0.9"
    description: "Expands chord symbols into a staff"
    menuPath: "Plugins.ExpandChordSymbols"

    // string
    // score chord symbol {tick: <tick>, text: <chord symbol text>, duration: <ticks>}
    // chordSpec
    // abstractNotes object in the form {degree: <adjustment value>, ...}
    // interval (above C, above tonic)
    // midi note - arrays of midinotes are assumed to be sorted by ascending pitch


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
        symbol = symbol.replace(/[()]/g, "");
        var tokens = symbol.match(
        /^([A-Ga-g])?([#♯])?([b♭])?(Major|major|Maj|maj|Ma|ma|M|j)?(minor|min|mi|m|-|−)?(dim|o|°)?(ø|O|0)?(aug|\+)?([tΔ∆\^])?(69|6-9|6\+9|6\/9)?([0-9]+)?(alt)?(sus([0-9])?)?(add([0-9]+))?(drop3|no3)?(([#♯])?([b♭])?([0-9]+))?(([#♯])?([b♭])?([0-9]+))?(([#♯])?([b♭])?([0-9]+))?(\/([A-G])([#♯])?([b♭])?)?/
        );

        // Assign each token to the appropriate field of a chord specification object.
        // If a token is empty, the field is simply undefined.
        var i = 1;
        var result = {
            letter:     tokens[i++],
            sharp:      tokens[i++],
            flat:       tokens[i++],
            major:      tokens[i++],
            minor:      tokens[i++],
            diminished: tokens[i++],
            halfdim:    tokens[i++],
            augmented:  tokens[i++],
            triangle:   tokens[i++],
            sixnine:    tokens[i++],
            number:     tokens[i++],
            alt:        tokens[i++],
            sus:        tokens[i++],
            susnumber:  tokens[i++],
            add:        tokens[i++],
            addnumber:  tokens[i++],
            nothree:    tokens[i++],
            adjustments: [
                {
                    exists: tokens[i++],
                    sharp:  tokens[i++],
                    flat:   tokens[i++],
                    number: tokens[i++]
                },
                {
                    exists: tokens[i++],
                    sharp:  tokens[i++],
                    flat:   tokens[i++],
                    number: tokens[i++]
                },
                {
                    exists: tokens[i++],
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
        // console.log(JSON.stringify(result));
        return result;
    }

    // Given a chord specification, return an abstractNotes object containing all the notes of the chord.
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
            if (a.exists) {
                result[a.number] = a.sharp ? 1 : -1;
                result[7] = seventh;
            }
        }

        return result;
    }

    // Deletes items from an abstractNotes object, to make it contain no more than maxLength notes.
    // Eliminates notes that are less important harmonically, in this order: tonic, perfect 5,
    // then secondary color notes (e.g. the 11th and 9th in a 13th chord).
    function prune(maxLength, abstractNotes) {
        var initialLength = countProperties(abstractNotes);

        // Keep deleting items until we have the right number of items.
        loop: while (countProperties(abstractNotes) > maxLength) {
            // delete the tonic note if it exists
            if (abstractNotes[1] != undefined) {
                delete abstractNotes[1];
                continue loop;
            }

            // delete the perfect 5 if it exists
            if (abstractNotes[5] == 0) {
                delete abstractNotes[5];
                continue loop;
            }

            // delete 2nd highest note, so e.g. we'll keep 13 but delete 11 and 9
            var indices = [];
            for (var i in abstractNotes) indices.push(i);
            delete abstractNotes[indices[indices.length - 2]];
        }
    }

    // Given a abstractNotes object, returns the corresponding array of midi notes,
    // based on the root note from "chordSpec".
    function render(abstractNotes, chordSpec) {
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

        // For each abstract note, construct the corresponding midi note.
        var notesemitones = {1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11, 8: 12, 9: 14, 10: 16, 11: 17, 12: 19, 13: 21};
        for (var i in abstractNotes) {
            // the midi note = tonic midi note + the number of semitones above the tonic + adjustment (-1,0,+1).
            midiNotes.push(tonicMidiNote + notesemitones[i] + abstractNotes[i]);
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
                        chords[cursor.tick] = {tick: cursor.tick, text: annotation.text};
                    }
                }
                cursor.next();
            }
        }

        // Now calculate the duration of each chord (duration = start time of next chord - start time of this chord).
        var lastChord;
        for (var i in chords) {
            var chord = chords[i];
            if (lastChord) {
                lastChord.duration = chord.tick - lastChord.tick;
            }
            lastChord = chord;
        }
        lastChord.duration = 960; // I don't know how to find the duration of the very last chord :(

        return chords;
    }

    // Given a text chord symbol (e.g. "C7b9"), return an array of midi notes (e.g. [60, 64, 67, 70, 73]).
    // If raw = true, you get all the notes of the chord, which can be 9 or 10 notes for complex chords.
    // If raw = false, you get at most 5 notes, in an inversion that puts most of the notes near or below middle C.
    function chordTextToMidiNotes(text, raw) {
        var chordSpec = parseChordSymbol(text);
        var abstractNotes = expandChordSpec(chordSpec);
        if (!raw) prune(4, abstractNotes);
        var midiNotes = render(abstractNotes, chordSpec);
        if (!raw) findOptimumInversion(midiNotes);
        addBass(chordSpec, midiNotes);
        return midiNotes;
    }

    // Write a bunch of chords to a given track of the current score, starting at time 0.
    // Chords is an array of score chord symbol objects like {tick: 1234, text: "Db7", duration: 234}.
    function writeChords(chords, track, raw) {
        var cursor = curScore.newCursor();
        cursor.track = track;
        cursor.rewind(Cursor.SCORE_START);

        // Here is what we do for each chord.
        for (var i in chords) {
            var chord = chords[i]; // the chord we're working on
            var midiNotes = chordTextToMidiNotes(chord.text, raw); // the notes we want to write for this chord
            var duration = chord.duration; // the duration of the chord, in midi ticks
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

                // Add all the midi notes to the score. If there are no midi notes, add a dummy note.
                // This is awkward code, do you know a better way?
                var beforeTick = cursor.tick; 
                cursor.addNote(midiNotes[0]);
                for (var j = 1; j < midiNotes.length; j += 1) {
                    cursor.addNote(midiNotes[j], true);
                }

                // NOTE: there is a bug in cursor.addNote(), it sometimes adds a note shorter
                // than the requested duration. The workaround is to add the missing time 
                // back into "duration", and then continue looping.
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

    // Here is where it all happens. It's easy .. you find all the chords, then write them to the score.
    onRun: {
        if (curScore) {
            writeChords(findAllChordSymbols(), curScore.ntracks - 4, false);
        }
        Qt.quit();        
    }
}
