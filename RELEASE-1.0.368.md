# Vigia IA 1.0.368+368 — Próximos pontos mais alto

## Alteração visual

- Aumentada a altura do diálogo Próximos pontos de 420 para 570 dp quando a lista está vazia ou há erro de consulta.
- Quando há pontos ou uma consulta em andamento, a altura passa de 650 para 690 dp.
- Ampliado o teto proporcional de 86% para 92% do espaço vertical disponível. O componente de diálogo existente ainda limita a altura para telas menores e áreas de sistema.

## Não alterado

- GPS, localização, servidores de pontos, filtros, arquivos offline, atualização via GitHub e permissões.
- Nenhum download automático, mudança de dados ou migração de banco.

## Validação

- Teste estrutural `tool/test_nearby_panel_height_368.py`; verificações de versão e regressões existentes. Flutter Analyze, Flutter Test e APK ainda dependem do CI Android.
