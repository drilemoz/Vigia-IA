"""Regressões do editor único de cicloviagem e da biblioteca compartilhada 341."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

def code(path):
    return (ROOT / path).read_text(encoding='utf-8')

class UnifiedBikePlanning341(unittest.TestCase):
    def test_both_entries_use_the_same_editor_and_map_does_not_duplicate_dialog(self):
        home = code('lib/screens/home_screen_redesign.dart')
        map_screen = code('lib/screens/map_monitoring_screen.dart')
        editor = code('lib/screens/trip_planning_screen.dart')
        self.assertIn('TripPlanningScreen()', home)
        self.assertIn('TripPlanningScreen(', map_screen)
        self.assertIn('initialTrip: draft.copyWith', map_screen)
        self.assertIn('returnToMap: true', map_screen)
        self.assertIn('BikeTripEditorBridge.fromMapRoute(', map_screen)
        self.assertNotIn("const Expanded(child: Text('Plano da cicloviagem'", map_screen)
        self.assertIn('final PlannedBikeTrip? initialTrip;', editor)
        self.assertIn('Navigator.of(context).pop<BikeTripEditorResult>(', editor)

    def test_one_library_with_backward_compatible_last_preview(self):
        map_screen = code('lib/screens/map_monitoring_screen.dart')
        editor = code('lib/screens/trip_planning_screen.dart')
        library = code('lib/services/planned_bike_trip_service.dart')
        self.assertIn('const PlannedBikeTripService().upsert(stored)', map_screen)
        self.assertIn('_library.upsert(draft)', editor)
        self.assertIn('_lastMapPreview.load()', editor)
        self.assertIn('_savedBikeRoutes.save(snapshot)', map_screen)
        self.assertIn('Future<void> upsert(PlannedBikeTrip trip)', library)
        self.assertIn('final existing = await load()', library)
        self.assertIn('vigia_planned_trips.json', library)

    def test_editor_and_map_keep_saved_route_and_settings(self):
        map_screen = code('lib/screens/map_monitoring_screen.dart')
        editor = code('lib/screens/trip_planning_screen.dart')
        model = code('lib/models/planned_bike_trip.dart')
        settings = code('lib/services/bike_trip_schedule_settings_service.dart')
        shell = code('lib/screens/map_workspace_shell.dart')
        self.assertIn('initialSavedRoute: widget.initialSavedRoute', shell)
        self.assertIn('_tryOpenInitialSavedRoute()', map_screen)
        self.assertIn('initialSavedRoute: SavedBikeRoute(', editor)
        self.assertIn('_scheduleSettings.initialize()', editor)
        self.assertIn('await _mapViewSettings.setBikeUseHistoricalSpeed(false)', map_screen)
        for key in ('balanceDays', 'forceLunch', 'departureMinute', 'breakEveryKm'):
            self.assertIn("'"+key+"'", model)
        self.assertIn('temp.rename(file.path)', settings)
        self.assertIn('balanceDays: trip.balanceDays', editor)
        self.assertIn('forceLunch: trip.forceLunch', editor)

    def test_route_is_not_recalculated_when_opening_map_editor(self):
        bridge = code('lib/services/bike_trip_editor_bridge.dart')
        self.assertIn('routes: saved.routes', bridge)
        self.assertIn('selectedIndex: saved.selectedIndex', bridge)
        self.assertNotIn('fetchAlternatives(', bridge)
        self.assertNotIn('currentPosition(', bridge)
        self.assertIn('Início do trajeto', bridge)

if __name__ == '__main__':
    unittest.main()
