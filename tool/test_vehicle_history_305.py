"""Structural regression checks for vehicle photos and on-demand local OCR.
Dart behavior is exercised by test/vehicle_*_test.dart on CI.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(path):
    return (ROOT / path).read_text(encoding='utf-8')


class VehicleHistory305Test(unittest.TestCase):
    def test_vehicle_detection_has_no_continuous_ocr(self):
        controller = source('lib/controllers/monitor_controller.dart')
        self.assertIn('primaryGlobalForBike', controller)
        self.assertIn('_captureVehicleObservations(', controller)
        self.assertIn('_vehicleCapture.observe(', source('lib/controllers/monitor_controller_vehicle_support.dart'))
        self.assertIn('bikeApproachDetectionActive || _vehicleCapture.enabled', controller)
        self.assertNotIn('VehiclePlateOcrService', controller)

    def test_opt_in_and_guard(self):
        service = source('lib/services/vehicle_capture_service.dart')
        self.assertIn('bool _enabled = false;', service)
        self.assertIn('minimumBetweenPhotos = Duration(seconds: 8)', service)
        self.assertIn('repeatSameRegion = Duration(seconds: 60)', service)
        self.assertIn('match.hits < 2', service)
        self.assertIn('cameraMoving', service)
        self.assertIn('requireSnapshot: true', service)

    def test_history_includes_photo_and_plate(self):
        event = source('lib/models/monitor_event.dart')
        self.assertIn('vehicleSnapshot', event)
        self.assertIn("'plateText': plateText", event)
        self.assertIn("plateText: json['plateText']", event)
        self.assertIn('Future<void> updatePlate(String id, String? plateText)', source('lib/services/event_history_service.dart'))

    def test_ocr_is_offline_manual_only(self):
        service = source('lib/services/vehicle_plate_ocr_service.dart')
        ui = source('lib/widgets/vehicle_plate_section.dart')
        self.assertIn('TextRecognizer(script: TextRecognitionScript.latin)', service)
        self.assertIn('BrazilianPlateText.bestCandidate', service)
        self.assertIn('Escanear placa', ui)
        self.assertIn('onPressed: _scanning || !hasPhoto ? null', ui)
        self.assertNotIn('api.platerecognizer.com', service)
        self.assertNotIn('VehiclePlateOcrService', source('lib/services/vehicle_capture_service.dart'))

    def test_version_and_ui_switch(self):
        self.assertIn('version: 1.0.321+321', source('pubspec.yaml'))
        self.assertIn('google_mlkit_text_recognition: ^0.17.1', source('pubspec.yaml'))
        self.assertIn('SwitchListTile.adaptive', source('lib/screens/events_screen.dart'))
        self.assertIn('Fotografar veículos automaticamente', source('lib/screens/events_screen.dart'))


if __name__ == '__main__':
    unittest.main()
