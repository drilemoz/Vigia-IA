# Vigia IA 1.0.341+341 — Planejamento unificado de cicloviagem

Base: 1.0.340+340, mantendo MBTiles, MapLibre 3D, câmeras e navegação existentes.

- **Mesmo editor:** o cartão Planejamento da tela inicial e o botão Plano de Mapas usam `TripPlanningScreen`. Mapas fornece a geometria já calculada (`BikeTripEditorBridge`), sem recálculo online nem GPS adicional.
- **Mesmo armazenamento:** `PlannedBikeTripService.upsert` é chamado ao salvar no editor ou na prévia de Mapas, com preservação das demais viagens (máximo 40). O arquivo da última rota `vigia_saved_route.json` permanece compatível; última prévia Bike antiga pode ser importada para a biblioteca quando o editor abre, com verificação de duplicados.
- **Preferências:** velocidade, horas diárias e equilíbrio de etapas seguem `MapViewSettingsService`. Saída, frequência/duração de pausas e almoço ficam persistidos em `BikeTripScheduleSettingsService`. `PlannedBikeTrip` grava `balanceDays` e `forceLunch`; registros antigos recebem padrões conservadores.
- **Navegação e offline:** ao escolher "Abrir prévia nos Mapas", a prévia aparece diretamente no mapa. Ao voltar do editor de Mapas, a rota de prévia é atualizada; navegação ativa mantém a geometria enquanto atualiza estimativas e ajustes. Dados do traçado persistem offline, mas **não** criam roteamento offline nem tiles MBTiles.
- **Restrições:** mudanças de caminho ativo só ocorrem via controles existentes de seleção/navegação; localidades para pernoite continuam aproximações não verificadas. A origem de mapa é identificada como primeiro ponto da geometria, não como GPS medido.
- **Validação:** `tool/test_unified_bike_planning_341.py` e `test/bike_trip_unified_flow_test.dart`; ver relatório `VALIDATION-1.0.341.md`. Build e validação física pendentes.
