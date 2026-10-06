# Improvista

A jazz rhythm section in your pocket. Give Improvista a chord chart and it plays piano, bass and drums underneath you, so you can practise soloing over real changes at any tempo.

Built with Flutter. It's developed and tested on iOS; the Android project is there but untested.

## What it does

- **Six styles:** Medium Swing, Bossa Nova, Ballad, Rock Ballad, Fusion and Fusion Ballad.
  - The **bass** walks or plays a pattern that fits the style, with chromatic approaches.
  - The **drums** play the style's groove; swing gets ride, hi-hat on 2 and 4, and real swung 8ths.
- **Piano that sounds like a comping pianist:**
  - **Rootless voicings** that keep the alterations on the chart: `FΔ7+5`, `A7alt` and `C7♯11` all sound as written.
  - **Smooth movement** between chords, held in the middle register.
  - **Two-handed voicings** in the ballad styles.
  - **Generated swing comping** with anticipated pushes, so no two bars sound the same.
- **Chart features:**
  - repeats with pass counts, plus 1st/2nd endings
  - slash chords
  - transposing instruments (Bb, Eb, F)
  - practice **sections**: loop one solo or the bridge on its own
- **Practice controls:**
  - tempo slider (40–300 BPM)
  - count-in
  - repeat
  - a scrolling chart view that highlights the current chord

## Running it

You need [Flutter](https://docs.flutter.dev/get-started/install) (Dart SDK 3.9+) and, for iOS, Xcode.

```sh
cd improvista_app
flutter pub get
flutter run          # pick the iOS simulator or a connected iPhone
flutter test         # parser, chord table, voicing and comping tests
```

The soundfont (`assets/fluidr3_trio.sf2`) and three sample songs are bundled: Airegin, Blue Bossa and Body and Soul.

## Chart format

Charts are [ChordPro](https://www.chordpro.org/) text files. You can paste them in or load them as `.cho`/`.txt` files.

```
{title: Body and Soul}
{artist: Johnny Green}
{tempo: 60}
{style: Ballad}
{section: AA}
|: [Eb-7] [Bb7b9] | [Eb-7] [Ab7] | [Dbmaj7] [Gb7] | [F-7] [E°7] |
| [Eb-7] | [C-7b5] [F7] | [Bb-7] [Eb-7] [Ab7] |1 [Db6] [Bb7b9] :|2 [Db6] [E-7] [A7] ||
{section: Bridge}
| [Dmaj7] [E-7] | [D/F#] [G-7] [C7] | [F#-7] [B-7] [E-7] [A7] | [Dmaj7] |
| [D-7] [G7] | [Cmaj7] [Eb°7] | [D-7] [G7] | [C7:1] [B7:1] [Bb7:2] |
```

| Directive | Meaning |
|---|---|
| `{title:}` `{artist:}` | shown in the app |
| `{tempo: 140}` | starting tempo in BPM (default 120) |
| `{time: 3/4}` | meter (default 4/4) |
| `{style: Bossa Nova}` | one of the six styles (default Medium Swing) |
| `{transpose: Bb}` | the chart is written for a Bb, Eb or F instrument (or a number of semitones); the band plays concert pitch |
| `{section: Solo 1}` | starts a practice section; the app shows a button to play just that part |
| `{c: ...}` | comment, ignored |

**Bars and beats**
- Bars are separated by `|`.
- In 4/4, one chord fills the bar, two chords split it 2+2, three split it **2+1+1**, and four get a beat each.
- Any other split needs explicit lengths: `[C7:1] [B7:1] [Bb7:2]`.

**Repeats** are written as on the page, and the app unrolls them:
- `|:` and `:|` mark a repeat.
- `:| x4` (or `4x`, `(4x)`) sets a pass count.
- `|1` and `|2` mark 1st and 2nd endings.
- D.S./Coda aren't supported yet; write those out in playing order.

**Chord spellings** can be copied straight off the chart: `Cmaj7`, `CΔ7`, `C-7`, `Cm7b5`, `Cø`, `C°7`, `C7(b9)`, `C7alt`, `FMaj6`, `BbΔ7+5`, `Gm11/F`. The full vocabulary is `chordQualities` in [`chord_utils.dart`](improvista_app/lib/utils/chord_utils.dart). An unknown quality falls back to the closest one it starts with (e.g. `7b9#13` plays as `7b9`).

## Getting your charts in

- **Paste ChordPro:** paste the text into the dialog.
- **Load from File:** keep your charts in a folder in iCloud Drive (or anywhere in the Files app). That folder is your song library.
- **Converting PDFs:** the repo includes a Claude skill, [`.claude/skills/convert-chart`](.claude/skills/convert-chart/SKILL.md), that turns a chart PDF or photo into Improvista ChordPro. It handles both lead sheets and big-band parts: it pulls out the solo sections, sets the transposition from the instrument, and copies the repeats as written. Use it with Claude Code in this repo, or upload it to Claude.

Please don't commit copyrighted charts to this repo.

## Project layout

```
improvista_app/lib/
├── main.dart, views/home_page.dart   app and UI
├── models/                           Song, Chord, RhythmSection
├── services/
│   ├── chord_parser.dart             ChordPro parsing, repeats, sections
│   ├── piano_patterns.dart           voicings, voice leading, comping
│   ├── bass_patterns.dart            walking lines and style patterns
│   ├── drum_patterns.dart            grooves
│   ├── music_generator.dart          builds all three tracks
│   └── audio_player.dart             MIDI playback (flutter_midi_pro), swing timing
└── utils/chord_utils.dart            chord table and spelling rules
```

## License

[MIT](LICENSE) © 2026 Charlie Ciccia.

The bundled soundfont is a subset of **Fluid R3 GM** © Frank Wen and Toby Smithe, MIT-licensed. See [`LICENSE-FluidR3.txt`](improvista_app/assets/LICENSE-FluidR3.txt).
