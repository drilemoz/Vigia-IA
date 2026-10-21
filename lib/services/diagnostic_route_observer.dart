import 'package:flutter/material.dart';

import 'automatic_diagnostics_service.dart';

/// Monitora push/pop sem persistir nomes de rotas, URLs ou parâmetros.
class DiagnosticRouteObserver extends NavigatorObserver {
  DiagnosticRouteObserver._();
  static final instance = DiagnosticRouteObserver._();

  int _depth = 0;
  final _diagnostics = AutomaticDiagnosticsService.instance;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _diagnostics.setUiRouteDepth(++_depth, 'abrir_tela');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _diagnostics.setUiRouteDepth(--_depth, 'voltar_tela');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _diagnostics.setUiRouteDepth(--_depth, 'remover_tela');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _diagnostics.setUiRouteDepth(_depth, 'substituir_tela');
  }
}
