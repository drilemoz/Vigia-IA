import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// O isolamento abrange apenas servicos do Vigia IA; nao controla o Android.
class TransmitterExclusivePolicy {
  const TransmitterExclusivePolicy._();
  static const MethodChannel _channel = MethodChannel('vigiaia/transmitter_exclusive');
  static bool _enabled = false;
  static bool get enabled => _enabled;

  /// Ativar ANTES de construir a interface e inicializar servicos opcionais.
  static Future<void> apply(bool enabled) async {
    _enabled = enabled;
    try {
      await _channel.invokeMethod<void>('setExclusive', <String, Object>{'enabled': enabled});
    } on MissingPluginException {
      // Testes Flutter e plataformas nao Android.
    } on PlatformException catch (error) {
      debugPrint('Vigia IA: isolamento nativo indisponivel: $error');
      rethrow;
    }
  }
}
