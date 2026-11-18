import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/presentation/widgets/auth_widgets.dart';
import '../../../authentication/presentation/widgets/recovery_key_view.dart';
import '../bloc/account/account_bloc.dart';
import '../bloc/change_password/change_password_bloc.dart';
import '../bloc/delete_account/delete_account_bloc.dart';
import '../dialogs/display_name_dialog.dart';
import '../dialogs/password_prompt_dialog.dart';
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

  /// O pedido de senha cuida da recusa; com a chave gerada, ela aparece em tela cheia.
  Future<void> _newRecoveryKey(BuildContext context) async {
    final bool generated = await showRecoveryKeyPrompt(context);
    if (!generated || !context.mounted) {
      return;
    }
    final AccountBloc bloc = context.read<AccountBloc>();
    final String? recoveryKey = bloc.state.recoveryKey;
    if (recoveryKey == null) {
      return;
    }
    bloc.add(const AccountRecoveryKeyShown());
    await _showRecoveryKey(context, recoveryKey);
  }

  void _onAction(BuildContext context, AccountState state) {
    // A chave nova e tratada pelo proprio pedido de senha.
    if (state.command != AccountCommand.rename) {
      return;
    }
    switch (state.action) {
      case ActionSucceeded(:final String? message):
        if (message != null) {
          showAppSnackBar(context, message, tone: Tone.success);
        }
      case ActionFailed(:final failure):
        showAppSnackBar(
          context,
          'Não foi possível alterar o nome. O nome anterior continua. ${failure.message}',
          tone: Tone.danger,
        );
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
            eyebrow: 'Nova chave gerada',
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
      builder: (BuildContext context, AccountState state) {
        final GuardianAccount? account = state.account;
        final bool renaming = state.command == AccountCommand.rename && state.action.isRunning;
        return Scaffold(
          appBar: AppBar(title: const Text('Conta e senha')),
          body: StateSwitcher(
            child: account == null
                ? const KeyedSubtree(key: ValueKey<String>('carregando'), child: LoadingState())
                : KeyedSubtree(
                    key: const ValueKey<String>('conta'),
                    child: AppPageBody(
                      children: <Widget>[
                        AppSection(
                          title: 'Seus dados',
                          child: AppListGroup(
                            footer: 'O e-mail é usado para entrar na conta e não muda por aqui.',
                            children: <Widget>[
                              AppListRow(
                                leading: const AppIconTile(icon: AppIcons.person),
                                title: 'Nome',
                                subtitle: account.displayName.isEmpty
                                    ? 'Não informado'
                                    : account.displayName,
                                trailing: renaming
                                    ? const InlineProgress(label: 'Salvando o nome')
                                    : ExcludeSemantics(
                                        child: Icon(
                                          AppIcons.edit,
                                          color: context.colors.textSecondary,
                                        ),
                                      ),
                                onTap: renaming ? null : () => _editName(context, account),
                              ),
                              AppListRow(
                                leading: const AppIconTile(icon: AppIcons.email),
                                title: 'E-mail',
                                subtitle: account.email,
                              ),
                            ],
                          ),
                        ),
                        const SectionGap(),
                        AppSection(
                          title: 'Acesso',
                          child: AppListGroup(
                            footer:
                                'Ao trocar a senha, os outros celulares conectados à conta '
                                'precisam entrar de novo.',
                            children: <Widget>[
                              AppListRow(
                                leading: const AppIconTile(icon: AppIcons.password),
                                title: 'Trocar senha',
                                subtitle:
                                    'A senha administrativa protege as regras e os relatórios.',
                                onTap: () => _openChangePassword(context),
                              ),
                              AppListRow(
                                leading: const AppIconTile(icon: AppIcons.key),
                                title: 'Gerar nova chave',
                                subtitle:
                                    'Chave de recuperação para quando a senha for esquecida. '
                                    'Gere outra se perdeu a atual ou alguém a viu.',
                                onTap: () => _newRecoveryKey(context),
                              ),
                            ],
                          ),
                        ),
                        const SectionGap(),
                        AppSection(
                          title: 'Excluir conta',
                          child: AppListGroup(
                            children: <Widget>[
                              AppListRow(
                                leading: const AppIconTile(
                                  icon: AppIcons.deleteForever,
                                  tone: Tone.danger,
                                ),
                                title: 'Excluir conta e dados',
                                subtitle:
                                    'Apaga a conta, os aparelhos vinculados, as regras e todo o '
                                    'histórico. Não pode ser desfeito.',
                                onTap: () => _openDeleteAccount(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
