import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../core/security/password_policy.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/credential_errors.dart';
import '../bloc/recover_access/recover_access_bloc.dart';
import '../widgets/auth_widgets.dart';

/// Recuperacao administrativa: troca a senha usando a chave de recuperacao.
///
/// O servidor gera uma chave nova e encerra todas as outras sessoes da conta. Espera um
/// [RecoverAccessBloc] acima na arvore.
class RecoverPage extends StatefulWidget {
  const RecoverPage({super.key});

  @override
  State<RecoverPage> createState() => _RecoverPageState();
}

class _RecoverPageState extends State<RecoverPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _key = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _emailFilled = false;

  static const List<HelpTopic> _help = <HelpTopic>[
    HelpTopic(
      title: 'Onde está a chave?',
      body:
          'Ela apareceu uma única vez, logo depois de criar a conta ou de gerar uma chave nova. '
          'Procure no papel ou no gerenciador de senhas onde você a guardou.',
    ),
    HelpTopic(
      title: 'Perdi a chave e a senha',
      body:
          'Por segurança, o servidor não guarda a chave e não há outra forma de trocar a '
          'senha esquecida. Sem as duas, não é possível recuperar esta conta.',
    ),
    HelpTopic(
      title: 'O que muda depois de recuperar',
      body:
          'A senha é trocada, uma chave nova é gerada e os outros aparelhos conectados à conta '
          'precisam entrar de novo. As regras e os aparelhos das crianças continuam iguais.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fillEmail(context.read<RecoverAccessBloc>().state.storedEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    _key.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<RecoverAccessBloc>().add(
      RecoverAccessSubmitted(
        email: _email.text,
        recoveryKey: _key.text,
        password: _password.text,
        confirmation: _confirm.text,
      ),
    );
  }

  /// Preenche o e-mail da ultima conta usada neste aparelho, uma vez.
  void _fillEmail(String? email) {
    if (email == null || _emailFilled) {
      return;
    }
    _emailFilled = true;
    if (_email.text.isEmpty) {
      _email.text = email;
    }
  }

  void _edited(CredentialField field) {
    // Redesenha o medidor de forca da senha e apaga o erro do campo.
    setState(() {});
    context.read<RecoverAccessBloc>().add(RecoverAccessFieldEdited(field));
  }

  @override
  Widget build(BuildContext context) {
    final PasswordCheck check = PasswordPolicy.evaluate(_password.text, email: _email.text);
    return BlocConsumer<RecoverAccessBloc, RecoverAccessState>(
      listenWhen: (RecoverAccessState previous, RecoverAccessState current) {
        return previous.storedEmail != current.storedEmail;
      },
      listener: (BuildContext context, RecoverAccessState state) => _fillEmail(state.storedEmail),
      builder: (BuildContext context, RecoverAccessState state) {
        final bool busy = state.status != FormStatus.editing;
        final CredentialErrors errors = state.errors;
        final String? formError = errors.form;
        return AuthScaffold(
          title: 'Recuperar acesso',
          subtitle:
              'Use a chave de recuperação guardada quando a conta foi criada e escolha uma nova '
              'senha administrativa.',
          trailing: const HelpButton(title: 'Recuperar acesso', topics: _help),
          children: <Widget>[
            AppTextField(
              controller: _email,
              label: 'E-mail da conta',
              isRequired: true,
              hint: 'maria@exemplo.com',
              enabled: !busy,
              errorText: errors.email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              onChanged: (_) => _edited(CredentialField.email),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _key,
              label: 'Chave de recuperação',
              isRequired: true,
              hint: 'RK-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
              helper: 'Letras e números em grupos de cinco. Espaços e minúsculas são aceitos.',
              enabled: !busy,
              errorText: errors.recoveryKey,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              style: context.text.bodyLarge?.copyWith(
                letterSpacing: 0.8,
                fontFeatures: AppTypography.tabularFigures,
              ),
              onChanged: (_) => _edited(CredentialField.recoveryKey),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPasswordField(
              controller: _password,
              label: 'Nova senha administrativa',
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
              label: 'Repita a nova senha',
              isRequired: true,
              enabled: !busy,
              errorText: errors.confirmation,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) => _edited(CredentialField.confirmation),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.xl),
            const AppBanner(
              tone: Tone.warning,
              title: 'Ao recuperar',
              message:
                  'A senha é trocada, uma nova chave de recuperação é gerada e os outros '
                  'aparelhos conectados à conta precisam entrar de novo.',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (formError != null) ...<Widget>[
              AppBanner(
                tone: Tone.danger,
                title: 'Não foi possível recuperar o acesso',
                message: '$formError A senha anterior continua valendo.',
                liveRegion: true,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppButton.primary(
              label: 'Recuperar acesso',
              busy: busy,
              expand: true,
              onPressed: _submit,
            ),
          ],
        );
      },
    );
  }
}
