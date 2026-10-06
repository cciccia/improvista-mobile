# Improvista

A Flutter app that generates jazz rhythm section accompaniment (bass, piano, drums) from ChordPro-format chord charts.

## Quick Start

```bash
flutter run                    # Run on connected device/emulator
flutter run -d chrome          # Run on web (no MIDI support)
flutter run -d <device_id>     # Run on specific device
```

## Architecture

```
lib/
├── main.dart                  # App entry point, MaterialApp setup
├── views/
│   └── home_page.dart         # Main UI: song loading, tempo slider, playback controls
├── models/
│   ├── song.dart              # Parsed song: title, tempo, chords, style, transpose
│   ├── chord.dart             # Chord with name and duration (in beats)
│   ├── rhythm_section.dart    # Container for bass/piano/drum tracks
│   └── drum_note.dart         # MIDI note + velocity for drums
├── services/
│   ├── chord_parser.dart      # ChordPro file parser
│   ├── music_generator.dart   # Orchestrates bass/piano/drum generation
│   ├── bass_patterns.dart     # Walking bass line generation
│   ├── piano_patterns.dart    # Piano voicings with voice leading
│   ├── drum_patterns.dart     # Style-specific drum patterns
│   └── audio_player.dart      # MIDI playback via flutter_midi_pro
└── utils/
    └── chord_utils.dart       # Chord table: quality -> bass tones + piano voicing
```

## ChordPro Format

Songs use ChordPro format with these supported directives:

```
{title: Song Name}
{artist: Composer}
{tempo: 140}              # BPM (default: 120)
{time: 4/4}               # Time signature (default: 4/4)
{style: Medium Swing}     # Style: Medium Swing, Bossa Nova, Ballad, Rock Ballad, Fusion, Fusion Ballad
{transpose: Bb}           # Instrument key: Bb, Eb, F, C, or semitones (-2, 3, etc.)
{c: Comment}              # Comments (ignored during parsing)
{section: Solo 1}         # Practice section: chips in the UI play just this part (until next {section:})

| [Dm7] | [G7] | [Cmaj7] | [Cmaj7] |
| [Am7] [D7] | [Gmaj7] |           # 2 chords = 2 beats each
| [Cmaj7/E] | [Fmaj7/A] |          # Slash chords: chord/bass note
| [Dm7:0.5] [G7:0.5] [Cmaj7:3] |   # Explicit durations in beats
```

### Repeats and Endings
Expanded into playing order by `expandRepeats` in `chord_parser.dart`:
```
|: [A] | [B] :|            # play twice
|: [A] :| x4               # pass count: x4, 4x or (4x)
|: [A] |1 [B] :|2 [C] ||   # 1st ending plays every pass but the last
[A] | [B] :|               # no |: = repeat from the top (or the previous repeat)
```
Only two endings; D.S./D.C./Coda are not unrolled.

### Chord Duration Rules
Default rules (when no explicit duration specified):
- 1 chord per measure = 4 beats
- 2 chords = 2 beats each
- 3 chords = 2, 1, 1 beats
- 4 chords = 1 beat each

Explicit duration syntax: `[ChordName:beats]`
- Use when you need half-beat or irregular durations
- If ANY chord in a measure has explicit duration, all should
- Examples: `[Dm7:0.5]` = half beat, `[Cmaj7:3]` = 3 beats

## Key Dependencies

- **flutter_midi_pro**: MIDI playback with soundfont support
- **file_picker**: File selection on device

## Audio Implementation

- Playback uses 16th-note resolution (4 steps per beat)
- Bass track: `List<int>` - MIDI notes, 0 = rest
- Piano track: `List<List<int>>` - chord voicings per step
- Drums track: `List<List<DrumNote>>` - multiple simultaneous hits per step
- Soundfonts in `assets/`: melodic (piano, bass) and drums
- Legacy 8th-note patterns are auto-expanded to 16th resolution

## Chord Parsing Notes

`chord_utils.dart` holds the whole chord vocabulary in `chordQualities`. Each quality gives:
- bass chord tones (3rd — or 4th for sus — altered 5th, 7th)
- piano notes in priority order (guide tones, then colours); a style plays the first N

`standardizeQuality` maps chart spellings onto table keys (Δ7+5 → maj7#5, Maj6 → 6, ø → m7b5, -7 → m7, 7(b9) → 7b9).
An unknown quality falls back to its longest known prefix (7b9#13 → 7b9) and logs `[Chord] ...` — chords are never silent.
To support a new quality, add it to `chordQualities`.

Piano voicings are rootless (the bass has the root). Up to 4 notes stack close; Ballad / Fusion Ballad / Rock Ballad use 6,
with the guide tones in the left hand and colours above. The lowest note always sits in C4–B4 (`pianoLowestNote`).
Slash chords: the bass plays the slash note, the piano voices the chord.

## Style-Specific Patterns

**Medium Swing** (default):
- Walking bass with chromatic approaches
- Ride cymbal pattern, hi-hat foot on 2 & 4
- Piano comps on off-beats

**Bossa Nova**:
- Root-fifth bass pattern
- Cross-stick and hi-hat pattern
- Syncopated piano rhythms

**Ballad**:
- Sparse whole-note bass
- Brush patterns
- Sustained piano chords

**Rock Ballad**:
- Steady 8th-note bass with root-fifth movement
- Hi-hat 8ths, snare on 2 & 4, fuller kick presence
- Sustained piano with gentle re-attacks

**Fusion**:
- Syncopated 16th-note bass lines with chromatic approaches
- 16th hi-hat with ghost notes on "e" and "a" subdivisions
- Syncopated stab-style piano comping on 16ths

**Fusion Ballad**:
- Sparse bass (root on 1, occasional 5th) with 16th-note resolution for sub-beat changes
- Light brushes/mallets, soft ride cymbal
- Sustained piano pads with gentle re-attacks
- Best for songs with half-beat chord changes that need a spacious feel

## Transposition

Supports instrument transposition via `{transpose: Bb}`:
- Bb instruments: -2 semitones (trumpet, tenor sax, clarinet)
- Eb instruments: -9 semitones (alto sax, baritone sax)
- F instruments: -7 semitones (French horn)
- C: concert pitch (no transposition)

## Sample Songs

Bundled in `assets/songs/`:
- `airegin.txt` - Fast bebop (240 BPM)
- `bluebossa.txt` - Bossa Nova (130 BPM)

## Soundfonts

`assets/fluidr3_trio.sf2` (20 MB) is a subset of FluidR3_GM (MIT, notice in `assets/LICENSE-FluidR3.txt`, registered with `LicenseRegistry` in `main.dart`) holding only:
- 0:0 Yamaha Grand Piano, 0:32 Acoustic Bass, 128:40 Brush kit (drums)

The full 148 MB FluidR3_GM.sf2 lives in the gitignored `../soundfont-originals/`. To use another preset, re-trim from it — trying a kit by `drumKit` number only works for kits that are in the subset.
The old E-mu `acoustickits 3&4.sf2` was dropped: it carries no redistribution license.

## Common Issues

- **iOS Simulator no audio**: Check simulator sound settings (Device > Sound)
- **`[Chord] unknown quality` in the log**: add the quality to `chordQualities` in `chord_utils.dart`
- **Hot reload doesn't update assets**: Full restart required for asset changes

## Future Enhancements

### Playback & Navigation
- [ ] Progress bar - Visual timeline showing position in the song, clickable to jump to any point
- [x] Measure counter - Display current measure number (e.g., "Bar 12 of 32")
- [x] Count-in - 1-2 bar metronome count before playback starts
- [ ] A-B loop - Select a section to loop for focused practice

### Practice Features
- [ ] Instrument muting - Toggle bass/piano/drums individually to practice playing along
- [ ] Volume sliders - Adjust relative levels of each instrument
- [ ] Gradual tempo increase - Start slow and automatically speed up over repeats

### Chord Display
- [ ] Upcoming chords - Show next 2-3 chords so you can prepare
- [x] Full chart view - Scrolling chord chart with current position highlighted
- [x] Measure grid - Visual layout matching the ChordPro bar lines

### Song Management
- [ ] Favorites/recent songs - Quick access to frequently used charts
- [ ] Setlist mode - Queue multiple songs to play in sequence
- [ ] Remember tempo per song - Persist tempo adjustments

### Export
- [ ] MIDI export - Save generated tracks for use in a DAW
