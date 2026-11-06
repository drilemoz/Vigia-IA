# Vigia IA 1.0.360+360 — Planejamento: margem de subidas e avisos de etapa

- No Planejamento, a reserva opcional 0–20 minutos por 100 m de **subida realmente presente** no perfil altimétrico modifica apenas a simulação de tempo exibida. Zero preserva o cálculo anterior. Faltando altitude, não se extrapola tempo extra e o usuário recebe aviso.
- Alertas por etapa: duração acima do limite de pedal diário, horário de chegada posterior ao limite pessoal e local de pernoite não confirmado ou afastado da rota. O horário-limite é editável de 15h a 21h; **não é uma previsão de pôr do sol**.
- Os dados continuam salvos localmente com o planejamento e compatíveis com viagens antigas. Alternativas de rota indicam o ganho de elevação quando fornecido pelo provedor.
- O clima só é solicitado ao apertar **Consultar clima**; quando a reserva muda, previsões anteriormente consultadas são removidas, pois o horário de passagem muda. A nova consulta considera o cenário escolhido.
- A margem não é previsão real da sua velocidade, não estima vento ou bagagem e não recalcula os dias ou os caminhos offline. O novo código não liga GPS ou internet automaticamente.
- Flutter Analyze, Flutter Test e geração do APK deverão ser confirmados pelo workflow Android.
