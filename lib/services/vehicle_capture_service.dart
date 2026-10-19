import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/detection.dart';
import '../models/monitor_event.dart';
import '../models/object_filter_catalog.dart';
import '../models/rgb_frame.dart';
import '../models/storage_policy.dart';
import 'error_log_service.dart';
import 'event_history_service.dart';

/// Mantém um histórico de posições recentes por câmera. Não compara placas,
/// portanto é uma proteção contra duplicatas aproximada, não identificação
/// exclusiva do mesmo veículo.
class VehicleCaptureGuard {
  static const Duration minimumBetweenPhotos = Duration(seconds: 8);
  static const Duration repeatSameRegion = Duration(seconds: 60);
  final Map<String, List<_VehicleObservation>> _recent = {};
  final Map<String, DateTime> _lastPhotoByCamera = {};

  Detection? observe({
    required String cameraId,
    required DateTime now,
    required List<Detection> detections,
    required bool cameraMoving,
    double confidenceThreshold = 0.65,
  }) {
    if (cameraMoving) {
      _recent.remove(cameraId);
      return null;
    }
    final observations = _recent.putIfAbsent(cameraId, () => []);
    observations.removeWhere((item) =>
        now.difference(item.lastSeen) > const Duration(seconds: 120));

    Detection? chosen;
    final candidates = detections
        .where((detection) =>
            ObjectFilterCatalog.automobiles.contains(detection.label) &&
            !detection.inferred &&
            detection.confidence >= confidenceThreshold &&
            detection.box.xMax > detection.box.xMin &&
            detection.box.yMax > detection.box.yMin)
        .toList(growable: false)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    for (final candidate in candidates) {
      final centerX = (candidate.box.xMin + candidate.box.xMax) / 2;
      final centerY = (candidate.box.yMin + candidate.box.yMax) / 2;
      _VehicleObservation? match;
      for (final item in observations) {
        if (item.label != candidate.label) continue;
        final dx = (item.centerX - centerX).abs();
        final dy = (item.centerY - centerY).abs();
        if (dx <= 0.15 && dy <= 0.15) {
          match = item;
          break;
        }
      }
      if (match == null) {
        observations.add(_VehicleObservation(
          label: candidate.label,
          centerX: centerX,
          centerY: centerY,
          lastSeen: now,
        ));
        continue;
      }
      final elapsed = now.difference(match.lastSeen);
      match.hits = elapsed >= Duration.zero &&
              elapsed <= const Duration(seconds: 5)
          ? (match.hits + 1).clamp(1, 4).toInt()
          : 1;
      match.lastSeen = now;
      match.centerX = centerX;
      match.centerY = centerY;
      if (match.hits < 2 || chosen != null) {
        continue;
      }
      if (match.lastSaved != null &&
          now.difference(match.lastSaved!) < repeatSameRegion) {
        continue;
      }
      final lastCameraPhoto = _lastPhotoByCamera[cameraId];
      if (lastCameraPhoto != null &&
          now.difference(lastCameraPhoto) < minimumBetweenPhotos) continue;
      chosen = candidate;
      match.lastSaved = now;
      _lastPhotoByCamera[cameraId] = now;
    }
    return chosen;
  }

  void reset() {
    _recent.clear();
    _lastPhotoByCamera.clear();
  }
}

class _VehicleObservation {
  _VehicleObservation({
    required this.label,
    required this.centerX,
    required this.centerY,
    required this.lastSeen,
  });
  final String label;
  double centerX;
  double centerY;
  DateTime lastSeen;
  int hits = 1;
  DateTime? lastSaved;
}

class VehicleCaptureService {
  VehicleCaptureService._();

  static final VehicleCaptureService instance = VehicleCaptureService._();
  final VehicleCaptureGuard _guard = VehicleCaptureGuard();
  final EventHistoryService _history = EventHistoryService.instance;
  bool _enabled = false; // Consentimento explícito no Histórico.
  bool _busy = false;
  Future<void>? _loading;
  File? _settingsFile;

  bool get enabled => _enabled;

  Future<void> initialize() => _loading ??= _initialize();

  Future<void> _initialize() async {
    try {
      final root = await getApplicationSupportDirectory();
      final file = File('${root.path}${Platform.pathSeparator}vehicle_capture.json');
      _settingsFile = file;
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) _enabled = decoded['enabled'] == true;
      }
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordException(
        source: 'Captura de veículos',
        error: error,
        stackTrace: stackTrace,
        message: 'Não foi possível carregar a preferência de fotos automáticas.',
        level: ErrorLogLevel.warning,
      );
    }
  }

  Future<void> setEnabled(bool enabled) async {
    await initialize();
    final file = _settingsFile;
    if (file == null) {
      throw StateError('Não foi possível salvar a opção de fotografar veículos.');
    }
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode({'enabled': enabled}), flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
    _enabled = enabled;
    _guard.reset();
  }

  bool hasRecentPhoto(String cameraId, String label) => _history.events.any(
        (event) =>
            event.type == MonitorEventType.vehicleSnapshot &&
            event.cameraId == cameraId &&
            event.label == label &&
            DateTime.now().difference(event.createdAt) <
                const Duration(seconds: 10),
      );

  Future<void> observe({
    required RgbFrame frame,
    required List<Detection> detections,
    required String cameraId,
    required String source,
    required bool cameraMoving,
    required double confidenceThreshold,
    required StoragePolicy storagePolicy,
  }) async {
    if (!_enabled || _busy) return;
    final candidate = _guard.observe(
      cameraId: cameraId,
      now: frame.capturedAt,
      detections: detections,
      cameraMoving: cameraMoving,
      confidenceThreshold: confidenceThreshold,
    );
    if (candidate == null) return;
    _busy = true;
    try {
      // Somente fotos locais. Sem OCR, internet ou notificações nesta etapa.
      final saved = await _history.addEvent(
        detection: candidate,
        frame: frame,
        source: source,
        type: MonitorEventType.vehicleSnapshot,
        cameraId: cameraId,
        requireSnapshot: true,
      );
      if (saved != null && storagePolicy.autoCleanup) {
        await _history.applyStoragePolicy(storagePolicy);
      }
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordException(
        source: 'Captura de veículos',
        error: error,
        stackTrace: stackTrace,
        message: 'Não foi possível registrar a foto do veículo.',
        level: ErrorLogLevel.warning,
      );
    } finally {
      _busy = false;
    }
  }
}
