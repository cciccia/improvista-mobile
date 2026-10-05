// lib/services/music_generator.dart
import 'piano_patterns.dart';
import '../models/rhythm_section.dart';
import '../models/song.dart';
import 'drum_patterns.dart';
import 'bass_patterns.dart';

const _straightStyles = {'Bossa Nova', 'Rock Ballad', 'Fusion', 'Fusion Ballad'};

RhythmSection generateRhythmSection(Song song) {
  final bass = generateBassLine(song);
  final drums = generateDrumTrack(song);
  final piano = generatePianoTrack(song);

  final totalSteps = song.totalSteps;

  return RhythmSection(
    bass: bass,
    drums: drums,
    piano: piano,
    totalSteps: totalSteps,
    swing: !_straightStyles.contains(song.style),
  );
}
