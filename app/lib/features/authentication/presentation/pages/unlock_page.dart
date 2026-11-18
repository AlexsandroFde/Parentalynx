import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../shared/design_system/design_system.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/unlock/unlock_bloc.dart';
import '../widgets/auth_widgets.dart';

/// Tela de bloqueio do painel. Pede a senha administrativa na abertura do app e quando ele
/// volta do segundo plano depois do tempo configurado.
///
/// Mostra de quem e a conta, o motivo do bloqueio e as saidas: recuperar o acesso ou entrar
/// com outra conta. Espera acima na arvore o [UnlockBloc] e o [AuthBloc]. Ao desbloquear, o
/// roteador leva de volta para onde a pessoa estava.
class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key});

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _unlock() => context.read<UnlockBloc>().add(UnlockSubmitted(_password.text));

  Future<void> _useAnotherAccount(String? email) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Entrar com outra conta?',
      message: email == null
          ? 'Este aparelho sai da conta atual.'
          : 'Este aparelho sai da conta $email.',
      consequence:
          'Os aparelhos das crianças e as regras continuam como estão. Para voltar, entre com '
          'o e-mail e a senha administrativa.',
      confirmLabel: 'Sair da conta',
      destructive: true,
      icon: AppIcons.signOut,
    );
    if (!confirmed || !mounted) {
      return;
    }
    context.read<AuthBloc>().add(const AuthSignOutRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UnlockBloc, UnlockState>(
      builder: (BuildContext context, UnlockState state) {
        final bool busy = state.status != FormStatus.editing;
        final String? email = state.email;
        return AuthScaffold(
          showAppBar: false,
          icon: AppIcons.lock,
          title: 'Painel bloqueado',
          subtitle:
              'Por segurança, o painel pede a senha administrativa ao abrir o app e depois de '
              'um tempo sem uso.',
          children: <Widget>[
            if (email != null) ...<Widget>[
              _AccountRow(email: email, name: state.displayName),
              const SizedBox(height: AppSpacing.xl),
            ],
            AppPasswordField(
              controller: _password,
              autofocus: true,
              enabled: !busy,
              errorText: state.error,
              onChanged: (_) => context.read<UnlockBloc>().add(const UnlockPasswordEdited()),
              onSubmitted: (_) => _unlock(),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton.primary(
              label: 'Desbloquear',
              icon: AppIcons.unlock,
              busy: busy,
              expand: true,
              onPressed: _unlock,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton.tertiary(
              label: 'Esqueci a senha',
              expand: true,
              onPressed: busy ? null : () => context.push(GuardianPaths.recover),
            ),
            AppButton.tertiary(
              label: 'Entrar com outra conta',
              expand: true,
              onPressed: busy ? null : () => _useAnotherAccount(email),
            ),
          ],
        );
      },
    );
  }
}

/// De quem e a conta que esta pedindo a senha.
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.email, this.name});

  final String email;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return AppListGroup(
      children: <Widget>[
        AppListRow(
          leading: InitialAvatar(name: name ?? email),
          title: name ?? email,
          subtitle: name == null ? 'Conta conectada neste aparelho' : email,
        ),
      ],
    );
  }
}
