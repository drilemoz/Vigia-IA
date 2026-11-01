import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/native_platform_service.dart';

enum ApiHelpProvider { gemini, googleMaps, stadia, geoapify, openrouteservice, openMeteo }

class ApiHelpInfo {
  const ApiHelpInfo(this.name, this.description, this.steps, this.url,
      {required this.keyRequired, this.warning = ''});
  final String name;
  final String description;
  final List<String> steps;
  final String url;
  final bool keyRequired;
  final String warning;
}

/// Instruções embutidas: consultáveis sem internet; abrir links é opcional.
const Map<ApiHelpProvider, ApiHelpInfo> apiHelp = {
  ApiHelpProvider.gemini: ApiHelpInfo(
    'Google Gemini', 'Interpretação de pesquisas de lugares.', [
      'Abra o Google AI Studio e entre em sua conta.',
      'Crie ou selecione um projeto e gere uma API key.',
      'Copie a chave, volte ao Vigia IA, cole, salve e teste.',
    ], 'https://aistudio.google.com/apikey', keyRequired: true,
    warning: 'A disponibilidade do plano gratuito e as cotas dependem da sua conta e do modelo escolhido.'),
  ApiHelpProvider.googleMaps: ApiHelpInfo(
    'Google Maps Platform', 'Mapa Google opcional no Vigia Maps.', [
      'Crie um projeto no Google Cloud Console e configure faturamento.',
      'Ative Maps SDK for Android e crie uma chave de API.',
      'Restrinja a chave ao pacote com.vigiaia.app e ao SHA-1 da assinatura do APK.',
      'Cole e salve. Confirme abrindo o mapa Google; um teste HTTP genérico não valida a restrição Android.',
    ], 'https://console.cloud.google.com/google/maps-apis', keyRequired: true,
    warning: 'O Google exige faturamento habilitado. Verifique os preços e limites na conta; não é uma API sem risco de cobrança.'),
  ApiHelpProvider.stadia: ApiHelpInfo(
    'Stadia Maps', 'Downloads de mapas autorizados e controle local de créditos.', [
      'Crie sua conta ou entre no painel Stadia Maps.',
      'Abra API Keys e gere uma chave conforme seu plano.',
      'Cole, salve e use o teste na tela de gerenciamento de mapas offline.',
    ], 'https://client.stadiamaps.com/dashboard/', keyRequired: true,
    warning: 'Verifique os termos de cache, uso não comercial e limites de créditos.'),
  ApiHelpProvider.geoapify: ApiHelpInfo(
    'Geoapify', 'Pesquisa de destinos, endereços e POIs (integração de busca prevista).', [
      'Abra o painel Geoapify e crie uma conta gratuita.',
      'Crie um projeto e acesse API Keys.',
      'Copie a chave e configure nesta central.',
      'Use Testar para validar a conexão de geocodificação.',
    ], 'https://myprojects.geoapify.com/', keyRequired: true,
    warning: 'Teste e consultas consomem créditos da cota gratuita. Sem chave, os provedores atuais continuam disponíveis.'),
  ApiHelpProvider.openrouteservice: ApiHelpInfo(
    'OpenRouteService · HeiGIT', 'Rotas ciclísticas e dados de elevação (integração prevista).', [
      'Crie uma conta no painel oficial HeiGIT.',
      'Acesse o painel de API keys e crie ou copie uma chave gratuita.',
      'Cole, salve e teste aqui.',
      'A API usa api.heigit.org/openrouteservice, não a URL antiga.',
    ], 'https://account.heigit.org/', keyRequired: true,
    warning: 'A cota e as condições de uso dependem da conta. Testar faz uma consulta curta de bicicleta.'),
  ApiHelpProvider.openMeteo: ApiHelpInfo(
    'Open-Meteo', 'Previsão meteorológica já utilizada no Vigia Maps.', [
      'Nenhum cadastro ou chave é necessário no endpoint público de uso não comercial.',
      'O Vigia IA já consulta clima e usa cache local.',
      'A ampliação de previsão e radiação solar será feita em uma próxima versão.',
    ], 'https://open-meteo.com/en/docs', keyRequired: false,
    warning: 'Acesso online requer internet e respeito aos limites e à licença; uso comercial exige avaliar outros planos.'),
};

Future<void> showApiServiceHelp(BuildContext context, ApiHelpProvider provider) async {
  final data = apiHelp[provider]!;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.help_outline_rounded),
        const SizedBox(width: 8),
        Expanded(child: Text(data.name)),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.description),
            const SizedBox(height: 10),
            Text(data.keyRequired ? 'Como obter e configurar' : 'Funcionamento sem chave',
              style: Theme.of(dialogContext).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (var i = 0; i < data.steps.length; i++)
              Padding(padding: const EdgeInsets.only(bottom: 7),
                child: Text('${i + 1}. ${data.steps[i]}')),
            if (data.warning.isNotEmpty) ...[
              const Divider(),
              Text(data.warning, style: Theme.of(dialogContext).textTheme.bodySmall),
            ],
          ],
        )),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fechar')),
        if (provider == ApiHelpProvider.openMeteo)
          OutlinedButton.icon(
            onPressed: () async {
              final status = await testOpenMeteoConnection();
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(status)));
              }
            },
            icon: const Icon(Icons.network_check_outlined),
            label: const Text('Testar previsão'),
          ),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.open_in_new_rounded),
          onPressed: () async {
            final opened = await NativePlatformService.instance.openExternalUrl(data.url);
            if (!opened) {
              await Clipboard.setData(ClipboardData(text: data.url));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Link oficial copiado.')));
              }
            }
          },
          label: const Text('Site oficial'),
        ),
      ],
    ),
  );
}

Future<void> showApiServiceGuide(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.77,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text('Como conseguir todas as APIs',
              style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('As instruções funcionam sem internet. Os links oficiais precisam de conexão. Todas as APIs são opcionais.'),
            const SizedBox(height: 12),
            for (final entry in apiHelp.entries)
              Card(child: ListTile(
                leading: Icon(entry.value.keyRequired
                    ? Icons.key_outlined : Icons.cloud_outlined),
                title: Text(entry.value.name),
                subtitle: Text(entry.value.keyRequired
                    ? 'Chave própria · veja gratuidade e limites'
                    : 'Não precisa de chave para uso não comercial'),
                trailing: const Icon(Icons.help_outline_rounded),
                onTap: () => showApiServiceHelp(sheetContext, entry.key),
              )),
          ],
        ),
      ),
    ),
  );
}

/// Teste de conectividade público: uma única consulta sem coordenadas pessoais.
Future<String> testOpenMeteoConnection() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '-15.79', 'longitude': '-47.88',
      'hourly': 'temperature_2m', 'forecast_days': '1',
    });
    final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 15));
    final code = response.statusCode;
    await response.drain<void>().timeout(const Duration(seconds: 10));
    return code == 200 ? 'Open-Meteo respondeu (HTTP 200).'
        : 'Open-Meteo respondeu HTTP $code. Consulte limites ou tente novamente.';
  } on TimeoutException {
    return 'Tempo de teste esgotado.';
  } on SocketException {
    return 'Sem internet para consultar Open-Meteo.';
  } catch (_) {
    return 'Não foi possível verificar Open-Meteo.';
  } finally {
    client.close(force: true);
  }
}
