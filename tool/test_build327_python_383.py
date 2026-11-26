"""Regressão: Python 3.14 incompatível com a cadeia YOLO26s no CI 327."""
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class Build327PythonTests(unittest.TestCase):
    def test_ci_provisions_python_before_export_and_checks(self):
        workflow = (ROOT / '.github/workflows/android-apk.yml').read_text()
        self.assertRegex(workflow, r"uses: actions/setup-python@v\d+\s+with:\s+python-version: '3\.12'")
        self.assertLess(workflow.index('actions/setup-python@'), workflow.index('bash ./tool/verify_project.sh'))
        self.assertLess(workflow.index('actions/setup-python@'), workflow.index('bash ./tool/export_yolo26s.sh'))
        self.assertIn('python3 tool/export_yolo26s.py', workflow)

    def test_guard_accepts_only_python_312(self):
        script = (ROOT / 'tool/export_yolo26s.sh').read_text()
        guard = script.split("python3 - <<'PYTHON'\n", 1)[1].split('\nPYTHON', 1)[0]
        self.assertLess(script.index("python3 - <<'PYTHON'"), script.index('python3 -m pip install'))
        for minor in (11, 12, 13, 14):
            with self.subTest(minor=minor):
                code = f'import sys; sys.version_info = (3, {minor}, 0); sys.version = "3.{minor}.0"\n' + guard
                result = subprocess.run([sys.executable, '-c', code], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0 if minor == 12 else 1)

    def test_no_bypass_of_model_validation(self):
        workflow = (ROOT / '.github/workflows/android-apk.yml').read_text()
        self.assertNotIn('PYO3_USE_ABI3_FORWARD_COMPATIBILITY', workflow)
        self.assertIn('APK sem YOLO26s real', workflow)
        self.assertIn('flutter analyze --fatal-infos --fatal-warnings', workflow)
