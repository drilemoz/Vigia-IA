part of 'object_detection_service.dart';

extension _DetectionMessages on ObjectDetectionService {
  void _handleWorkerMessage(dynamic rawMessage) {
    if (rawMessage is List && rawMessage.length == 2 && !_disposed) {
      final error = StateError('Worker de IA encerrou com erro: ${rawMessage[0]}');
      final stack = StackTrace.fromString(rawMessage[1]?.toString() ?? '');
      unawaited(ErrorLogService.instance.recordException(source: 'Isolate de IA',
          error: error, stackTrace: stack, context: const {'nãoTratado': true}));
      _commands = null;
      final ready = _ready;
      if (ready != null && !ready.isCompleted) ready.completeError(error, stack);
      for (final pending in _pending.values) {
        pending.watch.stop();
        if (!pending.completer.isCompleted) pending.completer.completeError(error, stack);
      }
      _pending.clear();
      final done = _workerDone;
      if (done != null && !done.isCompleted) done.complete();
      return;
    }
    if (rawMessage is! Map<Object?, Object?>) return;
    final message = rawMessage;
    final type = message['type'];

    if (type == 'ready') {
      final port = message['port'];
      if (port is! SendPort) {
        _ready?.completeError(
          StateError('Worker de deteccao retornou uma porta invalida.'),
        );
        return;
      }
      _commands = port;
      _diagnostics = message['diagnostics']?.toString();
      final ready = _ready;
      if (ready != null && !ready.isCompleted) ready.complete();
      return;
    }

    if (type == 'initError') {
      final ready = _ready;
      if (ready != null && !ready.isCompleted) {
        ready.completeError(StateError('${message['error']}'));
      }
      return;
    }

    if (type == 'disposed') {
      final done = _workerDone;
      if (done != null && !done.isCompleted) done.complete();
      return;
    }

    if (message['diagnostics'] is String) {
      _diagnostics = message['diagnostics']! as String;
    }
    final id = message['id'];
    if (id is! int) return;
    final pending = _pending.remove(id);
    if (pending == null || pending.completer.isCompleted) return;
    pending.watch.stop();

    if (type == 'error') {
      pending.completer.completeError(StateError('${message['error']}'));
      return;
    }

    if (type != 'result') {
      pending.completer.completeError(StateError('Resposta desconhecida do detector.'));
      return;
    }

    try {
      final rawResults = message['results'];
      if (rawResults is! List<Object?>) {
        throw StateError('Resultados invalidos recebidos do detector.');
      }
      final detections = <Detection>[];
      for (final rawRow in rawResults) {
        if (rawRow is! List<Object?> || rawRow.length < 6) continue;
        final label = rawRow[0]! as String;
        detections.add(
          Detection(
            label: label,
            displayLabel: LabelTranslator.ptBr(label),
            confidence: (rawRow[1]! as num).toDouble(),
            box: NormalizedBox(
              yMin: (rawRow[2]! as num).toDouble(),
              xMin: (rawRow[3]! as num).toDouble(),
              yMax: (rawRow[4]! as num).toDouble(),
              xMax: (rawRow[5]! as num).toDouble(),
            ),
          ),
        );
      }
      final rawTimings = message['timings'];
      final timingsMap = rawTimings is Map<Object?, Object?>
          ? rawTimings
          : const <Object?, Object?>{};
      double timing(String key) => (timingsMap[key] as num?)?.toDouble() ?? 0.0;
      final workerTotalMs = timing('workerTotalMs');
      final roundTripMs = pending.watch.elapsedMicroseconds / 1000.0;
      pending.completer.complete(
        DetectionRunResult(
          detections: List<Detection>.unmodifiable(detections),
          timings: DetectorStageTimings(
            roundTripMs: roundTripMs,
            isolateTransferAndQueueMs:
                math.max(0.0, roundTripMs - workerTotalMs),
            workerMaterializeMs: timing('workerMaterializeMs'),
            imageBuildMs: timing('imageBuildMs'),
            resizeLetterboxMs: timing('resizeLetterboxMs'),
            tensorBuildMs: timing('tensorBuildMs'),
            liteRtMs: timing('liteRtMs'),
            tensorTransferMs: timing('tensorTransferMs'),
            detectorPostprocessMs: timing('detectorPostprocessMs'),
            workerTotalMs: workerTotalMs,
          ),
        ),
      );
    } catch (error, stackTrace) {
      pending.completer.completeError(error, stackTrace);
    }
  }

}
