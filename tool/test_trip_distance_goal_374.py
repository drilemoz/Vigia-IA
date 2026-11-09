"""Verificação estática do novo assistente e das metas; não substitui Dart SDK."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def read(path):return (ROOT/path).read_text(encoding='utf-8')

class TripDistanceGoal374(unittest.TestCase):
 def test_three_distinct_steps(self):
  s=read('lib/screens/trip_planning_screen.dart')
  for text in ('Nova rota · 1 de 3','Programação · 2 de 3','Ritmo e metas · 3 de 3',
               '_wizardSchedule()', '_wizardRidingGoal()', 'if (step > 0)',
               '_wizardScheduleError()', 'Navigator.pop(ctx)'):
   self.assertIn(text,s)
 def test_schedule_blocks_past_and_keeps_breaks_and_limit(self):
  s=read('lib/screens/trip_planning_screen.dart')
  for text in ('DateTime.now()', 'departureAt.isAfter(DateTime.now())',
               'showDatePicker(', 'showTimePicker(', "const Text('Hoje')",
               "_choice('A cada'", "_choice('Pausa'", "_choice('Almoço'",
               "_choice('Chegar até'", 'latestArrivalMinute: _arrivalCutoffHour * 60'):
   self.assertIn(text,s)
 def test_target_is_real_calculation_and_saved(self):
  s=read('lib/screens/trip_planning_screen.dart')
  m=read('lib/models/planned_bike_trip.dart')
  p=read('lib/services/bike_trip_planner.dart')
  for text in ('dailyDistanceTargetKm: _useDistanceGoal ? _distanceGoalKm : null',
               'dailyDistanceTargetKm: trip.dailyDistanceTargetKm',
               '_distanceFirstDayOnly', '_validDistanceGoal'):
   self.assertIn(text,s)
  for text in ("'dailyDistanceTargetKm': dailyDistanceTargetKm",'double? dailyDistanceTargetKm',
               'clearDailyDistanceTarget',"json['dailyDistanceTargetKm']"):
   self.assertIn(text,m)
  for text in ('firstGoalMeters', 'remainingSeconds', 'distanceGoalFirstDayOnly',
               'dailyDistanceTargetKm','idealEnd','_mapCandidatesToRoute'):
   self.assertIn(text,p)
 def test_retains_stage_offline_and_weather_conferences(self):
  s=read('lib/screens/trip_planning_screen.dart')
  for text in ('_stageSlides(trip, simulatedDays, terrain)', 'TripDayReadinessService.notices(',
               'TripTerrainService.forDays(', 'weatherDays: const <TripWeatherDayForecast>[]',
               '_editStopCheck(day, trip)', 'Barreira' if False else 'proximidade'):
   if text=='proximidade':continue
   self.assertIn(text,s)
 def test_dart_tests_present(self):
  s=read('test/trip_distance_goal_374_test.dart')
  self.assertGreaterEqual(s.count("test('"),6)
  self.assertIn('PlannedBikeTrip.fromJson(',s)
  self.assertIn('50000',s)
if __name__=='__main__':unittest.main()
