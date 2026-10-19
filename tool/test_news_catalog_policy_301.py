import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_news_catalog_policy as policy

ROOT = Path(__file__).resolve().parents[1]


class NewsCatalogPolicy301Tests(unittest.TestCase):
    def test_current_news_accepts_descriptions_of_fixes(self):
        policy.validate(ROOT)

    def test_word_correction_is_not_a_rejection_reason(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'lib/services').mkdir(parents=True)
            (root / 'pubspec.yaml').write_text('version: 1.0.301+301\n', 'utf8')
            source = (ROOT / 'lib/services/update_news_catalog.dart').read_text('utf8')
            source = source.replace('Melhoradas as verificações de atualização',
                                    'Corrigido erro nas verificações de atualização')
            (root / 'lib/services/update_news_catalog.dart').write_text(source, 'utf8')
            policy.validate(root)

    def test_reject_old_release_or_empty_news(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'lib/services').mkdir(parents=True)
            (root / 'pubspec.yaml').write_text('version: 1.0.301+301\n', 'utf8')
            path = root / 'lib/services/update_news_catalog.dart'
            source = (ROOT / 'lib/services/update_news_catalog.dart').read_text('utf8')
            path.write_text(source.replace('build: 301', 'build: 300', 1), 'utf8')
            with self.assertRaisesRegex(ValueError, 'versão atual'):
                policy.validate(root)
            path.write_text(source.replace('Melhoradas as verificações de atualização para evitar bloqueios incorretos na geração do aplicativo.',
                                           'TODO'), 'utf8')
            with self.assertRaisesRegex(ValueError, 'mensagens'):
                policy.validate(root)


if __name__ == '__main__':
    unittest.main()
