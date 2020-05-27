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
import Qt.labs.platform 1.0
import QtQuick.Controls 2.0
import "Utils.js" as Utils


// This MuseScore 3 plugin creates files that contains a JSON representation of 
// the musical content of all open scores, including notes, rests, lyrics, and expression. 
// It doesn't write layout information or anything else non-musical, (because
// that wasn't needed for my purposes).

// The plugin works by traversing the current score's data structures and building a simpler, 
// JSON-compatible data structure. It then calls JSON.stringify() and writes
// the resulting string to a file. 

// Version 1 of the plugin writes most of the musical data that is available
// via the MuseScore 3.4 plugin API. There are some things missing
// because I could not find a way to get the information from the API,
// And there might be a few things missing because I'm too lazy:)

MuseScore {
    menuPath: "Plugins.Scores To JSON…"
    version:  "1.0"
    description: qsTr("Write a JSON representation of the musical content of all open scores")
    pluginType: "dialog"
    requiresScore: true

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

    // "getScoreResult()" returns a JSON-compatible data structure representing the score and
    // all its associated data structures.
    //
    // MuseScore's data structures are interesting because there are various ways to traverse them.
    // You can iterate over track number, or you can break that into staff & voice.
    // You can iterate over measures to get segments, or you can iterate the segments directly.
    // You can iterate over tracks, then measures, or you can do measures then tracks.
    // You can use a Cursor object to iterate, or you can follow the links from a score.
    // And so on. I don't think there is one "best" method, they all work.
    //
    // Here is how this plugin views down a score:
    //
    //   A score contains staffs, which contain voices, which contain measures,
    //   which contain segments, which contain Rest elements and Chord elements,
    //   which contain notes, which contain lyrics. In addition a score contains
    //   annotations which are not part of any staff, and measure-related information
    //   which is not part of any staff.
    //
    //  Score
    //      Staff
    //          Voice
    //              Measure
    //                  Segment
    //                      Chord
    //                          Note
    //                              Lyric
    //                      Rest
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
                        var segmentResult = {name: segment.name, tick: segment.tick, type: segment.segmentType.toString()};
                        var element = segment.elementAt((4 * staffNumber) + voiceNumber);
                        if (element) {
                            segmentResult.element = Utils.getElementInfo(element);
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
            var segmentResult = {annotations: [], tick: segment.tick};
            if (segment.annotations) {
                for (var i in segment.annotations) {
                    segmentResult.annotations.push(Utils.getElementInfo(segment.annotations[i]));
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
                    measureResult.elements.push(Utils.getElementInfo(element));
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

    function writeAllScoresToJSON(folder) {
        var message = "Wrote " + scores.length + " scores(s) to "
            + folder.replace(/^file:\/\//, "") + "\n";
        for (var i = 0; i < scores.length; i += 1) {
            var score = scores[i];
            var path = folder + score.scoreName + ".json";
            writeScoreToJSON(score, path);
            // message += "\n" + score.scoreName + ".json";
        }
        messageDialog.text = message;
        messageDialog.open();
    }

    onRun: {
        folderPicker.open();
        Qt.quit();
    }

    ApplicationWindow {
        MessageDialog {
            id: messageDialog
            visible: false
            modality: Qt.WindowModal
            title: "Done!"
            text: "xxx"
        }

        FolderDialog {
            id: folderPicker
            acceptLabel: "Write All Scores"
            onAccepted: {
                writeAllScoresToJSON(folder.toString() + "/");
                Qt.quit()
            }
        }
    }
}