import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../core/security/password_policy.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../domain/entities/credential_errors.dart';
import '../bloc/register/register_bloc.dart';
import '../widgets/auth_widgets.dart';

/// Criacao da conta do responsavel e da senha administrativa.
///
/// Espera um [RegisterBloc] acima na arvore. Ao criar a conta, o roteador leva para a tela da
/// chave de recuperacao.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _deviceName = TextEditingController();

  bool _deviceNameFilled = false;

  @override
  void initState() {
    super.initState();
    _fillDeviceName(context.read<RegisterBloc>().state.suggestedDeviceName);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _deviceName.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<RegisterBloc>().add(
      RegisterSubmitted(
        displayName: _name.text,
        email: _email.text,
        password: _password.text,
        confirmation: _confirm.text,
        deviceName: _deviceName.text,
      ),
    );
  }

  /// Preenche o nome do aparelho uma vez, sem sobrescrever o que a pessoa digitar.
  void _fillDeviceName(String? name) {
    if (name == null || _deviceNameFilled) {
      return;
    }
    _deviceNameFilled = true;
    if (_deviceName.text.isEmpty) {
      _deviceName.text = name;
    }
  }

  void _edited(CredentialField field) {
    // Redesenha o medidor de forca da senha e apaga o erro do campo.
    setState(() {});
    context.read<RegisterBloc>().add(RegisterFieldEdited(field));
  }

  @override
  Widget build(BuildContext context) {
    final PasswordCheck check = PasswordPolicy.evaluate(
      _password.text,
      email: _email.text,
      displayName: _name.text,
    );
    return BlocConsumer<RegisterBloc, RegisterState>(
      listenWhen: (RegisterState previous, RegisterState current) {
        return previous.suggestedDeviceName != current.suggestedDeviceName;
      },
      listener: (BuildContext context, RegisterState state) {
        _fillDeviceName(state.suggestedDeviceName);
      },
      builder: (BuildContext context, RegisterState state) {
        final bool busy = state.status != FormStatus.editing;
        final CredentialErrors errors = state.errors;
        final String? formError = errors.form;
        return AuthScaffold(
          title: 'Criar conta',
          subtitle:
              'Esta é a identidade administrativa da família. A senha protege todas as regras '
              'e os relatórios.',
          children: <Widget>[
            if (formError != null) ...<Widget>[
              NoticeBanner(message: formError, tone: Tone.danger),
              const SizedBox(height: AppSpacing.lg),
            ],
            TextField(
              controller: _name,
              enabled: !busy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.name],
              decoration: InputDecoration(
                labelText: 'Seu nome',
                errorText: errors.name,
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'E-mail',
                helperText: 'Usado para entrar na conta em outros aparelhos.',
                errorText: errors.email,
                errorMaxLines: 3,
                prefixIcon: const Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PasswordField(
              controller: _password,
              enabled: !busy,
              errorText: errors.password,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) => _edited(CredentialField.password),
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordStrengthMeter(password: _password.text, check: check),
            const SizedBox(height: AppSpacing.lg),
            PasswordField(
              controller: _confirm,
              enabled: !busy,
              label: 'Repita a senha',
              errorText: errors.confirmation,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) => _edited(CredentialField.confirmation),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _deviceName,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Nome deste aparelho',
                helperText: 'Aparece na lista de aparelhos conectados à conta.',
                prefixIcon: Icon(Icons.smartphone_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            BusyButton(label: 'Criar conta', busy: busy, onPressed: _submit),
          ],
        );
      },
    );
  }
}
