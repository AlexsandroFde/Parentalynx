import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../user_role/domain/entities/user_role.dart';
import '../bloc/onboarding/onboarding_bloc.dart';

/// Primeira tela: apresenta o app e deixa escolher o papel deste aparelho.
///
/// Espera acima na arvore o [OnboardingBloc].
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  void _choose(BuildContext context, UserRole role) {
    context.read<OnboardingBloc>().add(OnboardingRoleChosen(role));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingBloc, OnboardingState>(
      builder: (BuildContext context, OnboardingState state) {
        final UserRole? choosing = state.choosing;
        final AppFailure? failure = switch (state.action) {
          ActionFailed(:final AppFailure failure) => failure,
          _ => null,
        };
        return Scaffold(
          body: SafeArea(
            child: AppPageBody(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xxl,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BrandLockup(markSize: AppSizes.avatarLg),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const AppPageHeader(
                  eyebrow: 'Primeiro acesso',
                  title: 'Como este aparelho será usado?',
                  subtitle:
                      'O mesmo aplicativo é instalado no seu celular e no celular da criança. '
                      'Escolha o papel deste aparelho.',
                ),
                if (failure != null) ...<Widget>[
                  AppBanner(
                    tone: Tone.danger,
                    title: 'Não foi possível definir o papel deste aparelho',
                    message: failure.message,
                    liveRegion: true,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                AppListGroup(
                  children: <Widget>[
                    _RoleRow(
                      icon: AppIcons.guardian,
                      title: 'Sou o responsável',
                      description:
                          'Defina limites de tempo, escolha os aplicativos permitidos e '
                          'acompanhe os relatórios de uso.',
                      busy: choosing == UserRole.guardian,
                      enabled: choosing == null,
                      onTap: () => _choose(context, UserRole.guardian),
                    ),
                    _RoleRow(
                      icon: AppIcons.child,
                      title: 'Este é o aparelho da criança',
                      description:
                          'Vincule este aparelho ao responsável com um código. As regras '
                          'passam a valer aqui.',
                      busy: choosing == UserRole.child,
                      enabled: choosing == null,
                      onTap: () => _choose(context, UserRole.child),
                    ),
                  ],
                ),
                const SectionGap(),
                const AppBanner(
                  icon: AppIcons.show,
                  title: 'Controle transparente',
                  message:
                      'O ParentaLynx nunca fica escondido. A criança vê que o controle está '
                      'ativo, quais regras valem e quem é o responsável. O app não lê '
                      'mensagens, não registra o que é digitado e não captura a tela.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Uma das duas escolhas de papel. Durante a gravacao mostra o andamento no lugar da seta.
class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      leading: AppIconTile(icon: icon),
      title: title,
      subtitle: description,
      enabled: enabled || busy,
      trailing: busy
          ? Semantics(
              label: 'Gravando a escolha',
              child: const SizedBox.square(
                dimension: AppSizes.iconMd,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          : null,
      showChevron: !busy,
      onTap: enabled ? onTap : null,
    );
  }
}
