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

import QtQuick 2.2
import MuseScore 3.0
import Qt.labs.platform 1.0 // FolderDialog
import QtQuick.Controls 2.0

// This MuseScore 3 plugin creates a file that contains a JSON representation of 
// the musical content of a score, including notes, rests, lyrics, expression. 
// It doesn't write layout information or anything else non-musical, (only because
// it wasn't needed for my purposes).

// The plugin traverses the current score's data structures and builds a simpler, 
// JSON-compatible data structure. It then calls JSON.stringify() and writes
// the resulting string to a file. 

// Version 1 of the plugin writes most of the musical data that is available
// via the MuseScore 3.4 plugin API. There are some things missing (like tuplets or
// key signatures) because I could not find a way to get the information from the API,
// (and maybe there are a few things missing because I'm too lazy).

MuseScore {
    menuPath: "Plugins.Score To JSON…"
    version:  "1.0"
    description: qsTr("Write a JSON representation of the musical content of a score")
    pluginType: "dialog"
    requiresScore: true

    onRun: {
        folderPicker.open();
    }

    // Create a file at the given path, using the contents of "string".
    // If there is an existing file at that path it will be overwritten.
    // "path" should be an absolute path in the local file system.
    // You may be able to use other kinds of paths, but I haven't tested that.
    function writeFile(path, string) {
        var request = new XMLHttpRequest();
        request.open("PUT", path, false);
        request.send(string);
        return request.status;
    }

    // Find the name of the staff that contains the given track number.
    function getStaffName(score, trackNumber) {
        for (var i = 0; i < score.parts.length; i++) {
            var part = score.parts[i];
            if ((part.startTrack <= trackNumber) && (trackNumber < part.endTrack)) {
                return part.longName;
            }
        }
        return "???";
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

    // Returns a JSON-compatible data structure corresponding to an element.
    function getElementResult(element) {
        var result = {name: element.name};

        if (element.type === Element.REST) {
            result.duration = [element.duration.numerator, element.duration.denominator];

        } else if (element.type === Element.CHORD) {
            result.duration = [element.duration.numerator, element.duration.denominator];

            if (element.notes) {
                result.notes = [];
                for (var i = 0; i < element.notes.length; i += 1) {
                    var note = element.notes[i];
                    var noteResult = {pitch: note.pitch};
                    if (note.tieForward) noteResult.tieForward = true;
                    if (note.tieBack) noteResult.tieBack = true;
                    result.notes.push(noteResult);
                }
            }
            if (element.lyrics && element.lyrics.length > 0) {
                result.lyrics = [];
                for (var j = 0; j < element.lyrics.length; j += 1) {
                    result.lyrics.push(getElementResult(element.lyrics[j]));
                }
            }
            if (element.graceNotes && element.graceNotes.length > 0) {
                result.graceNotes = [];
                for (var k = 0; j < element.graceNotes.length; k += 1) {
                    result.graceNotes.push(getElementResult(element.graceNotes[k]));
                }
            }

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

    // "getScoreResult" returns a JSON-compatible data structure representing the score and
    // all its associated data structures.
    //
    // MuseScore's data structures are interesting because there are various ways to traverse them.
    // You can iterate over track number, or you can break that into staff & voice.
    // You can iterate over measures to get segments, or you can iterate the segments directly.
    // You can iterate over tracks, then measures, or you can do measures then tracks.
    // You can use a Cursor object to iterate, or you can follow the links from a score.
    // And so on. I don't think there is one "best" method, each probably has a purpose.
    //
    // Anyway, here is how we are going to do it here...
    //
    //  Score
    //      Staff
    //          Voice
    //              Measure
    //                  Segment
    //                      Element
    //                          Chord
    //                              Note
    //                              Lyric
    //
    //      Annotations
    //          annotation data that doesn't belong to any Staff
    //
    //      Measures
    //          per-measure data that doesn't belong to any Staff
    //
    function getScoreResult(score) {
        var result = {composer: score.composer, name: score.scoreName, title: score.title, staves: {}};

        // Gather the information in the staffs.
        for (var staffNumber = 0; staffNumber < score.nstaves; staffNumber += 1) {
            var staffResult = {name: getStaffName(score, staffNumber * 4), voices: {}};
            for (var voiceNumber = 0; voiceNumber < 4; voiceNumber += 1) {
                var voiceResult = {measures: {}};
                var measureNumber = 0;
                for (var measure = score.firstMeasure; measure; measure = measure.nextMeasure) {
                    measureNumber += 1;
                    var measureResult = {segments: []};
                    for (var segment = measure.firstSegment; segment; segment = segment.nextInMeasure) {
                        var segmentResult = {tick: segment.tick, type: segment.segmentType.toString(), name: segment.name};
                        var element = segment.elementAt((4 * staffNumber) + voiceNumber);
                        if (element) {
                            segmentResult.element = getElementResult(element);
                            measureResult.segments.push(segmentResult);
                        }
                    }
                    if (measureResult.segments.length > 0) {
                        voiceResult.measures["Staff " + (staffNumber + 1) + ", Voice " + (voiceNumber + 1) + ", Measure " + measureNumber] = measureResult;
                    }
                }
                if (Object.keys(voiceResult.measures).length > 0) {
                    staffResult.voices["Staff " + (staffNumber + 1) + ", Voice " + (voiceNumber + 1)] = voiceResult;
                }
            }
            result.staves["Staff " + (staffNumber + 1)] = staffResult;
        }               

        // Gather the annotations, which are not part of any staff.
        var annotationsResult = [];
        for (var segment = score.firstSegment(); segment; segment = segment.next) {
            var segmentResult = {tick: segment.tick, annotations: []};
            if (segment.annotations) {
                for (var i in segment.annotations) {
                    segmentResult.annotations.push(getElementResult(segment.annotations[i]));
                }
            }
            if (segmentResult.annotations.length > 0) {
                annotationsResult.push(segmentResult)
            }
        }
        result.annotations = annotationsResult; 

        // Gather the per-measure data that is not part of any staff.
        var measureNumber = 0;
        var measuresResult = {};
        for (var measure = score.firstMeasure; measure; measure = measure.nextMeasure) {
            measureNumber += 1;
            var measureResult = {elements: []};
            for (var j = 0; j < measure.elements.length; j += 1) {
                var element = measure.elements[j];
                if (element) {
                    measureResult.elements.push(getElementResult(element));
                }
            }
            if (measureResult.elements.length > 0) {
                measuresResult[measureNumber] = measureResult;
            }
        }
        result.measures = measuresResult; 

        return result;
    }

    function writeScoreToJSON(score, path) {
        var scoreResult = getScoreResult(score);
        var resultString = JSON.stringify(scoreResult, undefined, 4);
        writeFile(path, resultString);
    }

    ApplicationWindow {
        FolderDialog {
            id: folderPicker
            acceptLabel: "OK"
            onAccepted: {
                writeScoreToJSON(curScore, folder.toString() + "/" + curScore.scoreName + ".json");
                Qt.quit();
            }
            onRejected: {
                Qt.quit()
            } 
        }
    }
}