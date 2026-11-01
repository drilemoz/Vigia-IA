import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/partner_api_key_service.dart';
import 'api_service_help.dart';

class PartnerApiKeyScreen extends StatefulWidget {
  const PartnerApiKeyScreen({super.key, required this.provider});
  final PartnerApiProvider provider;

  @override
  State<PartnerApiKeyScreen> createState() => _PartnerApiKeyScreenState();
}

class _PartnerApiKeyScreenState extends State<PartnerApiKeyScreen> {
  final _service = PartnerApiKeyService.instance;
  final _controller = TextEditingController();
  PartnerKeyStatus _status = const PartnerKeyStatus(configured: false, masked: '');
  bool _obscured = true;
  bool _busy = true;
  String? _message;

  String get _title => widget.provider == PartnerApiProvider.geoapify ? 'Geoapify' : 'OpenRouteService';
  ApiHelpProvider get _help => widget.provider == PartnerApiProvider.geoapify
      ? ApiHelpProvider.geoapify : ApiHelpProvider.openrouteservice;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final status = await _service.status(widget.provider);
      if (mounted) setState(() { _status = status; _busy = false; });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _message = 'Falha ao consultar a chave protegida.'; });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _operation(Future<String> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _message = null; });
    try {
      final message = await action();
      if (mounted) setState(() => _message = message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) setState(() => _message = 'Operação não concluída. Verifique o aparelho e tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _operation(() async {
    final problem = PartnerApiKeyService.validate(_controller.text);
    if (problem != null) throw FormatException(problem);
    final status = await _service.save(widget.provider, _controller.text);
    _controller.clear();
    _status = status;
    _obscured = true;
    return 'Chave salva de forma criptografada no aparelho.';
  });

  Future<void> _reveal() async {
    if (!_obscured) { setState(() => _obscured = true); return; }
    await _operation(() async {
      if (_controller.text.isEmpty && _status.configured) {
        _controller.text = await _service.reveal(widget.provider) ?? '';
      }
      _obscured = false;
      return 'Chave visível até ocultar ou fechar esta tela.';
    });
  }

  Future<void> _copy() => _operation(() async {
    final key = _controller.text.isNotEmpty
        ? _controller.text : await _service.reveal(widget.provider);
    if (key == null || key.isEmpty) return 'Nenhuma chave para copiar.';
    await Clipboard.setData(ClipboardData(text: key));
    return 'Chave copiada. Limpe a área de transferência após usar.';
  });

  Future<void> _paste() => _operation(() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = data?.text;
    if (clipboardText == null || clipboardText.isEmpty) return 'Área de transferência sem texto.';
    _controller.text = clipboardText;
    return 'Texto colado. Salve para proteger a chave.';
  });

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remover chave $_title?'),
        content: const Text('A navegação e os serviços offline continuarão disponíveis.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _operation(() async {
      _status = await _service.save(widget.provider, '');
      _controller.clear();
      _obscured = true;
      return 'Chave removida.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('API $_title'), actions: [
      IconButton(tooltip: 'Como obter?', icon: const Icon(Icons.help_outline_rounded),
        onPressed: () => showApiServiceHelp(context, _help)),
    ]),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_status.configured
                ? 'Chave protegida cadastrada: ${_status.masked}'
                : 'Sem chave cadastrada · opcional'),
            const SizedBox(height: 7),
            const Text('Nesta versão a chave pode ser configurada e testada. A integração nas buscas e rotas será adicionada nas próximas versões.'),
          ],
        ))),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          enabled: !_busy,
          obscureText: _obscured,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          decoration: InputDecoration(
            labelText: 'Chave de API',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _obscured ? 'Mostrar' : 'Ocultar',
              onPressed: _busy ? null : _reveal,
              icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined), label: const Text('Salvar')),
          OutlinedButton.icon(onPressed: _busy ? null : _paste,
            icon: const Icon(Icons.content_paste_rounded), label: const Text('Colar')),
          OutlinedButton.icon(onPressed: _busy ? null : _copy,
            icon: const Icon(Icons.copy_rounded), label: const Text('Copiar')),
          TextButton.icon(onPressed: _busy || !_status.configured ? null : _remove,
            icon: const Icon(Icons.delete_outline_rounded), label: const Text('Remover')),
        ]),
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          onPressed: _busy || !_status.configured
              ? null : () => _operation(() => _service.test(widget.provider)),
          icon: const Icon(Icons.network_check_rounded),
          label: const Text('Testar conexão'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) Card(child: Padding(
          padding: const EdgeInsets.all(12), child: Text(_message!))),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => showApiServiceHelp(context, _help),
          icon: const Icon(Icons.help_outline_rounded),
          label: const Text('Como obter a chave?'),
        ),
      ],
    ),
  );
}
