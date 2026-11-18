import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../domain/services/i_elevation_prompter.dart';
import '../bloc/elevation/elevation_bloc.dart';

/// Implementacao de [IElevationPrompter] com um dialogo.
///
/// Mostra o dialogo pelo navegador raiz do app, entao funciona a partir de qualquer caso de
/// uso, sem depender da tela que disparou a operacao.
class DialogElevationPrompter implements IElevationPrompter {
  DialogElevationPrompter({required this._navigatorKey, required this._createBloc});

  final GlobalKey<NavigatorState> _navigatorKey;
  final ElevationBloc Function() _createBloc;

  @override
  Future<bool> requestElevation() async {
    final BuildContext? context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return false;
    }
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BlocProvider<ElevationBloc>(
          create: (BuildContext context) => _createBloc(),
          child: const ElevationDialog(),
        );
      },
    );
    return result ?? false;
  }
}

/// Pede a senha administrativa para liberar uma operacao. Fecha com verdadeiro quando a
/// senha foi aceita e com falso quando a pessoa desiste.
class ElevationDialog extends StatefulWidget {
  const ElevationDialog({super.key});

  @override
  State<ElevationDialog> createState() => _ElevationDialogState();
}

class _ElevationDialogState extends State<ElevationDialog> {
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _confirm() => context.read<ElevationBloc>().add(ElevationSubmitted(_password.text));

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return BlocConsumer<ElevationBloc, ElevationState>(
      listenWhen: (ElevationState previous, ElevationState current) {
        return previous.status != current.status && current.status == FormStatus.succeeded;
      },
      listener: (BuildContext context, ElevationState state) => Navigator.of(context).pop(true),
      builder: (BuildContext context, ElevationState state) {
        final bool busy = state.status != FormStatus.editing;
        return AlertDialog(
          icon: const Icon(Icons.lock_outline),
          title: const Text('Confirme sua senha'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Para alterar regras e dados, confirme a senha administrativa.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PasswordField(
                controller: _password,
                autofocus: true,
                enabled: !busy,
                errorText: state.error,
                onSubmitted: (_) => _confirm(),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            BusyButton(label: 'Confirmar', busy: busy, expand: false, onPressed: _confirm),
          ],
        );
      },
    );
  }
}
