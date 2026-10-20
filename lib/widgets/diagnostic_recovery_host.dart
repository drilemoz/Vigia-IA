import 'dart:async';

import 'package:flutter/material.dart';

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

class _DiagnosticRecoveryHostState extends State<DiagnosticRecoveryHost> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  Future<void> _check() async {
    try {
      final diagnostics = AutomaticDiagnosticsService.instance;
      final report = await (widget.capture ?? diagnostics.capture)();
      final pending = report['pendingIncidents'];
      if (!mounted) return;
      if (pending is List && pending.isNotEmpty && pending.last is Map) {
        final incident = (pending.last as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        );
        bool exporting = false;
        String? resultMessage;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => PopScope(
              canPop: !exporting,
              child: AlertDialog(
                title: const Text('Erro detectado no último uso'),
                content: Text(
                  resultMessage ??
                      '${incident['reason'] ?? 'Foi registrado um problema no aplicativo.'}\n\n'
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
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) => _ready
      ? widget.child
      : const Scaffold(body: Center(child: CircularProgressIndicator()));
}
