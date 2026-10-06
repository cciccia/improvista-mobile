// lib/views/home_page.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/song.dart';
import '../services/chord_parser.dart';
import '../services/music_generator.dart';
import '../services/audio_player.dart';
import '../models/rhythm_section.dart';

// Sample songs bundled with the app
const List<Map<String, String>> sampleSongs = [
  {'name': 'Airegin', 'path': 'assets/songs/airegin.txt'},
  {'name': 'Blue Bossa', 'path': 'assets/songs/bluebossa.txt'},
  {'name': 'Body and Soul', 'path': 'assets/songs/bodyandsoul.txt'},
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _chartScrollController = ScrollController();
  String _statusMessage = "Load a ChordPro file to begin.";
  bool _isPlayerInitialized = false;
  bool _isPlaying = false;
  bool _isRepeatEnabled = false;
  bool _isCountInEnabled = true;
  Song? _loadedSong; // what plays: the whole song or one section of it
  Song? _fullSong;
  SongSection? _section;
  double _tempo = 120.0;
  int? _currentChordIndex;

  @override
  void initState() {
    super.initState();
    _audioPlayer.initialize().then((_) {
      setState(() { _isPlayerInitialized = true; });
    });
  }

  @override
  void dispose() {
    _chartScrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _stopPlayback() {
    _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _currentChordIndex = null;
      _statusMessage = _loadedSong != null
          ? "'${_loadedSong!.title}' loaded. Press Play to start."
          : "Playback stopped.";
    });
  }

  int? _getChordIndexAtStep(int step) {
    if (_loadedSong == null) return null;
    const int stepsPerBeat = 4; // 16th-note resolution
    double beatPosition = step / stepsPerBeat;
    double accumulatedBeats = 0;
    for (int i = 0; i < _loadedSong!.chords.length; i++) {
      accumulatedBeats += _loadedSong!.chords[i].duration;
      if (beatPosition < accumulatedBeats) {
        return i;
      }
    }
    return _loadedSong!.chords.isNotEmpty ? _loadedSong!.chords.length - 1 : null;
  }

  /// Groups chords into measures based on the time signature.
  List<List<int>> _getMeasures() {
    if (_loadedSong == null) return [];
    final beatsPerMeasure = _loadedSong!.beatsPerMeasure.toDouble();
    final List<List<int>> measures = [];
    List<int> currentMeasure = [];
    double beatsInCurrentMeasure = 0;

    for (int i = 0; i < _loadedSong!.chords.length; i++) {
      final chord = _loadedSong!.chords[i];
      currentMeasure.add(i);
      beatsInCurrentMeasure += chord.duration;
      if (beatsInCurrentMeasure >= beatsPerMeasure - 0.001) {
        measures.add(currentMeasure);
        currentMeasure = [];
        beatsInCurrentMeasure = 0;
      }
    }
    if (currentMeasure.isNotEmpty) {
      measures.add(currentMeasure);
    }
    return measures;
  }

  void _loadSongFromContent(String content) {
    setState(() { _statusMessage = "Parsing file..."; });
    final Song song = parseChordPro(content);
    setState(() {
      _fullSong = song;
      _section = null;
      _loadedSong = song;
      _tempo = song.tempo;
      _statusMessage = "'${song.title}' loaded. Press Play to start.";
    });
  }

  void _selectSection(SongSection? section) {
    setState(() {
      _section = section;
      _loadedSong = section == null ? _fullSong : _fullSong!.section(section);
      _currentChordIndex = null;
    });
  }

  Widget _buildSectionChips() {
    ChoiceChip chip(String label, SongSection? section) => ChoiceChip(
          label: Text(label),
          selected: _section == section,
          onSelected: _isPlaying ? null : (_) => _selectSection(section),
        );
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        chip('Whole chart', null),
        ..._fullSong!.sections.map((s) => chip(s.name, s)),
      ],
    );
  }

  void _playLoadedSong() {
    if (!_isPlayerInitialized || _isPlaying || _loadedSong == null) return;

    setState(() { _statusMessage = "Generating rhythm section..."; });
    final RhythmSection rhythmSection = generateRhythmSection(_loadedSong!);

    final countInBars = _isCountInEnabled ? 2 : 0;

    setState(() {
      _isPlaying = true;
      _statusMessage = countInBars > 0
          ? "Count in..."
          : "Playing '${_loadedSong!.title}' at ${_tempo.toInt()} BPM...";
    });

    _audioPlayer.playRhythmSection(
      rhythmSection,
      tempo: _tempo,
      repeat: _isRepeatEnabled,
      countInBars: countInBars,
      beatsPerBar: _loadedSong!.beatsPerMeasure,
      onCountInBeat: (beat, totalBeats) {
        setState(() {
          _statusMessage = "Count in... ${beat + 1}";
        });
      },
      onStepChange: (step) {
        if (_statusMessage.startsWith("Count in")) {
          setState(() {
            _statusMessage = "Playing '${_loadedSong!.title}' at ${_tempo.toInt()} BPM...";
          });
        }
        final index = _getChordIndexAtStep(step);
        if (index != _currentChordIndex) {
          setState(() { _currentChordIndex = index; });
        }
      },
      onFinished: () {
        setState(() {
          _isPlaying = false;
          _currentChordIndex = null;
          _statusMessage = "Playback finished. Press Play to restart.";
        });
      },
    );
  }

  Future<void> _loadSampleSong(String assetPath) async {
    final content = await rootBundle.loadString(assetPath);
    _loadSongFromContent(content);
  }

  Future<void> _pickFile() async {
    if (!_isPlayerInitialized) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cho', 'txt'],
    );

    if (result != null) {
      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      _loadSongFromContent(content);
    }
  }

  Future<void> _pasteChordPro() async {
    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste ChordPro'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              hintText: 'Paste your ChordPro content here...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Load'),
          ),
        ],
      ),
    );

    if (content != null && content.isNotEmpty) {
      _loadSongFromContent(content);
    }
  }

  void _scrollToCurrentMeasure(List<List<int>> measures) {
    if (_currentChordIndex == null || !_chartScrollController.hasClients) return;
    // Find which row the current chord is in (4 measures per row)
    int measureIndex = 0;
    for (int i = 0; i < measures.length; i++) {
      if (measures[i].contains(_currentChordIndex)) {
        measureIndex = i;
        break;
      }
    }
    const int measuresPerRow = 4;
    final int row = measureIndex ~/ measuresPerRow;
    const double rowHeight = 62.0;
    final double rowTop = row * rowHeight;
    final double rowBottom = rowTop + rowHeight;

    final double viewportTop = _chartScrollController.offset;
    final double viewportHeight = _chartScrollController.position.viewportDimension;
    final double viewportBottom = viewportTop + viewportHeight;

    // Only scroll if the active row is outside the visible area
    double? targetOffset;
    if (rowBottom > viewportBottom) {
      // Row is below the visible area - scroll down so it's at the bottom
      targetOffset = rowBottom - viewportHeight;
    } else if (rowTop < viewportTop) {
      // Row is above the visible area - scroll up so it's at the top
      targetOffset = rowTop;
    }

    if (targetOffset != null) {
      final double maxScroll = _chartScrollController.position.maxScrollExtent;
      _chartScrollController.animateTo(
        targetOffset.clamp(0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildChordChart() {
    final measures = _getMeasures();
    final chords = _loadedSong!.chords;

    // Auto-scroll when chord changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentMeasure(measures);
    });

    const int measuresPerRow = 4;
    final List<Widget> rows = [];

    for (int i = 0; i < measures.length; i += measuresPerRow) {
      final rowMeasures = measures.sublist(
        i,
        (i + measuresPerRow).clamp(0, measures.length),
      );
      rows.add(
        Row(
          children: [
            // Measure number label
            SizedBox(
              width: 28,
              child: Text(
                '${i + 1}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 4),
            // Measure cells
            ...rowMeasures.map((measureChordIndices) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[700]!, width: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: measureChordIndices.map((chordIdx) {
                      final isActive = _currentChordIndex == chordIdx;
                      return Expanded(
                        child: Container(
                          decoration: isActive
                              ? BoxDecoration(
                                  color: Colors.blue[700],
                                  borderRadius: BorderRadius.circular(4),
                                )
                              : null,
                          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                          child: Text(
                            chords[chordIdx].name,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive ? Colors.white : Colors.grey[300],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            }),
            // Pad remaining cells if row is incomplete
            ...List.generate(
              measuresPerRow - rowMeasures.length,
              (_) => const Expanded(child: SizedBox()),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 250),
        child: ListView(
          controller: _chartScrollController,
          children: rows,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        title: const Text("Improvista"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            // Sample songs section
            const Text('Sample Songs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: sampleSongs.map((song) => ElevatedButton(
                onPressed: (_isPlayerInitialized && !_isPlaying)
                    ? () => _loadSampleSong(song['path']!)
                    : null,
                child: Text(song['name']!),
              )).toList(),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            // File picker and paste buttons
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Load from File'),
                  onPressed: _isPlayerInitialized ? _pickFile : null,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.paste),
                  label: const Text('Paste ChordPro'),
                  onPressed: _isPlayerInitialized ? _pasteChordPro : null,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Song controls (only shown when a song is loaded)
            if (_loadedSong != null) ...[
              if (_fullSong!.sections.isNotEmpty) ...[
                _buildSectionChips(),
                const SizedBox(height: 8),
              ],
              // Chord chart
              _buildChordChart(),
              const SizedBox(height: 16),
              // Current chord - large display
              if (_currentChordIndex != null)
                Text(
                  _loadedSong!.chords[_currentChordIndex!].name,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[300],
                  ),
                ),
              const SizedBox(height: 8),
              Text('Tempo: ${_tempo.toInt()} BPM', style: const TextStyle(fontSize: 16)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Slider(
                  value: _tempo,
                  min: 40,
                  max: 300,
                  divisions: 260,
                  label: '${_tempo.toInt()} BPM',
                  onChanged: _isPlaying ? null : (value) {
                    setState(() { _tempo = value; });
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Play, Stop, and Repeat buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                    onPressed: (_isPlayerInitialized && !_isPlaying) ? _playLoadedSong : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    onPressed: _isPlaying ? _stopPlayback : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(
                      Icons.repeat,
                      color: _isRepeatEnabled ? Colors.blue : Colors.grey,
                    ),
                    tooltip: _isRepeatEnabled ? 'Repeat: On' : 'Repeat: Off',
                    onPressed: () {
                      setState(() { _isRepeatEnabled = !_isRepeatEnabled; });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.timer,
                      color: _isCountInEnabled ? Colors.blue : Colors.grey,
                    ),
                    tooltip: _isCountInEnabled ? 'Count-in: On' : 'Count-in: Off',
                    onPressed: _isPlaying ? null : () {
                      setState(() { _isCountInEnabled = !_isCountInEnabled; });
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(_statusMessage),
            if (!_isPlayerInitialized)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}