import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/security/password_policy.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import 'auth_messages.dart';
import 'session_controller.dart';
import 'widgets/auth_widgets.dart';

/// Criacao da conta do responsavel e da senha administrativa.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _deviceName = TextEditingController();

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _formError;
  bool _busy = false;
  bool _deviceNameFilled = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _deviceName.dispose();
    super.dispose();
  }

  PasswordCheck get _check {
    return PasswordPolicy.evaluate(_password.text, email: _email.text, displayName: _name.text);
  }

  bool _validate() {
    final PasswordCheck check = _check;
    setState(() {
      _formError = null;
      _nameError = _name.text.trim().isEmpty ? 'Informe o seu nome.' : null;
      _emailError = validateEmail(_email.text);
      _passwordError = check.isAcceptable ? null : check.issues.first.message;
      _confirmError = _confirm.text == _password.text ? null : 'As senhas não são iguais.';
    });
    return _nameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmError == null;
  }

  Future<void> _submit() async {
    if (_busy || !_validate()) {
      return;
    }
    setState(() => _busy = true);
    final String deviceName = _deviceName.text.trim().isEmpty
        ? 'Aparelho do responsável'
        : _deviceName.text.trim();
    try {
      await ref
          .read(guardianSessionProvider.notifier)
          .register(
            email: _email.text.trim(),
            displayName: _name.text.trim(),
            password: _password.text,
            deviceName: deviceName,
          );
      // O roteador leva para a tela da chave de recuperacao.
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        if (isEmailInUse(error)) {
          _emailError = authFailureMessage(error);
        } else if (isWeakPassword(error)) {
          _passwordError = authFailureMessage(error);
        } else {
          _formError = authFailureMessage(error);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Preenche o nome do aparelho uma vez, sem sobrescrever o que a pessoa digitar.
    ref.listen<AsyncValue<String>>(guardianDeviceNameProvider, (
      AsyncValue<String>? previous,
      AsyncValue<String> next,
    ) {
      _fillDeviceName(next.value);
    });
    _fillDeviceName(ref.read(guardianDeviceNameProvider).value);

    return AuthScaffold(
      title: 'Criar conta',
      subtitle:
          'Esta é a identidade administrativa da família. A senha protege todas as regras '
          'e os relatórios.',
      children: <Widget>[
        if (_formError != null) ...<Widget>[
          NoticeBanner(message: _formError!, tone: Tone.danger),
          const SizedBox(height: AppSpacing.lg),
        ],
        TextField(
          controller: _name,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.name],
          decoration: InputDecoration(
            labelText: 'Seu nome',
            errorText: _nameError,
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.email],
          decoration: InputDecoration(
            labelText: 'E-mail',
            helperText: 'Usado para entrar na conta em outros aparelhos.',
            errorText: _emailError,
            errorMaxLines: 3,
            prefixIcon: const Icon(Icons.alternate_email),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PasswordField(
          controller: _password,
          enabled: !_busy,
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
          label: 'Repita a senha',
          errorText: _confirmError,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.newPassword],
          onChanged: (_) => setState(() => _confirmError = null),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _deviceName,
          enabled: !_busy,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Nome deste aparelho',
            helperText: 'Aparece na lista de aparelhos conectados à conta.',
            prefixIcon: Icon(Icons.smartphone_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        BusyButton(label: 'Criar conta', busy: _busy, onPressed: _submit),
      ],
    );
  }

  void _fillDeviceName(String? name) {
    if (name == null || _deviceNameFilled) {
      return;
    }
    _deviceNameFilled = true;
    if (_deviceName.text.isEmpty) {
      _deviceName.text = name;
    }
  }
}
