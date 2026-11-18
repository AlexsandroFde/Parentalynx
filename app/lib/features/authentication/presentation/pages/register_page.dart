import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../core/security/password_policy.dart';
import '../../../../shared/design_system/design_system.dart';
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

  static const List<HelpTopic> _help = <HelpTopic>[
    HelpTopic(
      title: 'O que a senha administrativa protege',
      body:
          'As regras, os relatórios e a desvinculação dos aparelhos. Ela também é pedida no '
          'aparelho da criança para mexer no controle, por isso não a compartilhe com ela.',
    ),
    HelpTopic(
      title: 'E se eu esquecer a senha?',
      body:
          'Logo depois de criar a conta, o app mostra uma chave de recuperação. Ela é a única '
          'forma de trocar a senha esquecida: guarde em papel ou em um gerenciador de senhas.',
    ),
    HelpTopic(
      title: 'Outro responsável pode usar a conta?',
      body:
          'Pode. Ele entra com o mesmo e-mail e a mesma senha no celular dele, e esse aparelho '
          'aparece em Mais, Sessões conectadas.',
    ),
  ];

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
        // Depois de aceito, continua inativo ate o roteador sair da tela.
        final bool busy = state.status != FormStatus.editing;
        final CredentialErrors errors = state.errors;
        final String? formError = errors.form;
        return AuthScaffold(
          eyebrow: 'Passo 1 de 3',
          title: 'Criar conta',
          subtitle:
              'É a conta administrativa da família. A senha protege as regras e os '
              'relatórios.',
          trailing: const HelpButton(title: 'Conta da família', topics: _help),
          children: <Widget>[
            AppTextField(
              controller: _name,
              label: 'Seu nome',
              isRequired: true,
              enabled: !busy,
              errorText: errors.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.name],
              onChanged: (_) => _edited(CredentialField.name),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _email,
              label: 'E-mail',
              isRequired: true,
              hint: 'maria@exemplo.com',
              helper: 'Usado para entrar na conta em outros aparelhos.',
              enabled: !busy,
              errorText: errors.email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              onChanged: (_) => _edited(CredentialField.email),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPasswordField(
              controller: _password,
              isRequired: true,
              enabled: !busy,
              errorText: errors.password,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) => _edited(CredentialField.password),
              onSubmitted: (_) => focusNextAfterPassword(),
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordStrengthMeter(password: _password.text, check: check),
            const SizedBox(height: AppSpacing.lg),
            AppPasswordField(
              controller: _confirm,
              label: 'Repita a senha',
              isRequired: true,
              enabled: !busy,
              errorText: errors.confirmation,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) => _edited(CredentialField.confirmation),
              onSubmitted: (_) => focusNextAfterPassword(),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _deviceName,
              label: 'Nome deste aparelho',
              helper: 'Aparece na lista de sessões conectadas da conta.',
              enabled: !busy,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (formError != null) ...<Widget>[
              AppBanner(
                tone: Tone.danger,
                title: 'Não foi possível criar a conta',
                message: formError,
                liveRegion: true,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppButton.primary(label: 'Criar conta', busy: busy, expand: true, onPressed: _submit),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Em seguida, você guarda a chave de recuperação e vincula o aparelho da criança.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ],
        );
      },
    );
  }
}
