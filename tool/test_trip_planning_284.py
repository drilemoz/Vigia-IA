"""Contratos preventivos do Planejamento 284 e build 237; testes Flutter pendentes no CI."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

def read(path): return (ROOT / path).read_text(encoding='utf-8')

class TripPlanning284(unittest.TestCase):
    def test_theme_verifier_follows_system_and_fixes_build_237(self):
        checker = read('tool/verify_project.sh')
        service = read('lib/services/appearance_settings_service.dart')
        self.assertIn("AppThemePreference _themePreference = AppThemePreference.system;", checker)
        self.assertIn("orElse: () => AppThemePreference.system", checker)
        self.assertNotIn("AppThemePreference _themePreference = AppThemePreference.dark;'", checker)
        self.assertIn('ThemeMode.system', service)
        self.assertIn('await file.exists()', service)

    def test_home_card_is_lazy_and_no_replacement_for_modes(self):
        home = read('lib/screens/home_screen_redesign.dart')
        self.assertEqual(home.count('VigiaModeCard('), 4)
        self.assertIn('_buildTripPlanningCard()', home)
        self.assertIn('TripPlanningScreen()', home)
        self.assertIn('Planejamento', home)
        self.assertIn('Cicloviagens', home)
        self.assertIn('_buildSystemStatusStrip', home)

    def test_city_search_is_explicit_online_and_does_not_force_gps(self):
        screen = read('lib/screens/trip_planning_screen.dart')
        self.assertIn('_citySearch.updateLocalQuery(', screen)
        self.assertIn('_citySearch.searchSubmitted(', screen)
        self.assertIn('onlineAllowed: true', screen)
        self.assertIn('onlyDownloaded: true', screen)
        self.assertIn('MapCyclingRouteService', screen)
        self.assertNotIn('Geolocator.getCurrentPosition(', screen)
        self.assertNotIn('requestCameraPermission(', screen)
        self.assertIn('alternativeCount: 2', screen)

    def test_routes_and_days_reuse_existing_math_and_schedule(self):
        screen = read('lib/screens/trip_planning_screen.dart')
        for requirement in ('BikeTripPlanner()', 'BikeTripSchedule.forDay(',
                            'selectedRoute.distanceMeters', 'MapTravelMode.bicycle',
                            'Apoios salvos', 'Buscar apoios', 'Carregar mapa'):
            if requirement == 'Carregar mapa':
                self.assertIn('Mostrar mapa-base online', screen)
            else:
                self.assertIn(requirement, screen)
        self.assertIn('Não indica cidade ou hospedagem confirmada.', screen)

    def test_library_keeps_multiple_routes_offline(self):
        source = read('lib/services/planned_bike_trip_service.dart')
        model = read('lib/models/planned_bike_trip.dart')
        self.assertIn('maximumTrips = 40', source)
        self.assertIn('vigia_planned_trips.json', source)
        self.assertIn('temp.rename(file.path)', source)
        self.assertIn('SavedBikeRouteService.encode', model)
        self.assertIn('SavedBikeRouteService.decode', model)
        self.assertIn('get selectedRoute', model)
        self.assertIn('Abrir prévia nos Mapas', read('lib/screens/trip_planning_screen.dart'))

if __name__ == '__main__': unittest.main()
