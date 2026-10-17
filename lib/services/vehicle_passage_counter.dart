import '../models/object_filter_catalog.dart';
import '../models/tracked_detection.dart';

/// Contagem experimental de passagens numa câmera FIXA.
///
/// A linha é vertical, no centro da imagem. Um veículo só conta ao ser
/// observado em pelo menos duas amostras em cada lado (x <= .42 / >= .58).
/// Um ID de rastreamento conta no máximo uma vez por sessão, inclusive em
/// retornos ou oscilações. Não é um odômetro nem mede fluxo com câmera móvel.
class VehiclePassageCounter {
  VehiclePassageCounter({this.maxObservationGap = const Duration(seconds: 4)});

  final Duration maxObservationGap;
  final Map<int, _PassageTrack> _tracks = <int, _PassageTrack>{};
  int _count = 0;
  int get count => _count;

  void reset() {
    _tracks.clear();
    _count = 0;
  }

  void observe(
    List<TrackedDetection> detections, {
    required DateTime now,
    required bool cameraMoving,
  }) {
    // Movimento global invalida a linha virtual, inclusive pistas anteriores.
    // Congela o total já confirmado, sem fingir que o deslocamento é tráfego.
    if (cameraMoving) {
      _tracks.clear();
      return;
    }
    _tracks.removeWhere(
      (_, track) => now.difference(track.lastSeen) > const Duration(seconds: 15),
    );
    for (final tracked in detections) {
      if (!ObjectFilterCatalog.vehicles.contains(tracked.detection.label) ||
          tracked.detection.inferred) {
        continue;
      }
      final box = tracked.detection.box;
      final x = (box.xMin + box.xMax) / 2;
      if (!x.isFinite || x < 0 || x > 1) continue;
      final side = x <= 0.42 ? -1 : (x >= 0.58 ? 1 : 0);
      final track = _tracks.putIfAbsent(
        tracked.trackId,
        () => _PassageTrack(lastSeen: now),
      );
      if (now.isBefore(track.lastSeen) ||
          now.difference(track.lastSeen) > maxObservationGap) {
        track.clearSide();
      }
      track.lastSeen = now;
      if (side == 0 || track.counted) continue;
      if (side == track.side) {
        track.oppositeCandidateSide = 0;
        track.oppositeSamples = 0;
        track.samples++;
        continue;
      }
      // Troca de lado: exige confirmação do lado anterior e do lado novo.
      if (track.side != 0 && track.samples >= 2) {
        if (track.oppositeCandidateSide != side) {
          track.oppositeCandidateSide = side;
          track.oppositeSamples = 1;
        } else {
          track.oppositeSamples++;
        }
        if (track.oppositeSamples >= 2) {
          track.counted = true;
          _count++;
        }
      } else {
        track.side = side;
        track.samples = 1;
        track.oppositeCandidateSide = 0;
        track.oppositeSamples = 0;
      }
    }
  }
}

class _PassageTrack {
  _PassageTrack({required this.lastSeen});

  DateTime lastSeen;
  int side = 0;
  int samples = 0;
  int oppositeCandidateSide = 0;
  int oppositeSamples = 0;
  bool counted = false;

  void clearSide() {
    side = 0;
    samples = 0;
    oppositeCandidateSide = 0;
    oppositeSamples = 0;
  }
}
