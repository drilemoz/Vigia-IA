"""Contracts for unified map search / radio / header in 1.0.327."""
import unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]
def file(name):return (R/name).read_text(encoding='utf8')

class UnifiedMap327(unittest.TestCase):
 def test_search_reuses_single_modal_and_fallback(self):
  s=file('lib/screens/map_monitoring_screen.dart')
  segment=s[s.index('  Future<void> _showDestinationSearch()'):s.index('  Future<void> _showMapSettings(')]
  for string in ('showModalBottomSheet<void>', 'GeminiMapService.instance.status()', '.interpret(typed)',
                 'Gemini indisponível. Pesquisa normal ativada.', 'await searchMap(typed)',
                 '_destinationSearch.searchSubmitted(', 'dialogActive', 'searchSerial'):
   self.assertIn(string,segment)
  self.assertNotIn('_openGeminiMapAssistant()',segment)
  self.assertNotIn('GeminiMapAssistantScreen(',segment)
 def test_map_result_is_direct_without_details_dialog(self):
  s=file('lib/screens/map_monitoring_screen.dart')
  segment=s[s.index('  Future<void> _showDestinationSearch()'):s.index('  Future<void> _showMapSettings(')]
  self.assertIn("label: const Text('Ver')",segment)
  self.assertIn('_focusSearchResult(item)',segment)
  self.assertNotIn('_showMapLocationDetails(',segment)
 def test_playing_radio_is_visible_in_focus_mode(self):
  s=file('lib/screens/map_monitoring_screen.dart')
  self.assertIn('if (hud.showRadioShortcut) ...[',s)
  self.assertNotIn('if (focusLevel == 0 && hud.showRadioShortcut)',s)
  self.assertIn('unawaited(_refreshRadioStatus());',s)
 def test_header_does_not_collide_with_system_hud(self):
  s=file('lib/screens/map_monitoring_screen.dart')
  self.assertIn('widget.workspaceHeaderHeight <= 0',s)
  shell=file('lib/screens/map_workspace_shell.dart')
  self.assertIn('workspaceHeaderHeight: 0',shell)
  self.assertNotIn('height: 50',shell)
  self.assertIn('_MapWorkspaceModeShortcut',s)
 def test_version_sync(self):
  self.assertIn('version: 1.0.345+345',file('pubspec.yaml'))
  self.assertTrue((R/'RELEASE-1.0.345.md').exists())
if __name__=='__main__': unittest.main()
