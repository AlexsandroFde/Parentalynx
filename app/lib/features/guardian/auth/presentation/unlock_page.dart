import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../guardian_paths.dart';
import 'auth_messages.dart';
import 'session_controller.dart';
import 'widgets/auth_widgets.dart';

/// Tela de bloqueio do painel. Pede a senha administrativa na abertura do app e quando ele
/// volta do segundo plano depois do tempo configurado.
class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  final TextEditingController _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy) {
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Digite a senha administrativa.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(guardianSessionProvider.notifier).unlock(_password.text);
      // O roteador leva de volta para onde a pessoa estava.
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = authFailureMessage(error, wrongCredentials: 'Senha incorreta.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final GuardianSession session = ref.watch(guardianSessionProvider);
    final String? email = session is GuardianLocked && session.account != null
        ? session.account!.email
        : ref.watch(storedGuardianEmailProvider).value;
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
          enabled: !_busy,
          errorText: _error,
          onChanged: (_) {
            if (_error != null) {
              setState(() => _error = null);
            }
          },
          onSubmitted: (_) => _unlock(),
        ),
        const SizedBox(height: AppSpacing.xl),
        BusyButton(
          label: 'Desbloquear',
          icon: Icons.lock_open_outlined,
          busy: _busy,
          onPressed: _unlock,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: _busy ? null : () => context.push(GuardianPaths.recover),
            child: const Text('Esqueci a senha'),
          ),
        ),
      ],
    );
  }
}
