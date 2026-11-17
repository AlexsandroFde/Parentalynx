import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/security/password_policy.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import 'auth_messages.dart';
import 'session_controller.dart';
import 'widgets/auth_widgets.dart';

/// Recuperacao administrativa: troca a senha usando a chave de recuperacao.
///
/// O servidor gera uma chave nova e encerra todas as outras sessoes da conta.
class RecoverPage extends ConsumerStatefulWidget {
  const RecoverPage({super.key});

  @override
  ConsumerState<RecoverPage> createState() => _RecoverPageState();
}

class _RecoverPageState extends ConsumerState<RecoverPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _key = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  String? _emailError;
  String? _keyError;
  String? _passwordError;
  String? _confirmError;
  String? _formError;
  bool _busy = false;
  bool _emailFilled = false;

  @override
  void dispose() {
    _email.dispose();
    _key.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  PasswordCheck get _check => PasswordPolicy.evaluate(_password.text, email: _email.text);

  /// Deixa a chave no formato que o servidor espera: maiusculas e sem espacos.
  static String _normalizeKey(String input) => input.toUpperCase().replaceAll(RegExp(r'\s'), '');

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final PasswordCheck check = _check;
    setState(() {
      _formError = null;
      _emailError = validateEmail(_email.text);
      _keyError = _normalizeKey(_key.text).length < 10 ? 'Digite a chave de recuperação.' : null;
      _passwordError = check.isAcceptable ? null : check.issues.first.message;
      _confirmError = _confirm.text == _password.text ? null : 'As senhas não são iguais.';
    });
    if (_emailError != null ||
        _keyError != null ||
        _passwordError != null ||
        _confirmError != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final String deviceName = await ref.read(guardianDeviceNameProvider.future);
      await ref
          .read(guardianSessionProvider.notifier)
          .recover(
            email: _email.text.trim(),
            recoveryKey: _normalizeKey(_key.text),
            newPassword: _password.text,
            deviceName: deviceName,
          );
      // O roteador leva para a tela da nova chave de recuperacao.
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        if (isWeakPassword(error)) {
          _passwordError = authFailureMessage(error);
        } else {
          _formError = authFailureMessage(
            error,
            wrongCredentials: 'E-mail ou chave de recuperação incorretos.',
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Preenche o e-mail da ultima conta usada neste aparelho, quando houver.
    final String? storedEmail = ref.watch(storedGuardianEmailProvider).value;
    if (storedEmail != null && !_emailFilled) {
      _emailFilled = true;
      if (_email.text.isEmpty) {
        _email.text = storedEmail;
      }
    }

    return AuthScaffold(
      title: 'Recuperar acesso',
      subtitle:
          'Informe a chave de recuperação mostrada quando a conta foi criada e escolha uma '
          'nova senha administrativa.',
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
          autofillHints: const <String>[AutofillHints.email],
          decoration: InputDecoration(
            labelText: 'E-mail da conta',
            errorText: _emailError,
            prefixIcon: const Icon(Icons.alternate_email),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _key,
          enabled: !_busy,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          style: const TextStyle(letterSpacing: 0.8),
          decoration: InputDecoration(
            labelText: 'Chave de recuperação',
            hintText: 'RK-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
            errorText: _keyError,
            prefixIcon: const Icon(Icons.key_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PasswordField(
          controller: _password,
          enabled: !_busy,
          label: 'Nova senha administrativa',
          errorText: _passwordError,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.newPassword],
          onChanged: (_) => setState(() => _passwordError = null),
        ),
        const SizedBox(height: AppSpacing.md),
        PasswordStrengthMeter(password: _password.text, check: _check),
        const SizedBox(height: AppSpacing.lg),
        PasswordField(
          controller: _confirm,
          enabled: !_busy,
          label: 'Repita a nova senha',
          errorText: _confirmError,
          autofillHints: const <String>[AutofillHints.newPassword],
          onChanged: (_) => setState(() => _confirmError = null),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const NoticeBanner(
          message:
              'Ao recuperar, a senha é trocada, uma nova chave de recuperação é gerada e os '
              'outros aparelhos conectados à conta precisam entrar de novo.',
        ),
        const SizedBox(height: AppSpacing.xl),
        BusyButton(label: 'Recuperar acesso', busy: _busy, onPressed: _submit),
      ],
    );
  }
}
