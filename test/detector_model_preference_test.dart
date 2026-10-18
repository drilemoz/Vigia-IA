import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/video_source_config.dart';

void main() {
  test('modelo de IA padrao e EfficientDet-Lite0; automatico continua opcional', () {
    const settings = MonitorSettings();
    expect(settings.detectorModel, DetectorModelPreference.efficientDetLite0);
    expect(settings.detectorModel.label, 'EfficientDet-Lite0');
    final automatic = settings.copyWith(
      detectorModel: DetectorModelPreference.automatic,
    );
    expect(automatic.detectorModel, DetectorModelPreference.automatic);
    expect(automatic.detectorModel.label, 'Automático');
    expect(settings.detectorModel, DetectorModelPreference.efficientDetLite0);
  });

  test('preferencia manual nao muda outros ajustes da IA', () {
    const settings = MonitorSettings(aiEnabled: false);
    final manual = settings.copyWith(
      detectorModel: DetectorModelPreference.yolo26s,
    );
    expect(manual.detectorModel, DetectorModelPreference.yolo26s);
    expect(manual.aiEnabled, isFalse);
    expect(manual.trackingEnabled, settings.trackingEnabled);
    expect(manual.copyWith(detectorModel: DetectorModelPreference.automatic)
        .detectorModel, DetectorModelPreference.automatic);
  });
}
