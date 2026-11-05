import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_metadata.dart';

import '../services/automatic_diagnostics_service.dart';

/// Runs before startup/news/permission dialogs, in every launch mode.
class DiagnosticRecoveryHost extends StatefulWidget {
  const DiagnosticRecoveryHost({
    super.key,
    required this.child,
    this.capture,
    this.exportIncident,
    this.acknowledge,
  });
  final Future<Map<String, Object?>> Function()? capture;
  final Future<String?> Function(Map<String, Object?>)? exportIncident;
  final Future<bool> Function(String)? acknowledge;
  final Widget child;

  @override
  State<DiagnosticRecoveryHost> createState() => _DiagnosticRecoveryHostState();
}

class _DiagnosticRecoveryHostState extends State<DiagnosticRecoveryHost>
    with WidgetsBindingObserver {
  bool _ready = false;
  bool _checking = false;
  final Set<String> _shownIncidentIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If native diagnostics were unavailable during startup, a later resume
    // can recover the incident without restarting or keeping the UI blocked.
    if (state == AppLifecycleState.resumed && _ready && !_checking) {
      unawaited(_check());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final diagnostics = AutomaticDiagnosticsService.instance;
      final report = await (widget.capture ?? diagnostics.capture)();
      final pending = report['pendingIncidents'];
      if (!mounted) return;
      if (pending is List && pending.isNotEmpty && pending.last is Map) {
        final incident = (pending.last as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final incidentId = incident['id']?.toString() ?? '';
        if (incidentId.isNotEmpty && !_shownIncidentIds.add(incidentId)) return;
        // Incidents written by older builds have no severity. Respect the
        // Android exit reason/importance instead of presenting a cached
        // low-memory kill from an older version as a new app crash.
        final legacyExit = incident['lastExit'];
        final cachedMemoryExit = legacyExit is Map &&
            legacyExit['reason'] == 3 &&
            legacyExit['importance'] is num &&
            (legacyExit['importance'] as num) >= 400;
        final severity = incident['severity']?.toString() ??
            (cachedMemoryExit ? 'info' : 'error');
        final isInformational = severity == 'info';
        final sourceVersion = incident['sourceVersion']?.toString() ??
            ((incident['session'] is Map)
                ? (incident['session'] as Map)['version']?.toString()
                : null);
        final previousVersion = sourceVersion != null &&
            sourceVersion.isNotEmpty && sourceVersion != AppMetadata.version;
        final subtitle = previousVersion
            ? 'Registro da versão $sourceVersion, recuperado pela ${AppMetadata.version}.\n\n'
            : 'Registro da sessão anterior.\n\n';
        bool exporting = false;
        String? resultMessage;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => PopScope(
              canPop: !exporting,
              child: AlertDialog(
                title: Text(isInformational
                    ? 'Encerramento anterior do Android'
                    : previousVersion
                        ? 'Falha recuperada de versão anterior'
                        : 'Erro detectado no último uso'),
                content: Text(
                  resultMessage ??
                      '$subtitle${incident['reason'] ?? 'Foi registrado um evento no aplicativo.'}\n\n'
                          'O diagnóstico foi salvo automaticamente. Deseja exportar o relatório para Downloads? '
                          'Nenhum relatório é enviado automaticamente.',
                ),
                actions: [
                  TextButton(
                    onPressed: exporting
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('Agora não'),
                  ),
                  FilledButton(
                    onPressed: exporting
                        ? null
                        : () async {
                            update(() {
                              exporting = true;
                              resultMessage = 'Salvando relatório…';
                            });
                            try {
                              final path =
                                  await (widget.exportIncident ??
                                          diagnostics.exportIncident)(incident)
                                      .timeout(const Duration(seconds: 20));
                              if (path == null || path.isEmpty) {
                                throw StateError('Não foi possível salvar');
                              }
                              final acknowledged =
                                  await (widget.acknowledge ??
                                      diagnostics.acknowledge)(
                                    incident['id']?.toString() ?? '',
                                  );
                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      acknowledged
                                          ? 'Diagnóstico salvo em Downloads.'
                                          : 'Diagnóstico salvo em Downloads. O aviso poderá aparecer novamente.',
                                    ),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (!dialogContext.mounted) return;
                              update(() {
                                exporting = false;
                                resultMessage = 'Não foi possível exportar. O diagnóstico continua salvo; você pode tentar novamente.';
                              });
                            }
                          },
                    child: Text(exporting ? 'Salvando…' : 'Exportar'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } finally {
      _checking = false;
      if (mounted && !_ready) setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) => _ready
      ? widget.child
      : const Scaffold(body: Center(child: CircularProgressIndicator()));
}
