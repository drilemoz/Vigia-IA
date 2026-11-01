import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/gemini_map_service.dart';

/// Mesma convenção do Uai Cortes: chave local, mascarar, salvar e testar.
class GeminiMapSettingsScreen extends StatefulWidget {
  const GeminiMapSettingsScreen({super.key});
  @override
  State<GeminiMapSettingsScreen> createState() => _GeminiMapSettingsScreenState();
}

class _GeminiMapSettingsScreenState extends State<GeminiMapSettingsScreen> {
  final _service = GeminiMapService.instance;
  final _controller = TextEditingController();
  String _masked = '';
  String _model = GeminiMapService.defaultModel;
  String? _result;
  bool _configured = false;
  bool _obscure = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final status = await _service.status();
      final model = await _service.savedModel();
      if (!mounted) return;
      setState(() { _masked = status.masked; _configured = status.configured; _model = model; });
    } catch (_) {
      if (mounted) setState(() => _result = 'Não foi possível consultar a chave protegida.');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _execute(() async {
      if (_controller.text.trim().isEmpty) {
        throw const FormatException('Cole uma chave antes de salvar.');
      }
      final status = await _service.save(_controller.text);
      _controller.clear();
      _obscure = true;
      _masked = status.masked;
      _configured = status.configured;
      return 'Chave salva criptografada no aparelho.';
    });
  }

  Future<void> _execute(Future<String> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _result = null; });
    try {
      final message = await action();
      if (mounted) setState(() => _result = message);
    } on GeminiMapException catch (error) {
      if (mounted) setState(() => _result = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _result = error.message);
    } catch (_) {
      if (mounted) setState(() => _result = 'Operação não concluída. Confira a conexão e a chave.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remover chave Gemini?'),
        content: const Text('O Vigia Maps continuará funcionando sem IA online.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Remover')),
        ],
      ),
    );
    if (yes != true) return;
    await _execute(() async {
      await _service.save('');
      _controller.clear();
      _obscure = true;
      _masked = '';
      _configured = false;
      return 'Chave removida deste aparelho.';
    });
  }

  Future<void> _reveal() async {
    if (!_obscure) {
      setState(() => _obscure = true);
      return;
    }
    await _execute(() async {
      if (_controller.text.isEmpty && _configured) {
        _controller.text = await _service.reveal() ?? '';
      }
      _obscure = false;
      return 'Chave visível até você ocultar ou sair da tela.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini no Vigia Maps')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Assistência inteligente (opcional)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('A IA interpreta perguntas sobre lugares. O mapa confirma os destinos pelo índice local ou OpenStreetMap. Sem chave ou internet, a navegação normal continua funcionando.'),
              const SizedBox(height: 8),
              Text(_configured ? 'Chave configurada: $_masked' : 'Nenhuma chave Gemini cadastrada.'),
            ]),
          )),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            enabled: !_busy,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(
              labelText: 'Chave da API Gemini',
              hintText: 'Cole sua chave do Google AI Studio',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Mostrar chave' : 'Ocultar chave',
                onPressed: _busy ? null : _reveal,
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_outlined), label: const Text('Salvar')),
            OutlinedButton.icon(onPressed: _busy ? null : () async {
              final clip = await Clipboard.getData(Clipboard.kTextPlain);
              if (clip?.text == null || !mounted) return;
              setState(() => _controller.text = clip!.text!);
            }, icon: const Icon(Icons.content_paste_rounded), label: const Text('Colar')),
            OutlinedButton.icon(onPressed: _busy ? null : () => _execute(() async {
              final value = _controller.text.isNotEmpty ? _controller.text : await _service.reveal();
              if (value == null || value.isEmpty) throw const FormatException('Nenhuma chave para copiar.');
              await Clipboard.setData(ClipboardData(text: value));
              return 'Chave copiada. Limpe a área de transferência após usar.';
            }), icon: const Icon(Icons.copy_rounded), label: const Text('Copiar')),
            TextButton.icon(onPressed: _busy || !_configured ? null : _remove,
              icon: const Icon(Icons.delete_outline_rounded), label: const Text('Remover')),
          ]),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _model,
            decoration: const InputDecoration(labelText: 'Modelo para busca e teste', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: GeminiMapService.defaultModel, child: Text('Flash-Lite · econômico')),
              DropdownMenuItem(value: GeminiMapService.advancedModel, child: Text('Flash · avançado')),
            ],
            onChanged: _busy ? null : (value) { if (value != null) { setState(() => _model = value); _execute(() async { await _service.saveModel(value); return 'Modelo salvo.'; }); } },
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _busy || !_configured ? null : () => _execute(() => _service.test(model: _model)),
            icon: const Icon(Icons.network_check_rounded),
            label: const Text('Testar conexão Gemini'),
          ),
          if (_busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          if (_result != null) Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(_result!))),
          const SizedBox(height: 12),
          const Text('Atenção: chamadas online podem consumir cota ou gerar cobrança. Somente as perguntas enviadas voluntariamente são transmitidas ao Gemini. Nunca inclua segredos ou informações sensíveis nas consultas.'),
        ],
      ),
    );
  }
}
