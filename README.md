# Expand Chord Symbols

This MuseScore 3 plugin generates notes for all the chord symbols in the current score.

The user can choose whether to generate:
* all the notes in each chord, which could be 8 or 9 notes for a complex chord like C13, or
* a condensed chord containing only the 4 most harmonically important notes, plus a bass note, and inverted as needed 
so that most of the notes are near or below middle C. This "condensed" mode produces voicings that are almost identical
to Marc Sabatella's recommended voicings shown [here](https://www.youtube.com/watch?v=iaca_EAmBCE&feature=youtu.be%0A) and [here](https://musescore.com/marcsabatella/chord-symbol-voicings-for-playback).

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

To install the plugin:
1. download the file ExpandChordSymbols.qml to your Plugins folder, which can be found here:
   * Windows: %HOMEPATH%\Documents\MuseScore3\Plugins
   * Mac: ~/Documents/MuseScore3/Plugins
   * Linux: ~/Documents/MuseScore3/Plugins
1. launch MuseScore3
1. select the menu item Plugins > Plugin Manager...
1. in the resulting dialog, enable expandChordSymbol
   
To use the plugin:
1. make sure that the last staff in the score is the one you want the plugin to modify. If necessary, go to Edit > Instruments and move or add staffs as required. Set the staff to bass clef.
1. select the menu item Plugins > Expand Chord Symbols….
1. the resulting dialog tells you which staff the plugin will write to, warns you if any existing notes will be overwritten, and lets you choose raw vs. condensed mode.
1. click OK
     
Hint: to download the plugin from this web page:
1. click on ExpandChordSymbols.qml (above)
1. on the resulting page, find the button "Raw", just above the text
1. right-click on the Raw button, and select Save Link As... (your browser may have different wording)

For more information, see the [MuseScore plugin page](https://musescore.org/en/project/expand-chord-symbols-notes).
