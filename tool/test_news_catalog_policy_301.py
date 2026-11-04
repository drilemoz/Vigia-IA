import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_news_catalog_policy as policy

ROOT = Path(__file__).resolve().parents[1]


def current_release_fixture(root: Path):
    """Use the shipped release text, not a sentence from an older release."""
    (root / 'lib/services').mkdir(parents=True, exist_ok=True)
    pubspec = (ROOT / 'pubspec.yaml').read_text('utf8')
    version = re.search(r'(?m)^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$', pubspec)
    if version is None:
        raise AssertionError('pubspec.yaml sem versão válida no teste')
    (root / 'pubspec.yaml').write_text(f'version: {version.group(1)}\n', 'utf8')
    catalog = (ROOT / 'lib/services/update_news_catalog.dart').read_text('utf8')
    first_message = re.search(r"changes:\s*<String>\s*\[\s*'([^'\n]+)'", catalog)
    if first_message is None:
        raise AssertionError('Catálogo atual sem a primeira mensagem de Novidades')
    return catalog, first_message


def replace_first_message(catalog: str, match: re.Match, replacement: str) -> str:
    return catalog[:match.start(1)] + replacement + catalog[match.end(1):]


class NewsCatalogPolicy301Tests(unittest.TestCase):
    def test_current_news_accepts_descriptions_of_fixes(self):
        policy.validate(ROOT)

    def test_word_correction_is_not_a_rejection_reason(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source, first = current_release_fixture(root)
            source = replace_first_message(
                source, first, 'Corrigido erro nas verificações de atualização')
            (root / 'lib/services/update_news_catalog.dart').write_text(source, 'utf8')
            policy.validate(root)

    def test_reject_old_release_or_empty_news(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source, first = current_release_fixture(root)
            path = root / 'lib/services/update_news_catalog.dart'
            build = re.search(r'(?m)^version:\s*\d+\.\d+\.\d+\+(\d+)\s*$',
                              (root / 'pubspec.yaml').read_text('utf8'))
            self.assertIsNotNone(build)
            outdated = source.replace(f'build: {build.group(1)}', 'build: 300', 1)
            self.assertNotEqual(outdated, source)
            path.write_text(outdated, 'utf8')
            with self.assertRaisesRegex(ValueError, 'versão atual'):
                policy.validate(root)

            # Mutate an actual message in the current catalog, not a hardcoded
            # sentence that may disappear when the app version changes.
            path.write_text(replace_first_message(source, first, 'TODO'), 'utf8')
            with self.assertRaisesRegex(ValueError, 'mensagens'):
                policy.validate(root)

            path.write_text(replace_first_message(source, first, ''), 'utf8')
            with self.assertRaisesRegex(ValueError, 'mensagens'):
                policy.validate(root)


if __name__ == '__main__':
    unittest.main()
