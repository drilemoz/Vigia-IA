# Vigia IA 1.0.363+363 — Verificação de preparação offline

- Novo botão **Verificar preparação offline** no Planejamento: executa conferência local dos arquivos MBTiles, limites declarados, pontos salvos e paradas/pousos sem confirmação manual.
- Mostra amostras da rota dentro ou fora dos limites, cobertura desconhecida para MBTiles sem bounds, arquivos ausentes/zerados e etapas possivelmente afetadas.
- Compara os pontos regionais efetivamente salvos à geometria (até 2,5 km em linha reta), sem sugerir serviços inexistentes, e distingue localidades já persistidas dentro da viagem.
- Diagnóstico sob demanda, sem internet, GPS, permissões extras nem operações em segundo plano; não remove nem corrige arquivos automaticamente.
- Atenção: **limites geográficos não garantem tiles presentes em todos os zooms**; acesso pela estrada, água e pernoite exigem conferência real.
- Flutter Analyze/Test/compilação APK: pendentes de GitHub Actions.
