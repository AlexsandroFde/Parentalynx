import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../bloc/server_config_bloc.dart';

/// Abre a folha para informar o endereco do servidor. Devolve verdadeiro se um endereco
/// valido foi gravado.
///
/// Usa o [ServerConfigBloc] de quem chama, que precisa estar acima na arvore.
Future<bool> showServerSheet(BuildContext context) async {
  final ServerConfigBloc bloc = context.read<ServerConfigBloc>();
  final bool? saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) {
      return BlocProvider<ServerConfigBloc>.value(value: bloc, child: const _ServerSheet());
    },
  );
  return saved ?? false;
}

class _ServerSheet extends StatefulWidget {
  const _ServerSheet();

  @override
  State<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends State<_ServerSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<ServerConfigBloc>().state.address);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    context.read<ServerConfigBloc>().add(ServerAddressSubmitted(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return BlocConsumer<ServerConfigBloc, ServerConfigState>(
      listenWhen: (ServerConfigState previous, ServerConfigState current) {
        return previous.status != current.status && current.status == FormStatus.succeeded;
      },
      listener: (BuildContext context, ServerConfigState state) => Navigator.of(context).pop(true),
      builder: (BuildContext context, ServerConfigState state) {
        final bool busy = state.status.isSubmitting;
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
                'Endereço do servidor ParentaLynx da sua família. Os dois aparelhos precisam '
                'usar o mesmo endereço.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enabled: !busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Endereço',
                  hintText: 'https://controle.exemplo.com',
                  errorText: state.error,
                  errorMaxLines: 4,
                  prefixIcon: const Icon(Icons.dns_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              BusyButton(label: 'Salvar', busy: busy, onPressed: _save),
            ],
          ),
        );
      },
    );
  }
}
