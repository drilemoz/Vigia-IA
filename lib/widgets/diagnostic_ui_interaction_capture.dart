import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/automatic_diagnostics_service.dart';

/// Registra interações gerais sem capturar textos, senhas ou coordenadas exatas.
/// Toques em campos editáveis, teclado e gestos de arrastar são ignorados.
class DiagnosticUiInteractionCapture extends StatefulWidget {
  const DiagnosticUiInteractionCapture({super.key, required this.child});

  final Widget child;

  @override
  State<DiagnosticUiInteractionCapture> createState() =>
      _DiagnosticUiInteractionCaptureState();
}

class _DiagnosticUiInteractionCaptureState
    extends State<DiagnosticUiInteractionCapture> {
  final Map<int, ({Offset at, DateTime when})> _starts = {};

  bool get _isEditing {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return true;
    final focused = FocusManager.instance.primaryFocus?.context;
    return focused?.widget is EditableText ||
        focused?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _start(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch || _isEditing) return;
    _starts[event.pointer] = (at: event.position, when: DateTime.now());
  }

  void _end(PointerUpEvent event) {
    final down = _starts.remove(event.pointer);
    if (down == null || _isEditing) return;
    final elapsed = DateTime.now().difference(down.when);
    if (elapsed > const Duration(milliseconds: 700) ||
        (event.position - down.at).distance > 24) {
      return; // Rolagem, gesto longo e arraste não são cliques.
    }
    final size = MediaQuery.sizeOf(context);
    if (size.width <= 0 || size.height <= 0) return;
    // Apenas uma região 3x3. Nunca envia pixel, conteúdo tocado ou texto.
    final column = (event.position.dx / size.width * 3).floor().clamp(0, 2).toInt();
    final row = (event.position.dy / size.height * 3).floor().clamp(0, 2).toInt();
    AutomaticDiagnosticsService.instance.recordUiTap(row, column);
  }

  @override
  void dispose() {
    _starts.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _start,
        onPointerUp: _end,
        onPointerCancel: (event) {
          _starts.remove(event.pointer);
        },
        behavior: HitTestBehavior.deferToChild,
        child: widget.child,
      );
}
