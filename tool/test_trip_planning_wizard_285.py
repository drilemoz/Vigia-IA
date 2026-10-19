"""Contratos de interface do assistente 285; não substituem Flutter Analyze."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def read(rel): return (ROOT/rel).read_text(encoding='utf-8')
class Wizard285(unittest.TestCase):
 def setUp(self):
  self.screen=read('lib/screens/trip_planning_screen.dart')
 def test_initial_screen_has_only_cta_and_library(self):
  body=self.screen[self.screen.index('Widget build(BuildContext context) => AdaptiveMainScaffold('):]
  self.assertIn("const Text('Nova rota')",body)
  self.assertIn('_librarySection()',body)
  self.assertIn('if (_draft != null) _preview(_draft!)',body)
  self.assertNotIn('_cityField(origin: true)',body)
  self.assertNotIn('_settings()',body)
 def test_wizard_has_two_steps(self):
  self.assertIn("'Nova rota · 1 de 2'",self.screen)
  self.assertIn("'Ritmo da pedalada · 2 de 2'",self.screen)
  self.assertIn('barrierDismissible: false',self.screen)
  self.assertIn('validCities && !_locating',self.screen)
  self.assertIn('shouldCalculate = true',self.screen)
 def test_gps_is_only_optional(self):
  self.assertIn('LocationTrackingService.instance',self.screen)
  self.assertIn('ensureAvailable(requestPermission: true)',self.screen)
  self.assertIn("'Usar meu local como origem'",self.screen)
  self.assertNotIn('positionStream(',self.screen)
  self.assertNotIn('Geolocator.getCurrentPosition(',self.screen)
 def test_export_uses_existing_picker_and_escapes_gpx(self):
  service=read('lib/services/planned_trip_export_service.dart')
  self.assertIn('saveBytesWithPicker(',self.screen)
  self.assertIn('application/gpx+xml',self.screen)
  self.assertIn('application/json',self.screen)
  self.assertIn('ACTION_CREATE_DOCUMENT',read('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt'))
  self.assertIn('&amp;',service)
  self.assertIn('trkpt',service)
  self.assertIn('trip.toJson()',service)
  self.assertIn('!point.latitude.isFinite',service)
 def test_action_bar_map_and_confirmation(self):
  self.assertIn('_routeMap(route)',self.screen)
  self.assertIn('_routeActions(trip)',self.screen)
  self.assertIn("const Text('Salvar')",self.screen)
  self.assertIn("const Text('Apagar')",self.screen)
  self.assertIn("Text('Exportar'",self.screen)
  self.assertIn('_discardOrDeleteCurrent',self.screen)
  self.assertIn('_delete(trip)',self.screen)
 def test_existing_storage_not_migrated(self):
  persistence=read('lib/services/planned_bike_trip_service.dart')
  self.assertIn("'schema': 1",persistence)
  self.assertIn('maximumTrips = 40',persistence)
  self.assertIn('vigia_planned_trips.json',persistence)
 def test_metadata(self):
  self.assertIn('version: 1.0.303+303',read('pubspec.yaml'))
  self.assertIn('AppBuildVersion(version: \'1.0.303\', build: 303)',read('lib/services/update_news_catalog.dart'))
  self.assertTrue((ROOT/'RELEASE-1.0.303.md').is_file())
if __name__=='__main__': unittest.main()
