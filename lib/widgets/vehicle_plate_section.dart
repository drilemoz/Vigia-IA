import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/monitor_event.dart';
import '../services/event_history_service.dart';
import '../services/vehicle_plate_ocr_service.dart';

/// Detalhe de placa no Histórico; nunca roda OCR durante a câmera ao vivo.
class VehiclePlateSection extends StatefulWidget {
  const VehiclePlateSection({
    required this.event,
    required this.history,
    required this.onChanged,
    super.key,
  });

  final MonitorEvent event;
  final EventHistoryService history;
  final VoidCallback onChanged;

  @override
  State<VehiclePlateSection> createState() => _VehiclePlateSectionState();
}

class _VehiclePlateSectionState extends State<VehiclePlateSection> {
  final VehiclePlateOcrService _ocr = const VehiclePlateOcrService();
  late final TextEditingController _plateController;
  bool _scanning = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _plateController = TextEditingController(text: widget.event.plateText ?? '');
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final path = widget.event.snapshotPath;
    if (_scanning || path == null || path.isEmpty) return;
    setState(() {
      _scanning = true;
      _message = null;
    });
    try {
      final detected = await _ocr.scan(path, widget.event.box);
      if (!mounted) return;
      if (detected == null) {
        setState(() => _message =
            'Nenhuma placa brasileira legível. Aproxime a câmera ou digite manualmente.');
        return;
      }
      _plateController.text = detected;
      await widget.history.updatePlate(widget.event.id, detected);
      if (!mounted) return;
      setState(() => _message = 'Possível placa detectada. Confira os caracteres.');
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Não foi possível ler a imagem neste aparelho.');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _saveEdited() async {
    final value = BrazilianPlateText.normalize(_plateController.text.trim());
    if (value == null) {
      setState(() => _message = 'Informe uma placa antiga ou Mercosul válida.');
      return;
    }
    try {
      await widget.history.updatePlate(widget.event.id, value);
      if (!mounted) return;
      _plateController.text = value;
      setState(() => _message = 'Texto da placa salvo localmente.');
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Não foi possível salvar a placa.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.event.snapshotPath?.isNotEmpty == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Placa brasileira', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            'Leitura local sob demanda. Não consulta marca, modelo, dono ou cadastro oficial.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _plateController,
            onChanged: (_) => setState(() {}),
            maxLength: 8,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]'))],
            decoration: const InputDecoration(
              labelText: 'Placa (confira e corrija)',
              hintText: 'ABC1D23',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _scanning || !hasPhoto ? null : () => unawaited(_scan()),
                icon: _scanning
                    ? const SizedBox(height: 17, width: 17, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.document_scanner_outlined),
                label: const Text('Escanear placa'),
              ),
              OutlinedButton.icon(
                onPressed: _scanning ? null : () => unawaited(_saveEdited()),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar texto'),
              ),
              IconButton(
                tooltip: 'Copiar placa',
                onPressed: _plateController.text.trim().isEmpty
                    ? null
                    : () => Clipboard.setData(ClipboardData(text: _plateController.text.trim())),
                icon: const Icon(Icons.copy_outlined),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(_message!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
