import 'package:flutter/material.dart';

import '../core/adaptive_layout.dart';
import '../services/automatic_diagnostics_service.dart';

const _mainDestinations = <({IconData icon, IconData selectedIcon, String label})>[
  (icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Início'),
  (icon: Icons.history_outlined, selectedIcon: Icons.history_rounded, label: 'Histórico'),
  (icon: Icons.videocam_outlined, selectedIcon: Icons.videocam_rounded, label: 'Ao vivo'),
  (icon: Icons.video_library_outlined, selectedIcon: Icons.video_library_rounded, label: 'Câmeras'),
  (icon: Icons.photo_library_outlined, selectedIcon: Icons.photo_library_rounded, label: 'Galeria'),
  (icon: Icons.map_outlined, selectedIcon: Icons.map_rounded, label: 'Mapas'),
];

class MainNavigationBar extends StatelessWidget {
  const MainNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: const NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStatePropertyAll<IconThemeData>(
          IconThemeData(size: 22),
        ),
      ),
      child: NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (index >= 0 && index < _mainDestinations.length) {
          AutomaticDiagnosticsService.instance
              .setUiSection(_mainDestinations[index].label);
        }
        onDestinationSelected(index);
      },
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        for (final destination in _mainDestinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
      ),
    );
  }
}

class MainNavigationRail extends StatelessWidget {
  const MainNavigationRail({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (index >= 0 && index < _mainDestinations.length) {
          AutomaticDiagnosticsService.instance
              .setUiSection(_mainDestinations[index].label);
        }
        onDestinationSelected(index);
      },
      labelType: NavigationRailLabelType.selected,
      minWidth: 70,
      scrollable: true,
      groupAlignment: -0.65,
      destinations: [
        for (final destination in _mainDestinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}

/// Shared shell for the six primary destinations.
///
/// Portrait phones keep the bottom NavigationBar. Landscape phones and tablets
/// move navigation to a compact left rail so the limited vertical space is not
/// consumed by a permanent bottom bar.
class AdaptiveMainScaffold extends StatelessWidget {
  const AdaptiveMainScaffold({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.body,
    this.appBar,
    this.backgroundColor,
    this.hideNavigation = false,
    this.extendBodyBehindAppBar = false,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final bool hideNavigation;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    final useRail = !hideNavigation && AdaptiveLayout.useNavigationRail(context);
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      bottomNavigationBar: hideNavigation || useRail
          ? null
          : MainNavigationBar(
              currentIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
            ),
      body: useRail
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafeArea(
                  top: false,
                  right: false,
                  child: MainNavigationRail(
                    currentIndex: currentIndex,
                    onDestinationSelected: onDestinationSelected,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
                ),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }
}
