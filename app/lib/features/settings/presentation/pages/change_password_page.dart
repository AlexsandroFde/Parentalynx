import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../core/security/password_policy.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../authentication/presentation/widgets/auth_widgets.dart';
import '../../domain/entities/password_change_errors.dart';
import '../bloc/change_password/change_password_bloc.dart';

/// Troca da senha administrativa.
///
/// Espera um [ChangePasswordBloc] acima na arvore. Com a senha trocada, a tela fecha e avisa
/// o que mudou nos outros celulares.
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
        showAppSnackBar(
          context,
          'Senha alterada. Os outros celulares conectados precisam entrar de novo.',
          tone: Tone.success,
        );
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
          subtitle:
              'Confirme a senha atual e escolha a nova senha administrativa. Este celular '
              'continua conectado.',
          children: <Widget>[
            AppPasswordField(
              controller: _current,
              label: 'Senha atual',
              isRequired: true,
              enabled: !busy,
              errorText: errors.current,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _edited(PasswordChangeField.current),
              onSubmitted: (_) => focusNextAfterPassword(),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPasswordField(
              controller: _next,
              label: 'Nova senha',
              isRequired: true,
              enabled: !busy,
              errorText: errors.next,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) => _edited(PasswordChangeField.next),
              onSubmitted: (_) => focusNextAfterPassword(),
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordStrengthMeter(password: _next.text, check: check),
            const SizedBox(height: AppSpacing.lg),
            AppPasswordField(
              controller: _confirm,
              label: 'Repita a nova senha',
              isRequired: true,
              enabled: !busy,
              errorText: errors.confirmation,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) => _edited(PasswordChangeField.confirmation),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.xl),
            const AppBanner(
              tone: Tone.warning,
              title: 'Depois da troca',
              message:
                  'Os outros celulares conectados à conta saem e precisam entrar com a senha '
                  'nova. As regras e os aparelhos das crianças não mudam.',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (formError != null) ...<Widget>[
              AppBanner(
                tone: Tone.danger,
                title: 'Não foi possível trocar a senha',
                message: '$formError A senha atual continua valendo.',
                liveRegion: true,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppButton.primary(label: 'Trocar senha', busy: busy, expand: true, onPressed: _submit),
          ],
        );
      },
    );
  }
}
