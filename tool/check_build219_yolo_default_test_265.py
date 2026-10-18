#!/usr/bin/env python3
"""Avoid APK 219: Flutter test expectations must match current EfficientDet-Lite0 default."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
test = (root/'test/detector_model_preference_test.dart').read_text(encoding='utf-8')
model = (root/'lib/models/video_source_config.dart').read_text(encoding='utf-8')
settings = (root/'lib/services/app_settings_service.dart').read_text(encoding='utf-8')
assert 'this.detectorModel = DetectorModelPreference.efficientDetLite0' in model
assert 'orElse: () => DetectorModelPreference.efficientDetLite0' in settings
assert 'expect(settings.detectorModel, DetectorModelPreference.efficientDetLite0);' in test
assert "expect(settings.detectorModel.label, 'EfficientDet-Lite0');" in test
assert 'detectorModel: DetectorModelPreference.automatic' in test
assert 'expect(automatic.detectorModel, DetectorModelPreference.automatic);' in test
assert 'expect(settings.detectorModel, DetectorModelPreference.automatic)' not in test
print('Build 219: padrão EfficientDet-Lite0 e modo Automático preservados (Flutter test).')
