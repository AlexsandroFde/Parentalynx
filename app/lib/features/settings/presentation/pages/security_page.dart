import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../authentication/domain/entities/app_lock_timeout.dart';
import '../../../authentication/presentation/bloc/auth/auth_bloc.dart';
import '../bloc/security/security_settings_bloc.dart';

/// Bloqueio do painel: quando pedir a senha administrativa de novo.
///
/// Espera acima na arvore o [SecuritySettingsBloc] e o [AuthBloc] (bloquear agora).
class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLockTimeout selected = context.select<SecuritySettingsBloc, AppLockTimeout>(
      (SecuritySettingsBloc bloc) => bloc.state.timeout,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Bloqueio do painel')),
      body: PageBody(
        children: <Widget>[
          const NoticeBanner(
            icon: Icons.lock_outline,
            message:
                'O painel pede a senha administrativa sempre que o app é aberto e quando ele '
                'volta do segundo plano depois do tempo escolhido. Assim, quem pegar o seu '
                'aparelho desbloqueado não consegue mudar as regras.',
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            title: 'Pedir a senha de novo após',
            padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
            child: RadioGroup<AppLockTimeout>(
              groupValue: selected,
              onChanged: (AppLockTimeout? value) {
                if (value != null) {
                  context.read<SecuritySettingsBloc>().add(AppLockTimeoutSelected(value));
                }
              },
              child: Column(
                children: <Widget>[
                  for (final AppLockTimeout option in AppLockTimeout.values)
                    RadioListTile<AppLockTimeout>(
                      value: option,
                      title: Text(option.label),
                      subtitle: option == AppLockTimeout.immediately
                          ? const Text('Bloqueia sempre que você sai do app')
                          : null,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => context.read<AuthBloc>().add(const AuthLockRequested()),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Bloquear agora'),
          ),
        ],
      ),
    );
  }
}
