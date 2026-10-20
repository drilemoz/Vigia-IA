# Vigia IA 1.0.312+312

## Desempenho A3 e diagnóstico local

- Novo cartão na tela Transmissão: CPU do processo Vigia IA (% da capacidade dos núcleos), memória do aplicativo medida por PSS e RAM livre/total do aparelho.
- Amostragem pela telemetria Android já existente, a cada 6 segundos, apenas enquanto a tela está visível. Sem monitoramento oculto ou consultas extras à câmera.
- Durante a gravação MP4 no A3, JPEG/H.264 usado pela rede recebe prioridade menor: com visualizador ativo, até 5 atualizações por segundo; sem visualizador, uma atualização aproximada a cada 2,5 segundos para manter o endpoint.
- Corrigido o limite da câmera no modo Eco durante REC: Eco não reduz para 5 FPS por si só; os limites térmicos NORMAL/WARM/HOT continuam valendo.
- Mantidas as fotografias automáticas por mudança de cena (opcionais), a Galeria Remota e o gravador nativo H.264. O arquivo MP4 ainda depende do codificador e carga reais do Redmi A3.
- **Não** ativada gravação automática por mudança de cena com a bicicleta em movimento, porque o deslocamento faria o gravador permanecer ativo quase continuamente. Modo dashcam em segmentos com retenção circular é opção para futura implementação.
- Validação no aparelho e APK Release precisam ser confirmados pelo GitHub Actions.
