# Vigia IA 1.0.322+322 · Restauração de navegação e investigação de encerramentos

## Mapas: regressões corrigidas

- Ao selecionar destino e modo Bicicleta, o diálogo de **velocidade média manual**, **horas pedalando por dia**, uso opcional de média do histórico e equilíbrio de dias volta a abrir antes do cálculo da prévia. Cancelar não inicia a rota.
- O cartão de prévia mantém alternativas, distância, duração e `Editar ritmo do pedal` para ajustes adicionais.
- Ao tocar em Iniciar, o painel de navegação inicia **expandido** com instruções, distância, tempo, andamento e opções de rotas; a pessoa ainda pode minimizá-lo. O painel deixa de ser ocultado simplesmente pelo modo Foco.
- Não foi adicionado algoritmo de navegação offline: calcular novas rotas ainda requer internet; rotas previamente salvas podem ser consultadas offline.

## Diagnóstico automático

- Grava nomes fixos de ações dos principais menus de Mapas e do fluxo de prévia/navegação, sem nomes digitados, senhas, credenciais nem posições GPS.
- Mantém amostras a cada 10 s em primeiro plano ou com serviço; acrescenta tentativa de coleta a cada 30 s em cache/segundo plano, sem criar wakelock, com 60 amostras limitadas. O Android pode suspender processo cacheado, impedindo coletas.
- Sinais de `onTrimMemory >= 60` disparam amostra antecipada com limite de frequência, sem bloquear a callback do sistema.
- Inclui PSS do processo, estado do processo e texto descritivo de ApplicationExitInfo quando disponível (sanitizado), com aviso explícito que reason=9 não distingue CPU/memória/thermal.
- Exportador marca se a saída Android ocorreu até 2 min após tentativa RTSP; não presume que o estágio RTSP antigo foi a causa de uma saída posterior.
- Retenção nativa continua limitada a 120 eventos e não há upload automático.

## Validação e limitações

Testes Python estruturais e verificação de fontes incluídos; Flutter Analyze, Flutter Test, compilação Android e reprodução em aparelho devem ser verificados no CI/aparelho. Não se atribui causa definitiva ao VLC ou Mapas sem rastros nativos adicionais.
