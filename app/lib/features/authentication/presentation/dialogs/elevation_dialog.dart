import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/services/i_elevation_prompter.dart';
import '../bloc/elevation/elevation_bloc.dart';
import '../widgets/auth_widgets.dart';

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
/// senha foi aceita e com falso quando a pessoa desiste (a operacao nao acontece).
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
    return BlocConsumer<ElevationBloc, ElevationState>(
      listenWhen: (ElevationState previous, ElevationState current) {
        return previous.status != current.status && current.status == FormStatus.succeeded;
      },
      listener: (BuildContext context, ElevationState state) => Navigator.of(context).pop(true),
      builder: (BuildContext context, ElevationState state) {
        final bool busy = state.status != FormStatus.editing;
        return FormDialogFrame(
          icon: AppIcons.lock,
          title: 'Confirme sua senha',
          message:
              'Por segurança, mudanças nas regras e nos dados da conta pedem a senha '
              'administrativa de novo.',
          consequence: 'Se você cancelar, nada é alterado.',
          busy: busy,
          confirmLabel: 'Confirmar',
          onConfirm: _confirm,
          onCancel: () => Navigator.of(context).pop(false),
          field: AppPasswordField(
            controller: _password,
            autofocus: true,
            enabled: !busy,
            errorText: state.error,
            onSubmitted: (_) => _confirm(),
          ),
        );
      },
    );
  }
}
