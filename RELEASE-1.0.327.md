# Vigia IA 1.0.327+327 — Central de Serviços e APIs

## Implementado

- Central opcional ampliada de três para seis provedores: Gemini, Google Maps Platform, Stadia Maps, Geoapify, OpenRouteService/HeiGIT e Open-Meteo.
- Ajuda `?` de cada serviço em pop-up com orientações offline, link oficial e aviso de limites/cobranças; guia geral de todas as APIs.
- Geoapify e OpenRouteService: nova tela para colar, salvar, revelar/ocultar, copiar, remover com confirmação e testar a conexão por demanda.
- Chaves novas criptografadas via Android Keystore AES-GCM, salvo em SharedPreferences privadas excluídas de backup em nuvem e de transferência do Android.
- Geoapify: teste explícito de Geocoding API. OpenRouteService: teste de rotas de bicicleta em `api.heigit.org/openrouteservice/v2/`.
- Google Maps: copiar, colar, mostrar chave salva apenas por ação e verificar configuração local; a validação real ocorre ao abrir o mapa pelo SDK Android.
- Open-Meteo continua sem chave no uso gratuito não comercial, com serviço meteorológico existente intacto e teste público de conexão sob demanda.

## Escopo futuro, **não** incluído neste build

- Geoapify na pesquisa real de destinos (previsto para 1.0.328).
- OpenRouteService no roteamento real e elevação (previsto para 1.0.329).
- Previsões estendidas, radiação e UV no Open-Meteo (previsto para 1.0.330).

## Segurança e autonomia

- Nenhuma chave é enviada automaticamente quando se abre a central. A consulta para teste exige toque explícito.
- A ausência/falha de API não interrompe mapas e navegação offline.
- Não inclui chaves reais. Não configura contas nem cobrança de provedores.
