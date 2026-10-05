// lib/services/drum_patterns.dart
import 'dart:math';
import '../models/drum_note.dart';
import '../models/song.dart';

const int kick = 36;
const int snare = 38;
const int crossStick = 37;
const int brushSnare = 40;
const int closedHiHat = 42;
const int rideCymbal = 51;
const int pedalHiHat = 44;

// Patterns below are written in 8th notes; _x2 spreads them onto the 16th grid.
final Map<String, List<List<DrumNote>>> _eighthPatterns = {
  'Bossa Nova': [
    // A more authentic, 2-measure Bossa Nova pattern (16 steps)
    // --- Measure 1 ---
    // Beat 1
    [DrumNote(kick, velocity: 100), DrumNote(closedHiHat, velocity: 70)],
    [DrumNote(closedHiHat, velocity: 70)],
    // Beat 2
    [DrumNote(crossStick, velocity: 95), DrumNote(closedHiHat, velocity: 70)],
    [DrumNote(kick, velocity: 90), DrumNote(closedHiHat, velocity: 70)],
    // Beat 3
    [DrumNote(kick, velocity: 100), DrumNote(closedHiHat, velocity: 70)],
    [DrumNote(closedHiHat, velocity: 70)],
    // Beat 4
    [DrumNote(crossStick, velocity: 95), DrumNote(closedHiHat, velocity: 70)],
    [DrumNote(kick, velocity: 90), DrumNote(closedHiHat, velocity: 70)],

    // --- Measure 2 ---
    // Beat 1
    [DrumNote(kick, velocity: 100), DrumNote(closedHiHat, velocity: 70)],
    [DrumNote(closedHiHat, velocity: 70)],
    // Beat 2
    [DrumNote(crossStick, velocity: 95), DrumNote(closedHiHat, velocity: 70)],
    [DrumNote(kick, velocity: 90), DrumNote(closedHiHat, velocity: 70)],
    // Beat 3
    [DrumNote(kick, velocity: 100), DrumNote(closedHiHat, velocity: 70)],
    [DrumNote(closedHiHat, velocity: 70)],
    // Beat 4 (slight variation leading back to the start)
    [DrumNote(crossStick, velocity: 95), DrumNote(closedHiHat, velocity: 70)],
    [DrumNote(closedHiHat, velocity: 70)],
  ],
  'Ballad': [
    // A 1-measure Ballad pattern with brushes
    [DrumNote(kick, velocity: 80)], [], [DrumNote(brushSnare, velocity: 70)], [],
    [DrumNote(kick, velocity: 80)], [], [DrumNote(brushSnare, velocity: 70)], [],
  ],
};

List<List<DrumNote>> _x2(List<List<DrumNote>> eighths) =>
    [for (final hit in eighths) ...[hit, const <DrumNote>[]]];

DrumNote _hh(int v) => DrumNote(closedHiHat, velocity: v);

// Native 16th-note patterns.
final Map<String, List<List<DrumNote>>> _sixteenthPatterns = {
  'Rock Ballad': [
    // 1 e & a 2 e & a 3 e & a 4 e & a — hats on 8ths, snare 2 & 4, kick 1, a-of-2, 3
    [DrumNote(kick, velocity: 105), _hh(80)], [], [_hh(65)], [],
    [DrumNote(snare, velocity: 105), _hh(80)], [], [_hh(65)], [DrumNote(kick, velocity: 85)],
    [DrumNote(kick, velocity: 100), _hh(80)], [], [_hh(65)], [],
    [DrumNote(snare, velocity: 105), _hh(80)], [], [_hh(65)], [],
  ],
  'Fusion': [
    // 16th hats, ghosts on e/a, snare 2 & 4, syncopated kick
    [DrumNote(kick, velocity: 105), _hh(85)], [_hh(45)], [_hh(70)], [DrumNote(kick, velocity: 90), _hh(45)],
    [DrumNote(snare, velocity: 110), _hh(85)], [_hh(45), DrumNote(snare, velocity: 35)], [_hh(70)], [_hh(45)],
    [_hh(85)], [_hh(45)], [DrumNote(kick, velocity: 100), _hh(70)], [_hh(45)],
    [DrumNote(snare, velocity: 110), _hh(85)], [_hh(45)], [_hh(70)], [DrumNote(snare, velocity: 35), _hh(45)],
  ],
  'Fusion Ballad': [
    // Soft ride on quarters, brush on 2 & 4, light kick on 1
    [DrumNote(kick, velocity: 65), DrumNote(rideCymbal, velocity: 60)], [], [], [],
    [DrumNote(rideCymbal, velocity: 55), DrumNote(brushSnare, velocity: 55)], [], [], [],
    [DrumNote(rideCymbal, velocity: 60)], [], [], [],
    [DrumNote(rideCymbal, velocity: 55), DrumNote(brushSnare, velocity: 55), DrumNote(pedalHiHat, velocity: 50)], [], [], [],
  ],
};

final Map<String, List<List<DrumNote>>> drumPatterns = {
  for (final e in _eighthPatterns.entries) e.key: _x2(e.value),
  ..._sixteenthPatterns,
};

/// One bar of swing time on the 16th grid. Off-beat 8ths sit on step 2 of
/// each beat; the player delays them onto the triplet (see RhythmSection.swing).
List<List<DrumNote>> _swingBar(Random random, {required bool phraseEnd}) {
  final bar = List.generate(16, (_) => <DrumNote>[]);
  for (var beat = 0; beat < 4; beat++) {
    final s = beat * 4;
    final backbeat = beat.isOdd;
    // Ride "ding, ding-a, ding, ding-a" + feathered kick on all four.
    bar[s].add(DrumNote(rideCymbal, velocity: (backbeat ? 92 : 82) + random.nextInt(8)));
    bar[s].add(DrumNote(kick, velocity: 30));
    if (backbeat) {
      bar[s].add(DrumNote(pedalHiHat, velocity: 85)); // hi-hat foot on 2 & 4
      bar[s + 2].add(DrumNote(rideCymbal, velocity: 62 + random.nextInt(8))); // skip note
    }
  }
  // Left-hand comping: 0-2 soft snare hits on swung off-beats.
  final beats = [0, 1, 2, 3]..shuffle(random);
  for (final beat in beats.take(random.nextInt(3))) {
    bar[beat * 4 + 2].add(DrumNote(snare, velocity: 38 + random.nextInt(22)));
  }
  if (phraseEnd) {
    // Set up the next phrase: snare on the & of 3, kick "bomb" on the & of 4.
    bar[10].add(DrumNote(snare, velocity: 80));
    bar[14].add(DrumNote(kick, velocity: 85));
  }
  return bar;
}

List<List<DrumNote>> generateDrumTrack(Song song) {
  final pattern = drumPatterns[song.style];
  if (pattern != null) {
    return List.generate(song.totalSteps, (i) => pattern[i % pattern.length]);
  }
  // Medium Swing (and unknown styles) are generated bar by bar so they breathe.
  final random = Random();
  final track = <List<DrumNote>>[];
  for (var bar = 0; track.length < song.totalSteps; bar++) {
    track.addAll(_swingBar(random, phraseEnd: bar % 8 == 7));
  }
  return track.sublist(0, song.totalSteps);
}
