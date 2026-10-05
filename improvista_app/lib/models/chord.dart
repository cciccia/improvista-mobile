/// All tracks use 16th-note resolution.
const int stepsPerBeat = 4;

class Chord {
  final String name;
  final double duration; // In beats, e.g., 4.0 for a full measure

  Chord({required this.name, this.duration = 4.0});

  /// Number of 16th-note steps this chord occupies.
  int get steps => (duration * stepsPerBeat).round();

  @override
  String toString() {
    return 'Chord(name: $name, duration: $duration)';
  }
}
