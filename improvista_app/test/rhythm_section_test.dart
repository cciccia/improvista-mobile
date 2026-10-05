import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:improvista_app/services/chord_parser.dart';
import 'package:improvista_app/services/drum_patterns.dart';
import 'package:improvista_app/services/music_generator.dart';
import 'package:improvista_app/utils/chord_utils.dart';
import 'package:tonic/tonic.dart' as tonic;

void main() {
  test('default duration rules', () {
    final song = parseChordPro('| [C] | [Dm7] [G7] | [A] [B] [C] | [D] [E] [F] [G] |');
    expect(song.chords.map((c) => c.duration), [4, 2, 2, 2, 1, 1, 1, 1, 1, 1]);
    expect(song.totalSteps, 4 * 4 * 4);
  });

  test('directives and explicit durations', () {
    final song = parseChordPro('{tempo: 86}{style: Fusion Ballad}{transpose: Eb}\n| [Dm7:0.5] [G7:0.5] [Cmaj7:3] | [F] [G:1] |');
    expect(song.tempo, 86);
    expect(song.style, 'Fusion Ballad');
    expect(song.transpose, -9);
    expect(song.chords.map((c) => c.name), ['Dm7', 'G7', 'Cmaj7', 'F', 'G']);
    expect(song.chords.map((c) => c.duration), [0.5, 0.5, 3, 3, 1]);
  });

  test('every track is exactly totalSteps long for every style', () {
    const chart = '| [Dm7:0.5] [G7:0.5] [Cmaj7:3] | [Am7] [D7] | [Gmaj7] | [C/E] [F] [G] |';
    for (final style in ['Medium Swing', 'Bossa Nova', 'Ballad', 'Rock Ballad', 'Fusion', 'Fusion Ballad']) {
      final song = parseChordPro('{style: $style}\n$chart');
      final rs = generateRhythmSection(song);
      expect([rs.bass.length, rs.piano.length, rs.drums.length], everyElement(rs.totalSteps), reason: style);
      expect(rs.totalSteps, 16 * 4, reason: style);
    }
  });

  test('every chord in the bundled songs is understood by tonic', () {
    for (final file in Directory('assets/songs').listSync().whereType<File>()) {
      for (final chord in parseChordPro(file.readAsStringSync()).chords) {
        expect(() => tonic.Chord.parse(normalizeChordName(chord.name)), returnsNormally,
            reason: '${file.path}: ${chord.name}');
      }
    }
  });

  test('medium swing is swung jazz time, not a rock backbeat', () {
    final song = parseChordPro('${'| [Dm7] | [G7] | [Cmaj7] | [Cmaj7] |' * 4}');
    final rs = generateRhythmSection(song);
    expect(rs.swing, isTrue);
    for (var bar = 0; bar < 16; bar++) {
      final steps = rs.drums.sublist(bar * 16, bar * 16 + 16);
      notes(int step) => steps[step].map((n) => n.midi);
      for (final beat in [0, 4, 8, 12]) {
        expect(notes(beat), contains(rideCymbal), reason: 'ride on every beat');
        expect(notes(beat), isNot(contains(snare)), reason: 'no snare on the beat');
      }
      expect(notes(4), contains(pedalHiHat));
      expect(notes(12), contains(pedalHiHat));
      expect(notes(6), contains(rideCymbal), reason: 'skip note on & of 2');
      expect(notes(14), contains(rideCymbal), reason: 'skip note on & of 4');
    }
    expect(generateRhythmSection(parseChordPro('{style: Bossa Nova}\n| [C] |')).swing, isFalse);
  });
}
