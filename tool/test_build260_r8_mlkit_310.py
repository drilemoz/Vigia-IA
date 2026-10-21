"""Build 260 R8 regression: optional ML Kit language modules must not block Release."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
LANG = ('chinese', 'devanagari', 'japanese', 'korean')

class Build260R8Regression(unittest.TestCase):
    def test_eight_optional_missing_types_are_the_only_suppressed_types(self):
        rules = (ROOT/'android/app/proguard-rules.pro').read_text(encoding='utf8')
        actual = {line.strip()[len('-dontwarn '):] for line in rules.splitlines() if line.strip().startswith('-dontwarn ')}
        expected = {f'com.google.mlkit.vision.text.{script}.{script.capitalize()}TextRecognizerOptions' for script in LANG}
        expected.update({entry+'$Builder' for entry in tuple(expected)})
        self.assertEqual(actual,expected)
        self.assertNotIn('com.google.mlkit.vision.text.latin',rules)
        self.assertNotIn('com.google.mlkit.**',rules)
        self.assertFalse(any('*' in rule for rule in actual))

    def test_release_uses_same_rules_and_bootstrap_restores_them(self):
        primary=(ROOT/'android/app/proguard-rules.pro').read_bytes()
        copy=(ROOT/'tool/android/proguard-rules.pro').read_bytes()
        self.assertEqual(primary,copy)
        gradle=(ROOT/'android/app/build.gradle.kts').read_text()
        self.assertIn('proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")',gradle)
        self.assertIn('signingConfig = signingConfigs.getByName("release")',gradle)
        self.assertNotIn('isMinifyEnabled = false',gradle)
        bootstrap=(ROOT/'tool/bootstrap_android.sh').read_text()
        self.assertIn('proguardFiles(getDefaultProguardFile(\"proguard-android-optimize.txt\"), \"proguard-rules.pro\")', bootstrap)
        self.assertIn('cp "$ROOT/tool/android/proguard-rules.pro" "$ROOT/android/app/proguard-rules.pro"',bootstrap)

    def test_original_ocr_and_local_gallery_remain_available(self):
        self.assertIn('google_mlkit_text_recognition', (ROOT/'pubspec.yaml').read_text())
        self.assertIn('TextRecognitionScript.latin',(ROOT/'lib/services/vehicle_plate_ocr_service.dart').read_text())
        self.assertIn('class RemoteGalleryScreen', (ROOT/'lib/screens/remote_gallery_screen.dart').read_text())
        self.assertIn('version: 1.0.318+318',(ROOT/'pubspec.yaml').read_text())
        self.assertTrue((ROOT/'RELEASE-1.0.318.md').is_file())

if __name__=='__main__':unittest.main()
