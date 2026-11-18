import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../../authentication/domain/entities/app_lock_timeout.dart';
import '../../../authentication/presentation/bloc/auth/auth_bloc.dart';
import '../bloc/security/security_settings_bloc.dart';

/// Bloqueio do painel: quando pedir a senha administrativa de novo e o bloqueio imediato.
///
/// Espera acima na arvore o [SecuritySettingsBloc] e o [AuthBloc] (bloquear agora).
class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  /// O que cada tempo significa no dia a dia.
  static String? _detail(AppLockTimeout option) {
    return switch (option) {
      AppLockTimeout.immediately => 'Pede a senha sempre que você sai do app',
      AppLockTimeout.oneMinute => 'Padrão. Dá para consultar outro app sem digitar a senha',
      AppLockTimeout.fiveMinutes || AppLockTimeout.fifteenMinutes => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLockTimeout selected = context.select<SecuritySettingsBloc, AppLockTimeout>(
      (SecuritySettingsBloc bloc) => bloc.state.timeout,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Bloqueio do painel')),
      body: AppPageBody(
        children: <Widget>[
          AppSection(
            title: 'Pedir a senha de novo após',
            subtitle:
                'Tempo que o app pode ficar em segundo plano antes de pedir a senha '
                'administrativa. Assim, quem pegar o seu celular desbloqueado não muda as regras.',
            child: AppListGroup(
              dividerIndent: AppSpacing.lg + AppSizes.iconLg + AppSpacing.md,
              footer: 'O painel também pede a senha sempre que o app é aberto.',
              children: <Widget>[
                for (final AppLockTimeout option in AppLockTimeout.values)
                  AppRadioRow<AppLockTimeout>(
                    title: option.label,
                    subtitle: _detail(option),
                    value: option,
                    groupValue: selected,
                    onChanged: (AppLockTimeout value) {
                      context.read<SecuritySettingsBloc>().add(AppLockTimeoutSelected(value));
                    },
                  ),
              ],
            ),
          ),
          const SectionGap(),
          AppSection(
            title: 'Bloqueio imediato',
            subtitle:
                'Antes de emprestar o celular, bloqueie o painel. Para voltar, digite a senha '
                'administrativa.',
            child: AppButton.secondary(
              label: 'Bloquear agora',
              icon: AppIcons.lock,
              expand: true,
              onPressed: () => context.read<AuthBloc>().add(const AuthLockRequested()),
            ),
          ),
        ],
      ),
    );
  }
}
