import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../bloc/unlock/unlock_bloc.dart';
import '../widgets/auth_widgets.dart';

/// Tela de bloqueio do painel. Pede a senha administrativa na abertura do app e quando ele
/// volta do segundo plano depois do tempo configurado.
///
/// Espera um [UnlockBloc] acima na arvore. Ao desbloquear, o roteador leva de volta para onde
/// a pessoa estava.
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UnlockBloc, UnlockState>(
      builder: (BuildContext context, UnlockState state) {
        final bool busy = state.status != FormStatus.editing;
        final String? email = state.email;
        return AuthScaffold(
          showAppBar: false,
          icon: Icons.lock_outline,
          title: 'Painel bloqueado',
          subtitle: email == null
              ? 'Digite a senha administrativa para abrir o painel.'
              : 'Conta $email. Digite a senha administrativa para abrir o painel.',
          children: <Widget>[
            PasswordField(
              controller: _password,
              autofocus: true,
              enabled: !busy,
              errorText: state.error,
              onChanged: (_) => context.read<UnlockBloc>().add(const UnlockPasswordEdited()),
              onSubmitted: (_) => _unlock(),
            ),
            const SizedBox(height: AppSpacing.xl),
            BusyButton(
              label: 'Desbloquear',
              icon: Icons.lock_open_outlined,
              busy: busy,
              onPressed: _unlock,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: busy ? null : () => context.push(GuardianPaths.recover),
                child: const Text('Esqueci a senha'),
              ),
            ),
          ],
        );
      },
    );
  }
}
