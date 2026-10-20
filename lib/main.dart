import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/app_orientation_service.dart';
import 'services/appearance_settings_service.dart';
import 'services/error_log_service.dart';
import 'services/automatic_diagnostics_service.dart';
import 'services/system_ui_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AutomaticDiagnosticsService.instance.start();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      ErrorLogService.instance.recordException(
        source: 'Flutter',
        error: details.exception,
        stackTrace: details.stack,
        message: 'Erro não tratado pela interface.',
        context: <String, Object?>{
          'nãoTratado': true,
          if (details.context != null)
            'contexto': details.context!.toDescription(),
          'biblioteca': details.library,
        },
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      ErrorLogService.instance.recordException(
        source: 'Plataforma',
        error: error,
        stackTrace: stackTrace,
        message: 'Erro não tratado da plataforma.',
        context: const {'nãoTratado': true},
      ),
    );
    return true;
  };

  await ErrorLogService.instance.initialize();
  try {
    await SystemUiService.edgeToEdge();
    await AppOrientationService.lockPortrait();
    await AppearanceSettingsService.instance.initialize();
  } catch (error, stackTrace) {
    await ErrorLogService.instance.recordException(source: 'Inicialização',
        error: error, stackTrace: stackTrace, context: const {'nãoTratado': true});
  }
  runApp(const VigiaIaApp());
}
