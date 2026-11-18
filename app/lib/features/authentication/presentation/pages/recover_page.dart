import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../core/security/password_policy.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
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
              'Informe a chave de recuperação mostrada quando a conta foi criada e escolha uma '
              'nova senha administrativa.',
          children: <Widget>[
            if (formError != null) ...<Widget>[
              NoticeBanner(message: formError, tone: Tone.danger),
              const SizedBox(height: AppSpacing.lg),
            ],
            TextField(
              controller: _email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'E-mail da conta',
                errorText: errors.email,
                prefixIcon: const Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _key,
              enabled: !busy,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              style: const TextStyle(letterSpacing: 0.8),
              decoration: InputDecoration(
                labelText: 'Chave de recuperação',
                hintText: 'RK-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
                errorText: errors.recoveryKey,
                prefixIcon: const Icon(Icons.key_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PasswordField(
              controller: _password,
              enabled: !busy,
              label: 'Nova senha administrativa',
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
              label: 'Repita a nova senha',
              errorText: errors.confirmation,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) => _edited(CredentialField.confirmation),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            const NoticeBanner(
              message:
                  'Ao recuperar, a senha é trocada, uma nova chave de recuperação é gerada e os '
                  'outros aparelhos conectados à conta precisam entrar de novo.',
            ),
            const SizedBox(height: AppSpacing.xl),
            BusyButton(label: 'Recuperar acesso', busy: busy, onPressed: _submit),
          ],
        );
      },
    );
  }
}
