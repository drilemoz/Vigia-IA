import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_litert/native.dart' hide Detection;
import 'detector_input_buffer.dart';
import 'detector_runtime_policy.dart';
import 'yolo_detection_decoder.dart';
import '../models/detection.dart';
import '../models/rgb_frame.dart';
import '../models/video_source_config.dart';
import 'label_translator.dart';
import 'error_log_service.dart';
part 'object_detection_assets.dart';
part 'object_detection_worker.dart';
part 'object_detection_runtime.dart';
part 'object_detection_metrics.dart';
part 'object_detection_messages.dart';
class ObjectDetectionService {
  ObjectDetectionService({this.preference = DetectorModelPreference.automatic});
  final DetectorModelPreference preference;

  static const _yoloModelAsset = 'assets/models/yolo26s.tflite';
  static const _lite2ModelAsset = 'assets/models/efficientdet_lite2.tflite';
  static const _primaryModelAsset = 'assets/models/efficientdet_lite0.tflite';
  static const _fallbackModelAsset = 'assets/models/ssd_mobilenet_v1.tflite';
  static const _yoloLabelsAsset = 'assets/models/yolo_coco80.txt';
  static const _labelsAsset = 'assets/models/labelmap.txt';

  Isolate? _worker;
  ReceivePort? _responses;
  SendPort? _commands;
  StreamSubscription<dynamic>? _responseSubscription;
  Completer<void>? _ready;
  Completer<void>? _workerDone;
  final Map<int, _PendingDetection> _pending = <int, _PendingDetection>{};
  int _nextRequestId = 0;
  bool _disposed = false;
  String? _diagnostics;

  bool get isReady => _commands != null && !_disposed;
  String? get diagnostics => _diagnostics;

  Future<void> initialize() async {
    if (isReady) return;
    if (_disposed) throw StateError('Detector ja descartado.');

    final models = await _loadDetectorAssets(preference);
    if (models.isEmpty) {
      throw StateError(
        'Modelos TensorFlow Lite ausentes. Execute tool/fetch_model.sh antes de compilar.',
      );
    }

    final labelsRaw = await rootBundle.loadString(_labelsAsset);
    final labels = labelsRaw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final yoloLabels = (await rootBundle.loadString(_yoloLabelsAsset))
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (yoloLabels.length != 80) {
      throw StateError('YOLO26 exige 80 rótulos COCO em ordem.');
    }

    final responses = ReceivePort();
    final ready = Completer<void>();
    final workerDone = Completer<void>();
    _responses = responses;
    _ready = ready;
    _workerDone = workerDone;
    _responseSubscription = responses.listen(_handleWorkerMessage);

    _worker = await Isolate.spawn<Map<String, Object>>(
      _detectorWorkerMain,
      <String, Object>{
        'replyPort': responses.sendPort,
        'models': models,
        'labels': labels,
        'yoloLabels': yoloLabels,
      },
      debugName: 'object-detector-worker',
      onError: responses.sendPort,
      errorsAreFatal: true,
    );

    try {
      await ready.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      await dispose();
      rethrow;
    }
  }

  Future<List<Detection>> detect(
    RgbFrame frame, {
    required double threshold,
    required int maxResults,
    Set<String>? allowedLabels,
  }) async =>
      (await detectMeasured(
        frame,
        threshold: threshold,
        maxResults: maxResults,
        allowedLabels: allowedLabels,
      ))
          .detections;

  Future<DetectionRunResult> detectMeasured(
    RgbFrame frame, {
    required double threshold,
    required int maxResults,
    Set<String>? allowedLabels,
  }) async {
    final commands = _commands;
    if (commands == null || _disposed) {
      throw StateError('Detector nao inicializado.');
    }

    final id = _nextRequestId++;
    final pending = _PendingDetection();
    _pending[id] = pending;
    final request = <String, Object>{
      'type': 'detect',
      'id': id,
      'width': frame.width,
      'height': frame.height,
      'bytes': TransferableTypedData.fromList([frame.rgbBytes]),
      'threshold': threshold,
      'maxResults': maxResults,
    };
    if (allowedLabels != null) {
      request['allowedLabels'] = allowedLabels.toList(growable: false);
    }
    commands.send(request);
    return pending.completer.future;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final commands = _commands;
    final worker = _worker;
    final workerDone = _workerDone;
    commands?.send(const <String, Object>{'type': 'dispose'});
    _commands = null;

    for (final pending in _pending.values) {
      pending.watch.stop();
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(StateError('Detector encerrado.'));
      }
    }
    _pending.clear();

    if (workerDone != null && !workerDone.isCompleted && commands != null) {
      try {
        await workerDone.future.timeout(const Duration(seconds: 2));
      } catch (_) {
        worker?.kill(priority: Isolate.immediate);
      }
    } else {
      worker?.kill(priority: Isolate.immediate);
    }

    await _responseSubscription?.cancel();
    _responseSubscription = null;
    _responses?.close();
    _responses = null;
    _worker = null;
    _workerDone = null;
  }
}
