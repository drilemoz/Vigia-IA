import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/detection.dart';

/// O OCR é local e executado somente por ação do usuário, nunca na análise
/// contínua das câmeras. O resultado é uma hipótese, não um dado oficial.
class VehiclePlateOcrService {
  const VehiclePlateOcrService();

  Future<String?> scan(String imagePath, NormalizedBox box) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('OCR disponível somente em dispositivos móveis.');
    }
    final original = File(imagePath);
    if (!await original.exists()) {
      throw StateError('A fotografia deste registro não está mais disponível.');
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    File? cropFile;
    try {
      final bytes = await original.readAsBytes();
      final crop = await compute<Map<String, Object?>, List<int>?>(
        _makeVehicleCrop,
        <String, Object?>{
          'bytes': bytes,
          'xMin': box.xMin,
          'yMin': box.yMin,
          'xMax': box.xMax,
          'yMax': box.yMax,
        },
      );
      if (crop != null) {
        final tmp = await getTemporaryDirectory();
        cropFile = File('${tmp.path}${Platform.pathSeparator}vigia_plate_${DateTime.now().microsecondsSinceEpoch}.jpg');
        await cropFile.writeAsBytes(crop, flush: true);
        final result = await recognizer.processImage(
          InputImage.fromFilePath(cropFile.path),
        );
        final candidate = BrazilianPlateText.bestCandidate(result.text);
        if (candidate != null) return candidate;
      }
      // Plano B: texto no quadro inteiro, se o recorte não contiver a placa.
      final result = await recognizer.processImage(
        InputImage.fromFilePath(original.path),
      );
      return BrazilianPlateText.bestCandidate(result.text);
    } finally {
      await recognizer.close();
      if (cropFile != null) {
        try {
          if (await cropFile.exists()) await cropFile.delete();
        } catch (_) {}
      }
    }
  }
}

/// O filtro aceita ABC1234 e ABC1D23. Corrige confusões OCR entre O/0,
/// I/1 e S/5 somente nas posições numéricas.
class BrazilianPlateText {
  const BrazilianPlateText._();

  static final RegExp _candidate = RegExp(
    r'(?<![A-Z0-9])[A-Z0-9]{3}[\s\-\.]?[A-Z0-9]{4}(?![A-Z0-9])',
  );
  static final RegExp _valid = RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$');

  static String? normalize(String text) {
    final upper = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (upper.length != 7) return null;
    final chars = upper.split('');
    for (final index in [0, 1, 2]) {
      chars[index] = switch (chars[index]) {
        '0' => 'O',
        '1' => 'I',
        '5' => 'S',
        '8' => 'B',
        _ => chars[index],
      };
    }
    for (final index in [3, 5, 6]) {
      chars[index] = switch (chars[index]) {
        'O' => '0',
        'I' || 'L' => '1',
        'S' => '5',
        'B' => '8',
        'Z' => '2',
        _ => chars[index],
      };
    }
    // Posição 4: número em placa antiga, letra em placa Mercosul.
    final letter5 = RegExp(r'^[A-Z]$').hasMatch(chars[4]);
    if (letter5) {
      if (chars[4] == 'O') chars[4] = '0';
      if (chars[4] == 'I') chars[4] = '1';
    }
    final normalized = chars.join();
    if (!_valid.hasMatch(normalized)) return null;
    final oldPlate = RegExp(r'^[A-Z]{3}[0-9]{4}$').hasMatch(normalized);
    final mercosur = RegExp(r'^[A-Z]{3}[0-9][A-Z][0-9]{2}$').hasMatch(normalized);
    return oldPlate || mercosur ? normalized : null;
  }

  static String? bestCandidate(String text) {
    final upper = text.toUpperCase();
    for (final match in _candidate.allMatches(upper)) {
      final result = normalize(match.group(0)!);
      if (result != null) return result;
    }
    return null;
  }
}

List<int>? _makeVehicleCrop(Map<String, Object?> data) {
  final source = img.decodeImage(data['bytes']! as Uint8List);
  if (source == null) return null;
  final xmin = (data['xMin']! as double).clamp(0.0, 1.0);
  final ymin = (data['yMin']! as double).clamp(0.0, 1.0);
  final xmax = (data['xMax']! as double).clamp(0.0, 1.0);
  final ymax = (data['yMax']! as double).clamp(0.0, 1.0);
  // Margem preserva a placa quando a caixa do detector é apertada.
  final x0 = (math.max(0.0, xmin - 0.05) * source.width).floor();
  final y0 = (math.max(0.0, ymin - 0.05) * source.height).floor();
  final x1 = (math.min(1.0, xmax + 0.05) * source.width).ceil();
  final y1 = (math.min(1.0, ymax + 0.05) * source.height).ceil();
  final width = x1 - x0;
  final height = y1 - y0;
  if (width < 32 || height < 20) return null;
  final crop = img.copyCrop(source, x: x0, y: y0, width: width, height: height);
  return img.encodeJpg(crop, quality: 90);
}
