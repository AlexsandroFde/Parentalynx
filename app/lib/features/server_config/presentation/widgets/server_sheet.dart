import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../shared/design_system/design_system.dart';
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
    return BlocConsumer<ServerConfigBloc, ServerConfigState>(
      listenWhen: (ServerConfigState previous, ServerConfigState current) {
        return previous.status != current.status && current.status == FormStatus.succeeded;
      },
      listener: (BuildContext context, ServerConfigState state) => Navigator.of(context).pop(true),
      builder: (BuildContext context, ServerConfigState state) {
        final bool busy = state.status.isSubmitting;
        return AppSheetFrame(
          title: 'Servidor',
          subtitle:
              'Endereço do servidor ParentaLynx da sua família. O seu celular e o da criança '
              'precisam usar o mesmo endereço.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                controller: _controller,
                label: 'Endereço do servidor',
                isRequired: true,
                hint: 'https://controle.exemplo.com',
                // Enquanto confere, o texto de apoio diz o que esta acontecendo.
                helper: busy
                    ? 'Conferindo se há um servidor ParentaLynx nesse endereço…'
                    : 'Endereço completo, começando com https://. Quem instalou o servidor '
                          'informa o endereço.',
                errorText: state.error,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton.primary(label: 'Salvar', busy: busy, expand: true, onPressed: _save),
            ],
          ),
        );
      },
    );
  }
}
