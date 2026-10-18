part of 'multi_camera_screen.dart';

extension _CameraEditorActions on _MultiCameraScreenState {
  Future<CameraEndpoint?> _showCameraEditor({
    required CameraEndpointType type,
    CameraEndpoint? existing,
    String? initialName,
    String? initialAddress,
  }) async {
    final isRtsp = type == CameraEndpointType.rtsp;
    final isMinha = MinhaCameraLiveUrl.isValid(existing?.address);
    final sourceTitle = isRtsp ? 'Câmera RTSP' : 'Celular transmissor';
    final sourceDescription = isRtsp
        ? 'Conecta uma câmera IP ou DVR pela URL RTSP.'
        : 'Recebe a imagem enviada por outro celular na mesma rede.';
    final previousUri = isRtsp ? Uri.tryParse(existing?.address ?? '') : null;
    final previousCredentials = previousUri?.userInfo ?? '';
    final credentialParts = previousCredentials.split(':');
    final username = TextEditingController(text: previousCredentials.isNotEmpty
        ? Uri.decodeComponent(credentialParts.first) : 'admin');
    final password = TextEditingController(text: credentialParts.length >= 2
        ? Uri.decodeComponent(credentialParts.skip(1).join(':')) : '');
    final name = TextEditingController(
      text: existing?.name ?? initialName ?? (isRtsp ? 'Câmera RTSP' : 'Câmera remota'),
    );
    final safeAddress = previousUri?.replace(userInfo: '').toString();
    final address = TextEditingController(text: safeAddress ?? initialAddress ?? existing?.address ?? '');
    bool passwordVisible = false;
    final key = TextEditingController(text: existing?.accessKey ?? '');
    String? error;
    bool softwareDecoding = existing?.rtspSoftwareDecoding ?? false;

    final result = await showDialog<CameraEndpoint>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          title: Text(
            existing == null
                ? (isRtsp ? 'Adicionar câmera RTSP' : 'Adicionar celular remoto')
                : 'Editar ${existing.name}',
          ),
          content: SizedBox(
            width: (MediaQuery.sizeOf(dialogContext).width - 72).clamp(160.0, 510.0).toDouble(),
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogContext)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isRtsp
                            ? Icons.router_outlined
                            : Icons.phone_android_rounded,
                        color: Theme.of(dialogContext).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sourceTitle,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(sourceDescription),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome da câmera'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: address,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: isRtsp ? 'URL RTSP' : 'Endereço local',
                    hintText: isRtsp
                        ? 'rtsp://192.168.1.20/stream'
                        : 'http://192.168.1.10:8765/live/TOKEN',
                  ),
                ),
                if (isRtsp) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: username,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Usuario RTSP',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: password,
                    obscureText: !passwordVisible,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Senha RTSP',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: passwordVisible ? 'Ocultar senha' : 'Mostrar senha',
                        icon: Icon(passwordVisible ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setDialogState(() => passwordVisible = !passwordVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('A senha sera protegida no cadastro. A descoberta ONVIF nao confirma o caminho do stream RTSP.',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compatibilidade (decodificação por software)'),
                    subtitle: const Text(
                      'Teste se o vídeo fechar o app. Pode usar mais CPU e bateria.',
                    ),
                    value: softwareDecoding,
                    onChanged: (value) => setDialogState(() => softwareDecoding = value),
                  ),
                ],
                if (type == CameraEndpointType.remotePhone) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: key,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Chave (não precisa para URL /live/)',
                      helperText: isMinha ? 'A chave já está incluída na URL.' : null,
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ],
            ),
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = address.text.trim();
                final uri = Uri.tryParse(value);
                final usernameValue = username.text.trim();
                final passwordValue = password.text;
                final validRtsp = isRtsp &&
                    uri != null &&
                    uri.scheme.toLowerCase() == 'rtsp' &&
                    uri.host.isNotEmpty &&
                    uri.userInfo.isEmpty && uri.path.isNotEmpty && uri.path != '/';
                final minha = MinhaCameraLiveUrl.parse(value);
                final validRemote = !isRtsp &&
                    (minha != null || (uri != null &&
                    (uri.scheme == 'http' || uri.scheme == 'https') &&
                    uri.host.isNotEmpty &&
                    key.text.trim().isNotEmpty));
                if (!(validRtsp || validRemote)) {
                  setDialogState(() {
                    error = isRtsp
                        ? 'Informe uma URL RTSP com caminho de video (ex.: /stream1).'
                        : 'Informe uma URL /live/ privada ou endereço HTTP com chave.';
                  });
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  CameraEndpoint(
                    id: existing?.id ??
                        'cam_${DateTime.now().microsecondsSinceEpoch}',
                    name: name.text.trim().isEmpty
                        ? (isRtsp ? 'Câmera RTSP' : 'Câmera remota')
                        : name.text.trim(),
                    type: type,
                    address: isRtsp && uri != null && passwordValue.isNotEmpty
                        ? uri.replace(userInfo: '$usernameValue:$passwordValue').toString()
                        : value,
                    accessKey: type == CameraEndpointType.remotePhone
                        ? (minha?.pathSegments.last ?? key.text.trim())
                        : null,
                    enabled: existing?.enabled ?? true,
                    rtspSoftwareDecoding: isRtsp && softwareDecoding,
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    address.dispose();
    key.dispose();
    username.dispose();
    password.dispose();
    return result;
  }

}
