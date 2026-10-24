import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';

const int kSampleRate = 44100;
const int kBufferSize = 2048; // Samples pro Analyse-Fenster (~46 ms)
const int kFrameBytes = kBufferSize * 2; // PCM16 → 2 Bytes pro Sample

/// Ein Analyse-Ergebnis eines Audio-Fensters.
class PitchSample {
  /// Erkannte Grundfrequenz in Hz, oder null wenn keine Tonhöhe erkannt wurde.
  final double? frequencyHz;

  /// Konfidenz der Tonhöhen-Erkennung, 0..1.
  final double probability;

  /// Lautstärke-Pegel (RMS) des Fensters, 0..1.
  final double level;

  const PitchSample({
    this.frequencyHz,
    required this.probability,
    required this.level,
  });

  bool get hasPitch => frequencyHz != null;
}

/// Nimmt Mikrofon-Audio auf, zerlegt es in Fenster und lässt die Tonhöhe
/// in einem Hintergrund-Isolate bestimmen. Liefert einen Stream von
/// [PitchSample]s für die Live-Anzeige und (später) die Bewertung.
class AudioAnalyzer {
  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<PitchSample> _out =
      StreamController<PitchSample>.broadcast();
  final StreamController<Uint8List> _frames =
      StreamController<Uint8List>.broadcast();
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  StreamSubscription<Uint8List>? _micSub;
  Isolate? _isolate;
  SendPort? _toIsolate;
  ReceivePort? _fromIsolate;
  bool _running = false;

  Stream<PitchSample> get samples => _out.stream;

  /// Rohe PCM16-Fenster (für den PA-Modus: Stimme an den TV streamen).
  Stream<Uint8List> get frames => _frames.stream;

  /// Prüft (und fragt ggf. an) die Mikrofon-Berechtigung.
  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (_running) return;
    _running = true;

    // 1) Hintergrund-Isolate für die Pitch-Detection hochfahren.
    _fromIsolate = ReceivePort();
    final ready = Completer<SendPort>();
    _fromIsolate!.listen((msg) {
      if (msg is SendPort) {
        ready.complete(msg);
      } else if (msg is PitchSample) {
        if (!_out.isClosed) _out.add(msg);
      }
    });
    _isolate = await Isolate.spawn(_pitchWorker, _fromIsolate!.sendPort);
    _toIsolate = await ready.future;

    // 2) Mikrofon-Stream starten. Fehlt ein Aufnahmegerät, sauber aufräumen.
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: kSampleRate,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      _micSub = stream.listen(_onBytes);
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  void _onBytes(Uint8List chunk) {
    _buffer.add(chunk);
    if (_buffer.length < kFrameBytes) return;

    final all = _buffer.takeBytes();
    var offset = 0;
    while (all.length - offset >= kFrameBytes) {
      // Kopie anlegen, damit nur die Fenster-Bytes ins Isolate wandern.
      final frame = Uint8List.fromList(
        Uint8List.sublistView(all, offset, offset + kFrameBytes),
      );
      _toIsolate?.send(frame);
      if (!_frames.isClosed) _frames.add(frame);
      offset += kFrameBytes;
    }
    if (offset < all.length) {
      _buffer.add(Uint8List.sublistView(all, offset));
    }
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    _toIsolate?.send('stop');
    _fromIsolate?.close();
    _fromIsolate = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _buffer.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _out.close();
    await _frames.close();
    await _recorder.dispose();
  }
}

/// Läuft im Hintergrund-Isolate: empfängt PCM16-Fenster und schickt
/// pro Fenster ein [PitchSample] zurück.
Future<void> _pitchWorker(SendPort toMain) async {
  final port = ReceivePort();
  toMain.send(port.sendPort);

  final detector = PitchDetector(
    audioSampleRate: kSampleRate.toDouble(),
    bufferSize: kBufferSize,
  );

  await for (final msg in port) {
    if (msg == 'stop') break;
    if (msg is! Uint8List) continue;
    toMain.send(await _analyzeFrame(detector, msg));
  }
  Isolate.exit();
}

Future<PitchSample> _analyzeFrame(PitchDetector detector, Uint8List frame) async {
  // RMS-Pegel direkt aus den PCM16-Samples.
  final data = ByteData.sublistView(frame);
  final n = frame.length ~/ 2;
  var sumSq = 0.0;
  for (var i = 0; i < n; i++) {
    final s = data.getInt16(i * 2, Endian.little) / 32768.0;
    sumSq += s * s;
  }
  final rms = n == 0 ? 0.0 : sqrt(sumSq / n);

  final result = await detector.getPitchFromIntBuffer(frame);
  final hasPitch = result.pitched && result.pitch > 0;

  return PitchSample(
    frequencyHz: hasPitch ? result.pitch : null,
    probability: result.probability,
    level: rms.clamp(0.0, 1.0),
  );
}
