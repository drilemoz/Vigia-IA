import 'package:flutter/material.dart';

import '../screens/events_screen.dart';
import '../screens/home_screen.dart';
import '../screens/map_workspace_shell.dart';
import '../screens/multi_camera_screen.dart';
import '../screens/settings_screen.dart';

/// Destinos principais: Início, Histórico, Ao vivo, Câmeras, Mapas, Ajustes.
/// A navegação principal substitui a pilha para impedir abas duplicadas.
/// Ao vivo inicia a câmera local pelo fluxo de permissões já existente na Home.
void navigateToMainDestination(
  BuildContext context,
  int destination, {
  required int currentIndex,
}) {
  if (destination == currentIndex) return;
  final Widget screen = switch (destination) {
    0 => const HomeScreen(),
    1 => const EventsScreen(),
    2 => const HomeScreen(startMonitorOnLoad: true),
    3 => const MultiCameraScreen(),
    4 => const MapWorkspaceShell(),
    5 => const SettingsScreen(),
    _ => const HomeScreen(),
  };
  Navigator.of(context).pushAndRemoveUntil<void>(
    MaterialPageRoute<void>(builder: (_) => screen),
    (_) => false,
  );
}
