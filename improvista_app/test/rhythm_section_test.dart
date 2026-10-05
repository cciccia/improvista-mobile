import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:improvista_app/services/chord_parser.dart';
import 'package:improvista_app/services/drum_patterns.dart';
import 'package:improvista_app/services/music_generator.dart';
import 'package:improvista_app/services/piano_patterns.dart';
import 'package:improvista_app/utils/chord_utils.dart';

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

  test('repeats and endings unroll in playing order', () {
    List<String> play(String chart) => parseChordPro(chart).chords.map((c) => c.name).toList();
    expect(play('|: [A] | [B] :| [C] |'), ['A', 'B', 'A', 'B', 'C']);
    expect(play('[A] | [B] :| [C]'), ['A', 'B', 'A', 'B', 'C'], reason: 'no |: repeats from the top');
    expect(play('|: [A] | [B] |1 [C] :|2 [D] |'), ['A', 'B', 'C', 'A', 'B', 'D']);
    expect(play('|: [A] |1 [B] | [C] :|2 [D] | [E] |'), ['A', 'B', 'C', 'A', 'D', 'E'], reason: 'multi-bar 1st ending');
    expect(play('|: [A] :| x3 [B] |'), ['A', 'A', 'A', 'B']);
    expect(play('|: [A] :| (4x) [B] |'), ['A', 'A', 'A', 'A', 'B']);
    expect(play('|: [A] |1 [B] :| 3x |2 [C] |'), ['A', 'B', 'A', 'B', 'A', 'C'], reason: '1st ending on every pass but the last');
    expect(play('[X] |: [A] :|: [B] :| [C] ||'), ['X', 'A', 'A', 'B', 'B', 'C']);
    expect(play('| [Dm7:0.5] [G7:0.5] [Cmaj7:3] :|').length, 6, reason: 'durations keep their colons');
  });

  test('Body and Soul unrolls to 32 bars', () {
    final song = parseChordPro(File('assets/songs/bodyandsoul.txt').readAsStringSync());
    expect(song.chords.fold<double>(0, (sum, c) => sum + c.duration), 32 * 4);
    expect(song.chords[14].name, 'Db6');
    expect(song.chords.sublist(14, 16).map((c) => c.name), ['Db6', 'Bb7b9'], reason: '1st ending');
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

  test('every chord in the bundled songs is in the chord table', () {
    for (final file in Directory('assets/songs').listSync().whereType<File>()) {
      for (final chord in parseChordPro(file.readAsStringSync()).chords) {
        expect(parseChord(chord.name).exact, isTrue, reason: '${file.path}: ${chord.name}');
      }
    }
  });

  test('chart spellings resolve to the same quality', () {
    String key(String name) => parseChord(name).qualityKey;
    expect(key('FΔ7+5'), 'maj7#5');
    expect(key('FΔ7sus4'), 'maj7sus4');
    expect(key('AΔ7♯11'), 'maj7#11');
    expect(key('FMaj6'), '6');
    expect(key('FΔ'), 'maj7');
    expect(key('CM7'), 'maj7');
    expect(key('C-7'), 'm7');
    expect(key('Bbø'), 'm7b5');
    expect(key('Co7'), 'dim7');
    expect(key('C7(b9)'), '7b9');
    expect(key('C7+'), '7#5');
    expect(key('C6/9'), '69');
    expect(key('Cm(maj7)'), 'mmaj7');
    expect(key('Cmadd9'), 'madd9');
    expect(parseChord('Gm11/F').bassPc, 5);
    expect(parseChord('Bb').rootPc, 10);
  });

  test('unknown qualities fall back to the longest known prefix', () {
    final chord = parseChord('C7b9#13');
    expect([chord.qualityKey, chord.exact], ['7b9', false]);
    expect(() => parseChord('H7'), throwsFormatException);
  });

  // Pitch classes the piano plays on the first comp hit of a one-chord song.
  Set<int> voicing(String chord, {String style = 'Medium Swing'}) {
    final piano = generatePianoTrack(parseChordPro('{style: $style}\n| [$chord] |'));
    return piano.firstWhere((s) => s.isNotEmpty).map((n) => n % 12).toSet();
  }

  test('piano voicings keep the alterations', () {
    expect(voicing('FΔ7+5'), {9, 1, 4, 7}); // A C# E G
    expect(voicing('AΔ7#11'), {1, 8, 11, 3}); // C# G# B D#
    expect(voicing('FΔ7sus4'), {10, 4, 7, 0}); // Bb E G C
    expect(voicing('C7alt'), {4, 10, 3, 8}); // E Bb D# Ab
    expect(voicing('Gm11/F'), {10, 5, 9, 0}); // Bb F A C over F in the bass
    expect(voicing('C7alt', style: 'Ballad'), {4, 10, 3, 8, 1, 6}); // + Db F#
  });

  test('bass plays the altered fifth and the slash note', () {
    final song = parseChordPro('{style: Bossa Nova}\n| [Fmaj7#5] |');
    final fifths = generateRhythmSection(song).bass.where((n) => n > 0).map((n) => n % 12);
    expect(fifths, isNot(contains(0)), reason: 'no natural C under F+');
    expect(generateRhythmSection(parseChordPro('| [Gm11/F] |')).bass.first % 12, 5);
  });

  test('no minor 9ths between voices unless the chord asks for one', () {
    const chart = '| [Cm7] | [F7] | [Bbmaj7] | [Ebm11] | [Dbmaj7#11] | [Gm7b5] | [Fm6] | [Bb13sus] | [Cmaj7#5] |';
    for (final style in ['Medium Swing', 'Ballad']) {
      for (final transpose in ['C', 'Bb', 'Eb']) {
        final piano = generatePianoTrack(parseChordPro('{style: $style}{transpose: $transpose}\n${chart * 4}'));
        for (final notes in piano.where((s) => s.isNotEmpty)) {
          for (final a in notes) {
            for (final b in notes) {
              expect(b - a > 12 && (b - a) % 12 == 1, isFalse, reason: '$style $transpose $notes');
            }
          }
        }
      }
    }
  });

  test('voicings stay in the comping register', () {
    const chart = '| [Cmaj7] | [Ebm11] | [Ab7alt] | [Dbmaj7#11] | [Gm7b5] | [C7b9] | [Fm6] | [Bb13sus] |';
    for (final style in ['Medium Swing', 'Ballad']) {
      for (final transpose in ['C', 'Bb', 'Eb']) {
        final piano = generatePianoTrack(parseChordPro('{style: $style}{transpose: $transpose}\n${chart * 8}'));
        for (final notes in piano.where((s) => s.isNotEmpty)) {
          expect(notes.reduce((a, b) => a < b ? a : b), inInclusiveRange(pianoLowestNote, pianoLowestNote + 11),
              reason: '$style $transpose $notes');
        }
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
