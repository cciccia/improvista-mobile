// lib/models/song.dart
import 'chord.dart';

class Song {
  final String? title;
  final String? artist;
  final String? style;
  final double tempo; // BPM
  final String timeSignature;
  final int transpose; // Semitones to transpose (negative = down)
  final List<Chord> chords;

  Song({
    this.title,
    this.artist,
    this.style,
    this.tempo = 120.0,
    this.timeSignature = '4/4',
    this.transpose = 0,
    required this.chords,
  });

  /// Total length in 16th-note steps. Every track must be exactly this long.
  int get totalSteps => chords.fold(0, (sum, chord) => sum + chord.steps);

  int get beatsPerMeasure => int.tryParse(timeSignature.split('/').first) ?? 4;
  int get beatUnit => int.tryParse(timeSignature.split('/').last) ?? 4;
}
