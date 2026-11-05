import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_news_catalog_policy as policy

ROOT = Path(__file__).resolve().parents[1]


def _current_version():
    content = (ROOT / 'pubspec.yaml').read_text('utf8')
    match = re.search(r'(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', content)
    if match is None:
        raise AssertionError('Versão do pubspec ausente no teste de Novidades')
    return match.group(1), int(match.group(2))


def _replace_first_message(source: str, replacement: str):
    # Modifica a PRIMEIRA mensagem real da lista; não depende de versões antigas.
    updated, changes = re.subn(
        r"(changes:\s*<String>\s*\[\s*)'[^'\n]*'",
        lambda match: match.group(1) + "'" + replacement + "'",
        source,
        count=1,
    )
    if changes != 1 or updated == source:
        raise AssertionError('O teste precisa alterar uma mensagem real do catálogo')
    return updated


class NewsCatalogPolicy301Tests(unittest.TestCase):
    def test_current_news_accepts_descriptions_of_fixes(self):
        policy.validate(ROOT)

    def test_word_correction_is_not_a_rejection_reason(self):
        version, build = _current_version()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'lib/services').mkdir(parents=True)
            (root / 'pubspec.yaml').write_text(f'version: {version}+{build}\n', 'utf8')
            source = (ROOT / 'lib/services/update_news_catalog.dart').read_text('utf8')
            replacement = _replace_first_message(source, 'Corrigido erro nas verificações de atualização')
            (root / 'lib/services/update_news_catalog.dart').write_text(replacement, 'utf8')
            policy.validate(root)

    def test_reject_old_release_or_empty_news(self):
        version, build = _current_version()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'lib/services').mkdir(parents=True)
            (root / 'pubspec.yaml').write_text(f'version: {version}+{build}\n', 'utf8')
            path = root / 'lib/services/update_news_catalog.dart'
            source = (ROOT / 'lib/services/update_news_catalog.dart').read_text('utf8')
            current = f"AppBuildVersion(version: '{version}', build: {build})"
            self.assertIn(current, source)
            path.write_text(source.replace(current, f"AppBuildVersion(version: '{version}', build: 300)", 1), 'utf8')
            with self.assertRaisesRegex(ValueError, 'versão atual'):
                policy.validate(root)
            for invalid in ('TODO', '', 'placeholder'):
                with self.subTest(message=invalid):
                    path.write_text(_replace_first_message(source, invalid), 'utf8')
                    with self.assertRaisesRegex(ValueError, 'mensagens|Novidades'):
                        policy.validate(root)


if __name__ == '__main__':
    unittest.main()
