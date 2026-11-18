import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../server_config/presentation/bloc/server_config_bloc.dart';
import '../../../server_config/presentation/widgets/server_sheet.dart';
import '../../../user_role/domain/entities/user_role.dart';
import '../bloc/onboarding/onboarding_bloc.dart';

/// Primeira tela: apresenta o app e deixa escolher o papel deste aparelho.
///
/// Mostra o servidor em uso antes da escolha, porque sem ele a escolha nao pode ser gravada.
/// Espera acima na arvore o [OnboardingBloc] e o [ServerConfigBloc] (folha do servidor).
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  /// Falta o servidor para gravar a escolha: pede o endereco e avisa como a folha fechou.
  Future<void> _askServer(BuildContext context) async {
    final OnboardingBloc bloc = context.read<OnboardingBloc>();
    final bool saved = await showServerSheet(context);
    bloc.add(OnboardingServerSheetClosed(saved: saved));
  }

  void _choose(BuildContext context, UserRole role) {
    context.read<OnboardingBloc>().add(OnboardingRoleChosen(role));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingBloc, OnboardingState>(
      listenWhen: (OnboardingState previous, OnboardingState current) {
        return current.awaitingServerFor != null &&
            previous.awaitingServerFor != current.awaitingServerFor;
      },
      listener: (BuildContext context, OnboardingState state) {
        unawaited(_askServer(context));
      },
      child: BlocBuilder<OnboardingBloc, OnboardingState>(
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
                  const SectionGap(),
                  _ServerSection(enabled: choosing == null),
                ],
              ),
            ),
          );
        },
      ),
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

/// Servidor em uso: o endereco ou o aviso de que falta configurar, com a troca a um toque.
class _ServerSection extends StatelessWidget {
  const _ServerSection({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ServerConfigState server = context.watch<ServerConfigBloc>().state;
    final bool configured = server.isConfigured;
    return AppSection(
      title: 'Servidor',
      child: AppListGroup(
        footer: 'O seu celular e o da criança precisam usar o mesmo servidor.',
        children: <Widget>[
          AppListRow(
            leading: AppIconTile(
              icon: AppIcons.server,
              tone: configured ? Tone.neutral : Tone.warning,
            ),
            title: configured ? server.address : 'Servidor não configurado',
            subtitle: configured
                ? 'Toque para trocar o endereço.'
                : 'Informe o endereço antes de escolher o papel do aparelho.',
            trailing: configured ? null : const StatusBadge(label: 'Pendente', tone: Tone.warning),
            showChevron: true,
            enabled: enabled,
            onTap: enabled ? () => showServerSheet(context) : null,
          ),
        ],
      ),
    );
  }
}
