import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../shared/design_system/design_system.dart';
import '../bloc/login/login_bloc.dart';
import '../widgets/auth_widgets.dart';

/// Entrada em uma conta que ja existe.
///
/// Espera um [LoginBloc] acima na arvore. Ao entrar, o roteador leva para o painel.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<LoginBloc>().add(LoginSubmitted(email: _email.text, password: _password.text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(
      builder: (BuildContext context, LoginState state) {
        // Depois de aceito, continua inativo ate o roteador sair da tela.
        final bool busy = state.status != FormStatus.editing;
        final String? formError = state.errors.form;
        return AuthScaffold(
          title: 'Entrar',
          subtitle: 'Use o e-mail e a senha administrativa da conta da família.',
          children: <Widget>[
            AppTextField(
              controller: _email,
              label: 'E-mail',
              isRequired: true,
              hint: 'maria@exemplo.com',
              enabled: !busy,
              errorText: state.errors.email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.username, AutofillHints.email],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPasswordField(
              controller: _password,
              isRequired: true,
              enabled: !busy,
              errorText: state.errors.password,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (formError != null) ...<Widget>[
              AppBanner(
                tone: Tone.danger,
                title: 'Não foi possível entrar',
                message: formError,
                liveRegion: true,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppButton.primary(
              label: 'Entrar',
              icon: AppIcons.signIn,
              busy: busy,
              expand: true,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton.tertiary(
              label: 'Esqueci a senha',
              expand: true,
              onPressed: busy ? null : () => context.push(GuardianPaths.recover),
            ),
          ],
        );
      },
    );
  }
}
