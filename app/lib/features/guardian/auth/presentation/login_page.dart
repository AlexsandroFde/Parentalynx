import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../guardian_paths.dart';
import 'auth_messages.dart';
import 'session_controller.dart';
import 'widgets/auth_widgets.dart';

/// Entrada em uma conta que ja existe.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  String? _emailError;
  String? _passwordError;
  String? _formError;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    setState(() {
      _formError = null;
      _emailError = validateEmail(_email.text);
      _passwordError = _password.text.isEmpty ? 'Digite a senha administrativa.' : null;
    });
    if (_emailError != null || _passwordError != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final String deviceName = await ref.read(guardianDeviceNameProvider.future);
      await ref
          .read(guardianSessionProvider.notifier)
          .login(email: _email.text.trim(), password: _password.text, deviceName: deviceName);
      // O roteador leva para o painel.
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _formError = authFailureMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Entrar',
      subtitle: 'Use o e-mail e a senha administrativa da conta da família.',
      children: <Widget>[
        if (_formError != null) ...<Widget>[
          NoticeBanner(message: _formError!, tone: Tone.danger),
          const SizedBox(height: AppSpacing.lg),
        ],
        TextField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.username, AutofillHints.email],
          decoration: InputDecoration(
            labelText: 'E-mail',
            errorText: _emailError,
            prefixIcon: const Icon(Icons.alternate_email),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PasswordField(
          controller: _password,
          enabled: !_busy,
          errorText: _passwordError,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.xl),
        BusyButton(label: 'Entrar', busy: _busy, onPressed: _submit),
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
