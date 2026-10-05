// lib/services/piano_patterns.dart
import 'package:tonic/tonic.dart' as tonic;
import '../models/chord.dart';
import '../models/song.dart';
import '../utils/chord_utils.dart';
import 'dart:math';

/// Calculates the melodic "distance" between two voicings.
int _calculateVoicingDistance(List<int> voicing1, List<int> voicing2) {
  if (voicing1.isEmpty || voicing2.isEmpty || voicing1.length != voicing2.length) {
    return 9999;
  }
  int distance = 0;
  for (var i = 0; i < voicing1.length; i++) {
    distance += (voicing1[i] - voicing2[i]).abs();
  }
  return distance;
}

/// Finds the best voicing for the current chord based on the previous one.
List<int> _findBestVoicing(tonic.Chord currentChord, List<int> previousVoicing) {
  const int pianoOctave = 2;
  
  // 1. Get the core pitches for our new voicing (3, 5, 7, 9)
  final corePitches = [
    getThird(currentChord),
    getFifth(currentChord),
    getSeventh(currentChord),
    getNinth(currentChord),
  ];

  // 2. Build a proper root position voicing in MIDI notes, handling octave rollovers
  List<int> rootPositionVoicing = [];
  int lastMidiNote = 0;
  for (final pitch in corePitches) {
    int midiNote = 12 * (pianoOctave + 1) + pitch.semitones;
    // If the next note is lower, it should be in the next octave up
    if (rootPositionVoicing.isNotEmpty && midiNote < lastMidiNote) {
      midiNote += 12;
    }
    rootPositionVoicing.add(midiNote);
    lastMidiNote = midiNote;
  }

  // 3. Generate musically correct inversions
  List<List<int>> allInversions = [rootPositionVoicing];
  List<int> currentInversion = List.from(rootPositionVoicing);
  for (var i = 0; i < corePitches.length - 1; i++) {
    // Take the bottom note, add an octave, and move it to the top
    int bottomNote = currentInversion.removeAt(0);
    currentInversion.add(bottomNote + 12);
    allInversions.add(List.from(currentInversion));
  }

  // 4. Generate candidates in a few nearby octaves
  List<List<int>> candidateVoicings = [];
  for (final inversion in allInversions) {
    candidateVoicings.add(inversion); // The base octave
    candidateVoicings.add(inversion.map((n) => n - 12).toList()); // Octave below
    candidateVoicings.add(inversion.map((n) => n + 12).toList()); // Octave above
  }

  // 5. Find the candidate with the minimum distance to the previous voicing
  if (previousVoicing.isEmpty) {
    return candidateVoicings.first;
  }

  List<int> bestVoicing = [];
  int minDistance = 99999;

  for (final candidate in candidateVoicings) {
    final distance = _calculateVoicingDistance(candidate, previousVoicing);
    if (distance < minDistance) {
      minDistance = distance;
      bestVoicing = candidate;
    }
  }

  return bestVoicing;
}

// Comping rhythms. 1 = play, 0 = rest. 8-step patterns are 8th notes and get
// spread onto the 16th grid; 16-step patterns are native 16ths.
const Map<String, List<List<int>>> _compPatterns = {
  'Medium Swing': [
    [0, 0, 0, 1, 0, 0, 0, 1], // Classic: and-of-2, and-of-4
    [0, 1, 0, 1, 0, 0, 0, 0], // Charleston: and-of-1, and-of-2
    [0, 0, 0, 1, 0, 1, 0, 0], // Off-beats: and-of-2, and-of-3
  ],
  'Bossa Nova': [
    [1, 0, 0, 1, 0, 0, 0, 0], // 1, and-of-2
    [1, 0, 1, 0, 0, 1, 0, 1], // 1, 2, and-of-3, and-of-4
    [0, 0, 0, 1, 1, 0, 1, 0], // and-of-2, 3, 4
    [1, 0, 0, 1, 0, 1, 0, 1], // Syncopated
  ],
  'Ballad': [
    [1, 0, 0, 0, 0, 0, 0, 0], // Sustained, once per chord
  ],
  'Rock Ballad': [
    [1, 0, 0, 0, 1, 0, 0, 0], // 1 and 3
    [1, 0, 0, 0, 0, 0, 1, 0], // 1, and re-attack on 4
  ],
  'Fusion': [
    // 1 e & a 2 e & a 3 e & a 4 e & a
    [1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0],
    [0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0],
    [1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0],
  ],
  'Fusion Ballad': [
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], // Pad
    [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0], // Pad, gentle re-attack on 3
  ],
};

List<List<int>> generatePianoTrack(Song song) {
  final List<List<int>> pianoTrack = [];
  List<int> lastVoicing = [];
  final random = Random();
  final transpose = song.transpose;
  final patterns = _compPatterns[song.style] ?? _compPatterns['Medium Swing']!;

  for (final chord in song.chords) {
    final List<List<int>> chordSteps = List.generate(chord.steps, (_) => []);
    try {
      final parsedChord = tonic.Chord.parse(normalizeChordName(chord.name));
      final List<int> baseVoicing = _findBestVoicing(parsedChord, lastVoicing);
      lastVoicing = baseVoicing; // Keep untransposed for voice leading
      final List<int> midiVoicing = baseVoicing.map((n) => n + transpose).toList();

      final pattern = patterns[random.nextInt(patterns.length)];
      final int stepsPerSlot = (stepsPerBeat * 4) ~/ pattern.length; // 2 for 8ths, 1 for 16ths
      for (var i = 0; i < chordSteps.length; i++) {
        if (i % stepsPerSlot == 0 && pattern[(i ~/ stepsPerSlot) % pattern.length] == 1) {
          chordSteps[i] = midiVoicing;
        }
      }
      // Very short chords may fall between comp hits; always sound the change.
      if (chordSteps.isNotEmpty && chordSteps.every((s) => s.isEmpty) && chord.duration < 1.0) {
        chordSteps[0] = midiVoicing;
      }
    } catch (e) {
      print('[Piano] ${chord.name}: $e');
    }
    pianoTrack.addAll(chordSteps);
  }
  return pianoTrack;
}
