# Expand Chord Symbols

This MuseScore 3 plugin generates notes for all the chord symbols in the current score.

The user can choose whether to generate:
* all the notes in each chord, which could be 8 or 9 notes for a complex chord like C13, or
* a condensed chord containing only the 4 most harmonically important notes, plus a bass note, and inverted as needed 
so that most of the notes are near or below middle C. This "condensed" mode produces voicings that are almost identical
to Marc Sabatella's recommended voicings shown [here](https://www.youtube.com/watch?v=iaca_EAmBCE&feature=youtu.be%0A) and [here](https://musescore.com/marcsabatella/chord-symbol-voicings-for-playback).

You can also choose between:
* each generated chord is a single stack of notes
* generated chords follow an arbitrary user-specified rhythm pattern

All generated notes are added to voice 1 of the last staff in the score. Any existing notes in that voice in that staff will be overwritten.

The following chord symbol features are supported in the current version:
Feature | Example
------- | -------
*letter*[b ♭ # ♯] | A, Bb, C#
Major, major, Maj, maj, Ma, ma, M, j | Cma, DM7
minor, min, mi, m, -, − | Dmi, D-9
dim, o, ° | Ebdim, E°7
ø, O, 0 | Abø7
aug, + | Db+
t, Δ, ∆, ^ | C∆7
69, 6-9, 6+9, 6/9 | G6/9
*number* | C7, E13
(Major, major, Maj, maj, Ma, ma, M, j *number*) | Cmi(ma7)
alt | Dalt
sus[*number*] | Asus, Dsus2
add*number* | Cadd4
drop3, no3 | Fdrop3
b*number* ... | C7b5b9
#*number* ... | Eb7#9#11
/ *letter*[b #] | D7/A

You may enclose parts of the chord symbol in parentheses, for example "C9(#5)".

To install the plugin:
1. download the file ExpandChordSymbols.zip
1. expand the zip file. The result is a folder "ExpandChordSymbols"
1. move the ExpandChordSymbols folder into your MuseScore Plugins folder, which can be found here:
   * Windows: %HOMEPATH%\Documents\MuseScore3\Plugins
   * Mac: ~/Documents/MuseScore3/Plugins
   * Linux: ~/Documents/MuseScore3/Plugins
1. launch MuseScore3
1. select the menu item Plugins > Plugin Manager...
1. in the resulting dialog, enable expandChordSymbol
   
To use the plugin:
1. make sure that the last staff in the score is the one you want the plugin to modify. If necessary, go to Edit > Instruments and move or add staffs as required. Set the staff to bass clef.
1. select the menu item Plugins > Expand Chord Symbols….
1. the resulting dialog tells you which staff the plugin will write to, warns you if any existing notes will be overwritten, and lets you choose various options.
1. click OK

To use a rhythm pattern, enable "Use a rhythm pattern" in the dialog. Clicking on the note images (1/8, 1/4 etc.) will add items to the rhythm pattern. Clicking on the notes in the pattern will cycle between various voicings: All notes, Bass note only, non-Bass notes only, or Rest. If you select a sequence of notes anywhere in the score before launching the dialog, you can then click "Use selection" to load those notes into the rhythm pattern.

When the dialog is launched, it displays the last rhythm pattern that you used on this score. If you don't want to use that, just click "Clear".

When using the rhythm pattern option, please be aware of the following:
* you can't edit a pattern. to make changes, use the "Clear" button, then enter the desired pattern
* the plugin cannot generate tied notes
* tuplets (triplets, quintuplets, etc) cannot be used in the rhythm pattern
* if you do "Use selection" the rhythm pattern is taken from the first voice of the first staff of the selection
* if you choose "Restart pattern for every chord symbol", the plugin will always fill the entire time between one chord symbol and the next, starting at the beginning of the pattern. If the pattern is too long, we don't use all of it. If the pattern is too short, it is extended with sustained notes. The pattern is re-started for each chord symbol.
* if you choose "Repeat pattern over entire score" (the default), then the rhythm pattern is repeated over and over again for entire score. The rhythm pattern can be any length you like - in many cases you will want exactly 1 measure long, but other times you may want just a few beats, or many measures long.
* there is a limit of 16 items in the rhythm pattern (because longer patterns won't fit in the dialog).
* if the first chord of the score is not at the very beginning, the first few generated notes might have the wrong timing. Sorry about that!

To download the plugin from this web page:
1. click on ExpandChordSymbols.zip (above)
1. on the resulting page, click the button "Download", just above the text


