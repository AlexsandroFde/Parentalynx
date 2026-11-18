import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/presentation/widgets/recovery_key_view.dart';
import '../bloc/account/account_bloc.dart';
import '../bloc/change_password/change_password_bloc.dart';
import '../bloc/delete_account/delete_account_bloc.dart';
import '../dialogs/display_name_dialog.dart';
import '../dialogs/password_prompt_dialog.dart';
import '../messages/settings_messages.dart';
import 'change_password_page.dart';
import 'delete_account_page.dart';

/// Conta do responsavel: nome, senha administrativa, chave de recuperacao e exclusao.
///
/// Espera um [AccountBloc] acima na arvore. [changePasswordBloc] e [deleteAccountBloc] criam
/// os BLoCs das telas de troca de senha e de exclusao, abertas sobre o painel.
class AccountPage extends StatelessWidget {
  const AccountPage({required this.changePasswordBloc, required this.deleteAccountBloc, super.key});

  final ChangePasswordBloc Function() changePasswordBloc;
  final DeleteAccountBloc Function() deleteAccountBloc;

  Future<void> _editName(BuildContext context, GuardianAccount account) async {
    final String? name = await showDisplayNameDialog(context, initial: account.displayName);
    if (name == null || !context.mounted) {
      return;
    }
    context.read<AccountBloc>().add(AccountNameSubmitted(name));
  }

  Future<void> _newRecoveryKey(BuildContext context) async {
    final String? password = await showPasswordPrompt(
      context,
      title: 'Gerar nova chave',
      message:
          'A chave de recuperação atual deixa de valer. Confirme a senha administrativa para '
          'gerar outra.',
      confirmLabel: 'Gerar',
    );
    if (password == null || !context.mounted) {
      return;
    }
    context.read<AccountBloc>().add(AccountRecoveryKeyRequested(password));
  }

  void _onAction(BuildContext context, AccountState state) {
    switch (state.action) {
      case ActionSucceeded(:final String? message):
        if (message != null) {
          showAppSnackBar(context, message, tone: Tone.success);
        }
        final String? recoveryKey = state.recoveryKey;
        if (recoveryKey != null) {
          context.read<AccountBloc>().add(const AccountRecoveryKeyShown());
          unawaited(_showRecoveryKey(context, recoveryKey));
        }
      case ActionFailed(:final failure):
        if (state.command == AccountCommand.recoveryKey) {
          showAppSnackBar(context, passwordConfirmationErrorFor(failure), tone: Tone.danger);
        } else {
          showFailure(context, failure);
        }
      case ActionIdle() || ActionRunning():
        break;
    }
  }

  /// A chave nova aparece uma unica vez, em tela cheia, ate a pessoa confirmar que guardou.
  Future<void> _showRecoveryKey(BuildContext context, String recoveryKey) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext pageContext) => PopScope(
          canPop: false,
          child: RecoveryKeyView(
            recoveryKey: recoveryKey,
            onDone: () => Navigator.of(pageContext).pop(),
          ),
        ),
      ),
    );
  }

  void _openChangePassword(BuildContext context) {
    unawaited(
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => BlocProvider<ChangePasswordBloc>(
            create: (BuildContext context) => changePasswordBloc(),
            child: const ChangePasswordPage(),
          ),
        ),
      ),
    );
  }

  void _openDeleteAccount(BuildContext context) {
    unawaited(
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => BlocProvider<DeleteAccountBloc>(
            create: (BuildContext context) => deleteAccountBloc(),
            child: const DeleteAccountPage(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountBloc, AccountState>(
      listenWhen: (AccountState previous, AccountState current) {
        return previous.action != current.action;
      },
      listener: _onAction,
      buildWhen: (AccountState previous, AccountState current) {
        return previous.account != current.account;
      },
      builder: (BuildContext context, AccountState state) {
        final GuardianAccount? account = state.account;
        return Scaffold(
          appBar: AppBar(title: const Text('Conta e senha')),
          body: account == null
              ? const LoadingView()
              : PageBody(
                  children: <Widget>[
                    SectionCard(
                      title: 'Seus dados',
                      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
                      child: Column(
                        children: <Widget>[
                          ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: const Text('Nome'),
                            subtitle: Text(
                              account.displayName.isEmpty ? 'Não informado' : account.displayName,
                            ),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () => _editName(context, account),
                          ),
                          ListTile(
                            leading: const Icon(Icons.alternate_email),
                            title: const Text('E-mail'),
                            subtitle: Text(account.email),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SectionCard(
                      title: 'Senha administrativa',
                      subtitle:
                          'Protege as regras, os relatórios e a desvinculação no aparelho da '
                          'criança. Ao trocar, os outros aparelhos conectados à conta precisam '
                          'entrar de novo.',
                      child: OutlinedButton.icon(
                        onPressed: () => _openChangePassword(context),
                        icon: const Icon(Icons.password),
                        label: const Text('Trocar senha'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SectionCard(
                      title: 'Chave de recuperação',
                      subtitle:
                          'É a única forma de recuperar o acesso se você esquecer a senha. Se '
                          'perdeu a chave ou alguém a viu, gere outra.',
                      child: OutlinedButton.icon(
                        onPressed: () => _newRecoveryKey(context),
                        icon: const Icon(Icons.key_outlined),
                        label: const Text('Gerar nova chave'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SectionCard(
                      title: 'Excluir conta',
                      subtitle:
                          'Apaga a conta, os aparelhos vinculados, as regras e todo o histórico. '
                          'Os aparelhos das crianças deixam de ser controlados.',
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () => _openDeleteAccount(context),
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text('Excluir conta e dados'),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
