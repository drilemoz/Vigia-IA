"""Regressões estruturais do Flutter Analyze do build 253.

Não substitui flutter analyze, que é executado no CI com o SDK Flutter.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(name):
    return (ROOT / name).read_text('utf-8')


class Build253Analyzer302(unittest.TestCase):
    def test_rtsp_editor_user_field_has_no_extra_parenthesis(self):
        editor = src('lib/screens/rtsp_camera_editor_dialog.dart')
        self.assertIn("prefixIcon: Icon(Icons.person_outline_rounded), hintText: 'admin')),", editor)
        self.assertNotIn("hintText: 'admin'))),", editor)
        self.assertIn('if (_busy) ...[', editor)
        self.assertIn('actionsPadding: const EdgeInsets', editor)
        self.assertIn('        ))),\n      actionsPadding:', editor)

    def test_transmitter_checks_nullable_status_before_ready(self):
        transmitter = src('lib/screens/native_transmitter_screen.dart')
        self.assertIn('if (s != null && !s.ready)', transmitter)
        self.assertNotRegex(transmitter, r'if \(!s\.ready\)')

    def test_sdp_regex_uses_supported_multiline_parameter(self):
        assistant = src('lib/services/rtsp_connection_assistant.dart')
        self.assertIn("RegExp(r'^m=video\\s', multiLine: true, caseSensitive: false)", assistant)
        self.assertNotIn("RegExp(r'(?m)", assistant)

    def test_changed_if_branches_are_braced(self):
        assistant = src('lib/services/rtsp_connection_assistant.dart')
        self.assertIn('if (colon > 0) {', assistant)
        self.assertRegex(assistant, r'bytes\[i \+ 3\] == 10\) \{\s*return i;')
        self.assertRegex(assistant, r'bytes\[i \+ 1\] == 10\) \{\s*return i;')
        self.assertIn("(params.containsKey('qop') && !qopList.contains('auth'))) {", assistant)

    def test_socket_utf8_decoder_receives_list_int_stream(self):
        test = src('test/rtsp_connection_assistant_test.dart')
        self.assertIn('.cast<List<int>>()\n          .transform(utf8.decoder)', test)
        self.assertNotIn("import 'dart:async';", test)


if __name__ == '__main__':
    unittest.main()
