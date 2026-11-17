import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../shared/widgets/form_widgets.dart';

/// Abre a folha para informar o endereco do servidor. Devolve verdadeiro se um endereco
/// valido foi gravado.
Future<bool> showServerSheet(BuildContext context) async {
  final bool? saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => const _ServerSheet(),
  );
  return saved ?? false;
}

class _ServerSheet extends ConsumerStatefulWidget {
  const _ServerSheet();

  @override
  ConsumerState<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends ConsumerState<_ServerSheet> {
  late final TextEditingController _controller;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(serverUrlProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String url = _controller.text.trim();
    if (!AppConfig.isAcceptableServerUrl(url)) {
      setState(() {
        _error = AppConfig.isReleaseBuild
            ? 'Informe um endereço completo que comece com https://'
            : 'Informe um endereço completo, por exemplo https://controle.exemplo.com';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final String previous = ref.read(serverUrlProvider);
    try {
      // Grava e confere se ha um servidor ParentaLynx respondendo nesse endereco.
      await ref.read(serverUrlProvider.notifier).set(url);
      await ref.read(apiClientProvider).get('/v1/meta', auth: ApiAuth.none);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      await ref.read(serverUrlProvider.notifier).set(previous);
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Não foi possível falar com o servidor nesse endereço. '
              '${toFailure(error).message}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Servidor', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Endereço do servidor ParentaLynx da sua família. Os dois aparelhos precisam usar '
            'o mesmo endereço.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Endereço',
              hintText: 'https://controle.exemplo.com',
              errorText: _error,
              errorMaxLines: 4,
              prefixIcon: const Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          BusyButton(label: 'Salvar', busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}
