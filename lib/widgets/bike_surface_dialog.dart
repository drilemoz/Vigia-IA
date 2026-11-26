import 'package:flutter/material.dart';
import '../services/map_view_settings_service.dart';

Future<bool> chooseBikeSurface(BuildContext context) async {
  final settings = MapViewSettingsService.instance;
  await settings.initialize();
  if (!context.mounted) return false;
  final selected = await showDialog<BikeSurfacePreference>(context: context,
    builder: (ctx) => SimpleDialog(title: const Text('Pavimento da rota'), children: [
      for (final option in BikeSurfacePreference.values)
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, option),
          child: ListTile(contentPadding: EdgeInsets.zero,
            leading: Icon(option == settings.bikeSurface ? Icons.check_circle : Icons.circle_outlined),
            title: Text(switch (option) {
              BikeSurfacePreference.paved => 'Priorizar asfalto',
              BikeSurfacePreference.balanced => 'Equilibrada',
              BikeSurfacePreference.shortest => 'Menor distância',
              BikeSurfacePreference.rain => 'Modo chuva',
            }),
            subtitle: Text(switch (option) {
              BikeSurfacePreference.paved => 'Preferir vias pavimentadas.',
              BikeSurfacePreference.balanced => 'Permitir vias não pavimentadas.',
              BikeSurfacePreference.shortest => 'Buscar trajetos mais curtos.',
              BikeSurfacePreference.rain => 'Evitar terra; pavimento desconhecido exige conferência.',
            }))),
    ]));
  if (selected == null) return false;
  await settings.setBikeSurface(selected);
  return true;
}
