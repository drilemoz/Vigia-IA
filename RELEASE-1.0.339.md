# Vigia IA 1.0.339+339 — Correções de mapas offline e 3D

- Base: 1.0.338+338. Mantidos módulos de câmera, IA, serviços e APIs, roteamento e seleção de mapa offline/online.
- MBTiles: o TileLayer não encerra o SQLite em sua desmontagem. A tela possui a conexão até trocar de pacote ou ser fechada; após liberação, ela aguarda 45 s para leituras de tiles pendentes.
- A exclusão do pacote é refletida na lista antes de remover seu arquivo; a remoção física aguarda todas as conexões registradas. Arquivos órfãos MBTiles são eliminados na inicialização seguinte se o aplicativo for encerrado nesse intervalo.
- O MapLibre Android usa TextureView/TLHC com fallback HC. O renderer deixa de iniciar invisível sob AnimatedOpacity, e notificações de download/estado da rede deixam de redefinir seu estado indevidamente.
- As mudanças mitigam os erros relatados na versão 1.0.337 (SQLite fechado, PlatformView e ANR), mas exigem confirmação no dispositivo com APK 1.0.339. Não há garantia de resolução do ANR ou erro nativo sem teste real.
