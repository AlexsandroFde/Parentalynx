import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../core/security/password_policy.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../authentication/presentation/widgets/auth_widgets.dart';
import '../../domain/entities/password_change_errors.dart';
import '../bloc/change_password/change_password_bloc.dart';

/// Troca da senha administrativa.
///
/// Espera um [ChangePasswordBloc] acima na arvore. Com a senha trocada, a tela fecha.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<ChangePasswordBloc>().add(
      ChangePasswordSubmitted(
        currentPassword: _current.text,
        newPassword: _next.text,
        confirmation: _confirm.text,
      ),
    );
  }

  void _edited(PasswordChangeField field) {
    // Redesenha o medidor de forca da senha e apaga o erro do campo.
    setState(() {});
    context.read<ChangePasswordBloc>().add(ChangePasswordFieldEdited(field));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChangePasswordBloc, ChangePasswordState>(
      listenWhen: (ChangePasswordState previous, ChangePasswordState current) {
        return previous.status != current.status && current.status == FormStatus.succeeded;
      },
      listener: (BuildContext context, ChangePasswordState state) {
        showAppSnackBar(context, 'Senha alterada.', tone: Tone.success);
        Navigator.of(context).pop();
      },
      builder: (BuildContext context, ChangePasswordState state) {
        final bool busy = state.status != FormStatus.editing;
        final PasswordChangeErrors errors = state.errors;
        final String? formError = errors.form;
        final PasswordCheck check = PasswordPolicy.evaluate(
          _next.text,
          email: state.email,
          displayName: state.displayName,
        );
        return AuthScaffold(
          title: 'Trocar senha',
          subtitle: 'Os outros aparelhos conectados à conta precisam entrar de novo.',
          children: <Widget>[
            if (formError != null) ...<Widget>[
              NoticeBanner(message: formError, tone: Tone.danger),
              const SizedBox(height: AppSpacing.lg),
            ],
            PasswordField(
              controller: _current,
              enabled: !busy,
              label: 'Senha atual',
              errorText: errors.current,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),
            PasswordField(
              controller: _next,
              enabled: !busy,
              label: 'Nova senha',
              errorText: errors.next,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) => _edited(PasswordChangeField.next),
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordStrengthMeter(password: _next.text, check: check),
            const SizedBox(height: AppSpacing.lg),
            PasswordField(
              controller: _confirm,
              enabled: !busy,
              label: 'Repita a nova senha',
              errorText: errors.confirmation,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) => _edited(PasswordChangeField.confirmation),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.xl),
            BusyButton(label: 'Trocar senha', busy: busy, onPressed: _submit),
          ],
        );
      },
    );
  }
}
