import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../authentication/domain/services/credentials_policy.dart';
import '../../../authentication/presentation/widgets/auth_widgets.dart';
import '../bloc/account/account_bloc.dart';
import '../messages/settings_messages.dart';

/// Pede a senha e gera uma nova chave de recuperacao pelo [AccountBloc] de quem chama.
///
/// O dialogo fica aberto enquanto o servidor confere a senha: a recusa aparece no campo, sem
/// perder o que foi digitado, e o dialogo so fecha (com verdadeiro) quando a chave nova
/// existe. A chave fica no estado do BLoC para a tela mostrar em seguida.
Future<bool> showRecoveryKeyPrompt(BuildContext context) async {
  final AccountBloc bloc = context.read<AccountBloc>();
  final bool? generated = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return BlocProvider<AccountBloc>.value(value: bloc, child: const _RecoveryKeyPrompt());
    },
  );
  return generated ?? false;
}

class _RecoveryKeyPrompt extends StatefulWidget {
  const _RecoveryKeyPrompt();

  @override
  State<_RecoveryKeyPrompt> createState() => _RecoveryKeyPromptState();
}

class _RecoveryKeyPromptState extends State<_RecoveryKeyPrompt> {
  final TextEditingController _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final String? error = CredentialsPolicy.enteredPasswordError(_password.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    context.read<AccountBloc>().add(AccountRecoveryKeyRequested(_password.text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountBloc, AccountState>(
      listenWhen: (AccountState previous, AccountState current) {
        return current.command == AccountCommand.recoveryKey && previous.action != current.action;
      },
      listener: (BuildContext context, AccountState state) {
        switch (state.action) {
          case ActionSucceeded():
            Navigator.of(context).pop(true);
          case ActionFailed(:final failure):
            setState(() => _error = passwordConfirmationErrorFor(failure));
          case ActionIdle() || ActionRunning():
            break;
        }
      },
      builder: (BuildContext context, AccountState state) {
        final bool busy =
            state.command == AccountCommand.recoveryKey && state.action is ActionRunning;
        return FormDialogFrame(
          icon: AppIcons.key,
          title: 'Gerar nova chave?',
          message:
              'Use quando a chave atual se perdeu ou alguém a viu. Confirme a senha '
              'administrativa para continuar.',
          consequence: 'A chave atual deixa de valer assim que a nova for gerada.',
          confirmLabel: 'Gerar nova chave',
          busy: busy,
          onConfirm: _submit,
          onCancel: () => Navigator.of(context).pop(false),
          field: AppPasswordField(
            controller: _password,
            autofocus: true,
            enabled: !busy,
            errorText: _error,
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        );
      },
    );
  }
}
