// lib/services/bass_patterns.dart
import 'dart:math';
import 'package:tonic/tonic.dart' as tonic;
import '../models/chord.dart';
import '../utils/chord_utils.dart';
import '../models/song.dart';

const int bassOctave = -1;
final _random = Random();

/// Expands an 8-step pattern to 16-step by inserting a 0 (rest) between each original step.
List<int> _expandTo16(List<int> pattern8) {
  final List<int> pattern16 = [];
  for (final note in pattern8) {
    pattern16.add(note);  // Original 8th note position
    pattern16.add(0);     // Empty 16th note position
  }
  return pattern16;
}

/// Helper to convert pitch to MIDI note in bass octave
int _pitchToMidi(tonic.Pitch pitch) => 12 * (bassOctave + 1) + pitch.semitones;

/// Get chromatic approach note to target (from above or below randomly)
int _chromaticApproach(int targetMidi) {
  return _random.nextBool() ? targetMidi - 1 : targetMidi + 1;
}

/// Get the effective bass MIDI note for a chord, considering slash bass notation.
/// Returns the slash bass note if present, otherwise the chord root.
int _getEffectiveBass(String chordName, tonic.Chord parsedChord) {
  final slashBass = getSlashBassNote(chordName);
  if (slashBass != null) {
    final bassPitch = parseNoteName(slashBass);
    if (bassPitch != null) {
      return _pitchToMidi(bassPitch);
    }
  }
  return _pitchToMidi(parsedChord.root);
}

/// Generates a one-measure Bossa Nova bass pattern for a given chord.
List<int> generateBossaNovaBass({
  required Chord currentChord,
  required Chord nextChord,
}) {
  final parsedChord = tonic.Chord.parse(normalizeChordName(currentChord.name));
  final rootNote = _getEffectiveBass(currentChord.name, parsedChord);
  final fifthNote = _pitchToMidi(getFifth(parsedChord));

  int lastNote;
  if (currentChord.name != nextChord.name) {
    final nextParsed = tonic.Chord.parse(normalizeChordName(nextChord.name));
    final nextBass = _getEffectiveBass(nextChord.name, nextParsed);
    lastNote = _chromaticApproach(nextBass);
  } else {
    lastNote = rootNote;
  }

  // Bossa patterns - pick one randomly
  final patterns = [
    [rootNote, 0, 0, fifthNote, fifthNote, 0, 0, lastNote],
    [rootNote, 0, fifthNote, 0, rootNote, 0, 0, lastNote],
    [rootNote, 0, 0, rootNote, fifthNote, 0, 0, lastNote],
  ];
  return patterns[_random.nextInt(patterns.length)];
}

/// Generates a one-measure Ballad bass pattern for a given chord.
List<int> generateBalladBass(String chordName, tonic.Chord chord) {
  final rootNote = _getEffectiveBass(chordName, chord);
  final fifthNote = _pitchToMidi(getFifth(chord));

  // Ballad patterns - sparse but melodic
  final patterns = [
    [rootNote, 0, 0, 0, fifthNote, 0, 0, 0],
    [rootNote, 0, 0, 0, 0, 0, 0, 0],
    [rootNote, 0, 0, fifthNote, 0, 0, rootNote, 0],
  ];
  return patterns[_random.nextInt(patterns.length)];
}

/// Generates a one-measure Rock Ballad bass pattern - more movement than jazz ballad.
List<int> generateRockBalladBass(String chordName, tonic.Chord chord) {
  final rootNote = _getEffectiveBass(chordName, chord);
  final fifthNote = _pitchToMidi(getFifth(chord));
  final octaveUp = rootNote + 12;

  // Rock ballad patterns - steady 8th notes with root-fifth movement
  final patterns = [
    // Classic root-fifth pattern
    [rootNote, 0, rootNote, 0, fifthNote, 0, fifthNote, 0],
    // Root-fifth with octave
    [rootNote, 0, fifthNote, 0, rootNote, 0, octaveUp, 0],
    // Driving 8ths on root
    [rootNote, 0, rootNote, 0, rootNote, 0, fifthNote, 0],
    // Melodic climb
    [rootNote, 0, rootNote + 2, 0, fifthNote, 0, rootNote, 0],
  ];
  return patterns[_random.nextInt(patterns.length)];
}

/// Generates a one-measure Fusion bass pattern - syncopated 16th-note lines.
/// Returns native 16-step pattern (no expansion needed).
List<int> generateFusionBass(String chordName, tonic.Chord chord) {
  final root = _getEffectiveBass(chordName, chord);
  final third = _pitchToMidi(getThird(chord));
  final fifth = _pitchToMidi(getFifth(chord));
  final seventh = _pitchToMidi(getSeventh(chord));
  final octave = root + 12;

  // Fusion patterns - syncopated 16th notes with ghost notes and chromatic approaches
  // Position: 1 e & a 2 e & a 3 e & a 4 e & a
  final patterns = [
    // Pattern 1: Classic funk-fusion line
    [root, 0, 0, root, 0, 0, fifth, 0, 0, 0, 0, third, 0, 0, root, 0],
    // Pattern 2: Syncopated with octave jump
    [root, 0, 0, 0, root, 0, 0, octave, 0, 0, fifth, 0, 0, 0, 0, root - 1],
    // Pattern 3: Busy 16th-note run
    [root, 0, root, 0, third, 0, fifth, 0, seventh, 0, fifth, 0, third, 0, root, 0],
    // Pattern 4: Chromatic approach tones
    [root, 0, 0, root + 1, root + 2, 0, third, 0, 0, 0, fifth - 1, fifth, 0, 0, 0, 0],
    // Pattern 5: Sparse with pickup
    [root, 0, 0, 0, 0, 0, fifth, 0, 0, 0, 0, 0, 0, 0, root - 1, root],
  ];
  return patterns[_random.nextInt(patterns.length)];
}

/// Generates a Fusion Ballad bass pattern - very sparse, breathing room.
/// Uses chord duration to decide density: shorter chords may get rests entirely.
/// Returns native 16-step pattern for sub-beat chord change support.
List<int> generateFusionBalladBass(String chordName, tonic.Chord chord, {required double duration}) {
  final root = _getEffectiveBass(chordName, chord);
  final fifth = _pitchToMidi(getFifth(chord));
  final numSteps = (duration * stepsPerBeat).round();

  // Short chords (< 2 beats): mostly rest, occasional root
  if (duration < 2.0) {
    if (_random.nextDouble() < 0.6) {
      return List.filled(numSteps, 0); // Rest - let it breathe
    }
    return [root, ...List.filled(numSteps - 1, 0)];
  }

  // Medium chords (2-3 beats): root only
  if (duration < 4.0) {
    return [root, ...List.filled(numSteps - 1, 0)];
  }

  // Full measure (4 beats): sparse patterns
  // Position: 1 e & a 2 e & a 3 e & a 4 e & a
  final patterns = [
    // Root only - very sparse
    [root, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    // Root only (weighted towards this)
    [root, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    // Root on 1, fifth on 3
    [root, 0, 0, 0, 0, 0, 0, 0, fifth, 0, 0, 0, 0, 0, 0, 0],
  ];
  return patterns[_random.nextInt(patterns.length)];
}

/// Generates a style-specific walking bass line for a single chord.
List<int> generateSwingBass({
  required Chord currentChord,
  required Chord nextChord,
}) {
  final normalizedName = normalizeChordName(currentChord.name);
  final parsedChord = tonic.Chord.parse(normalizedName);

  final root = _getEffectiveBass(currentChord.name, parsedChord);
  final third = _pitchToMidi(getThird(parsedChord));
  final fifth = _pitchToMidi(getFifth(parsedChord));
  final seventh = _pitchToMidi(getSeventh(parsedChord));

  final int numBeats = currentChord.duration.toInt();

  // Determine approach note to next chord
  int approachNote;
  if (currentChord.name != nextChord.name) {
    final nextParsed = tonic.Chord.parse(normalizeChordName(nextChord.name));
    final nextBass = _getEffectiveBass(nextChord.name, nextParsed);
    approachNote = _chromaticApproach(nextBass);
  } else {
    // Approach back to own root
    approachNote = _chromaticApproach(root);
  }

  List<int> quarterNotes;

  if (numBeats == 1) {
    quarterNotes = [root];
  } else if (numBeats == 2) {
    // 2-beat patterns
    final patterns = [
      [root, approachNote],
      [root, third],
      [root, fifth],
    ];
    quarterNotes = patterns[_random.nextInt(patterns.length)];
  } else if (numBeats == 3) {
    final patterns = [
      [root, third, approachNote],
      [root, fifth, approachNote],
      [root, third, fifth],
    ];
    quarterNotes = patterns[_random.nextInt(patterns.length)];
  } else {
    // 4+ beat walking patterns - the meat of jazz walking bass!
    final patterns = [
      // Classic patterns
      [root, third, fifth, approachNote],
      [root, fifth, third, approachNote],
      [root, third, seventh, approachNote],
      // Chromatic passing tones
      [root, root + 1, root + 2, third],
      [root, fifth, fifth - 1, approachNote],
      // Scalar motion
      [root, root + 2, root + 4, approachNote],
      [root, root - 2, root - 3, approachNote],
      // Arpeggios with approach
      [root, third, fifth, seventh],
      [root, fifth, seventh, approachNote],
      // Pedal patterns
      [root, third, root, approachNote],
      [root, fifth, root, approachNote],
    ];
    quarterNotes = patterns[_random.nextInt(patterns.length)];

    // For longer than 4 beats, extend with more notes
    while (quarterNotes.length < numBeats) {
      quarterNotes.insert(quarterNotes.length - 1, fifth);
    }
  }

  // Convert to 16th-note resolution (note on quarter, rests on 16ths)
  final List<int> finalNotes = [];
  for (final note in quarterNotes) {
    finalNotes.add(note);  // Quarter note position
    finalNotes.add(0);     // 16th
    finalNotes.add(0);     // 8th
    finalNotes.add(0);     // 16th
  }
  return finalNotes;
}

List<int> generateBassLine(Song song) {
  final List<int> midiNotes = [];
  final chords = song.chords;
  final transpose = song.transpose;

  for (var i = 0; i < chords.length; i++) {
    try {
      final currentChord = chords[i];
      final nextChord = chords[(i + 1) % chords.length];
      final parsedChord = tonic.Chord.parse(normalizeChordName(currentChord.name));
      final numSteps = currentChord.steps;

      List<int> notes;

      // For sub-beat durations (< 1 beat), just play the root
      if (currentChord.duration < 1.0) {
        final root = _getEffectiveBass(currentChord.name, parsedChord);
        notes = [root, ...List.filled(numSteps - 1, 0)];
      } else {
        switch (song.style) {
          case 'Bossa Nova':
            notes = _expandTo16(generateBossaNovaBass(
              currentChord: currentChord,
              nextChord: nextChord,
            ));
            break;
          case 'Ballad':
            notes = _expandTo16(generateBalladBass(currentChord.name, parsedChord));
            break;
          case 'Rock Ballad':
            notes = _expandTo16(generateRockBalladBass(currentChord.name, parsedChord));
            break;
          case 'Fusion':
            // Fusion bass is native 16-step, no expansion needed
            notes = generateFusionBass(currentChord.name, parsedChord);
            break;
          case 'Fusion Ballad':
            // Fusion Ballad bass is native 16-step, sparse patterns
            notes = generateFusionBalladBass(currentChord.name, parsedChord, duration: currentChord.duration);
            break;
          case 'Medium Swing':
          default:
            // Swing bass already outputs 16-step patterns
            notes = generateSwingBass(
              currentChord: currentChord,
              nextChord: nextChord,
            );
            break;
        }
        // Trim or pad to match actual chord duration
        if (notes.length > numSteps) {
          notes = notes.sublist(0, numSteps);
        } else if (notes.length < numSteps) {
          notes = [...notes, ...List.filled(numSteps - notes.length, 0)];
        }
      }
      // Apply transposition to non-rest notes
      midiNotes.addAll(notes.map((n) => n > 0 ? n + transpose : n));
    } catch (e) {
      print('[Bass] ${chords[i].name}: $e');
      midiNotes.addAll(List.filled(chords[i].steps, 0));
    }
  }
  return midiNotes;
}