import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/presentation/bloc/auth/auth_bloc.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../domain/entities/devices_overview.dart';
import '../bloc/more/more_bloc.dart';
import '../texts/settings_texts.dart';

/// Aba Mais: de quem e a conta, aparelhos, alertas, conta e seguranca, dados, sobre e saida.
///
/// Espera acima na arvore o [AuthBloc] (conta e saida), o [DevicesBloc] (contagens dos
/// aparelhos) e o [MoreBloc] (servidor e versao do app).
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  Future<void> _signOut(BuildContext context, GuardianAccount? account) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Sair da conta?',
      message:
          'Este aparelho deixa de receber alertas e de administrar as regras. Os aparelhos '
          'das crianças continuam vinculados e as regras continuam valendo.',
      consequence: account == null
          ? 'Para voltar, entre com o e-mail e a senha administrativa.'
          : 'Para voltar, entre com ${account.email} e a senha administrativa.',
      confirmLabel: 'Sair',
      destructive: true,
      icon: AppIcons.signOut,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    context.read<AuthBloc>().add(const AuthSignOutRequested());
  }

  @override
  Widget build(BuildContext context) {
    final GuardianAccount? account = context.select<AuthBloc, GuardianAccount?>(
      (AuthBloc bloc) => switch (bloc.state) {
        AuthReady(:final GuardianAccount account) => account,
        AuthSignedOut() || AuthLocked() => null,
      },
    );
    final DevicesOverview devices = context.select<DevicesBloc, DevicesOverview>(
      (DevicesBloc bloc) =>
          DevicesOverview.of(active: bloc.state.active, pending: bloc.state.pending),
    );
    final MoreState more = context.watch<MoreBloc>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: AppPageBody(
        children: <Widget>[
          if (account != null)
            AppPageHeader(
              eyebrow: 'Conta da família',
              title: accountTitle(account),
              subtitle: account.email,
              trailing: InitialAvatar(name: accountTitle(account), size: AppSizes.avatarLg),
            ),
          AppSection(
            title: 'Aparelhos',
            child: AppListGroup(
              children: <Widget>[
                _Item(
                  icon: AppIcons.addLink,
                  title: 'Vincular aparelho',
                  subtitle: pendingLinksLabel(devices.pendingLinks),
                  waiting: devices.pendingLinks,
                  onTap: () => context.push(GuardianPaths.pairing),
                ),
                _Item(
                  icon: AppIcons.devices,
                  title: 'Aparelhos vinculados',
                  subtitle: activeDevicesLabel(devices.activeDevices),
                  onTap: () => context.push(GuardianPaths.devices),
                ),
              ],
            ),
          ),
          const SectionGap(),
          AppSection(
            title: 'Alertas',
            child: AppListGroup(
              children: <Widget>[
                _Item(
                  icon: AppIcons.timeRequest,
                  title: 'Pedidos de tempo',
                  subtitle: pendingTimeRequestsLabel(devices.pendingTimeRequests),
                  waiting: devices.pendingTimeRequests,
                  onTap: () => context.go(GuardianPaths.timeRequests),
                ),
                _Item(
                  icon: AppIcons.notificationActive,
                  title: 'Preferências de notificação',
                  subtitle: 'Escolher quais avisos chegam neste celular',
                  onTap: () => context.go(GuardianPaths.notificationPrefs),
                ),
              ],
            ),
          ),
          const SectionGap(),
          AppSection(
            title: 'Conta e segurança',
            child: AppListGroup(
              children: <Widget>[
                _Item(
                  icon: AppIcons.person,
                  title: 'Conta e senha',
                  subtitle: 'Nome, senha administrativa e chave de recuperação',
                  onTap: () => context.go(GuardianPaths.account),
                ),
                _Item(
                  icon: AppIcons.deviceLocked,
                  title: 'Sessões conectadas',
                  subtitle: 'Celulares de responsáveis com acesso à conta',
                  onTap: () => context.go(GuardianPaths.sessions),
                ),
                _Item(
                  icon: AppIcons.scheduledLock,
                  title: 'Bloqueio do painel',
                  subtitle: 'Quando pedir a senha de novo',
                  onTap: () => context.go(GuardianPaths.security),
                ),
              ],
            ),
          ),
          const SectionGap(),
          AppSection(
            title: 'Dados',
            child: AppListGroup(
              children: <Widget>[
                _Item(
                  icon: AppIcons.privacy,
                  title: 'Dados e privacidade',
                  subtitle: 'O que é coletado, por quanto tempo e os avisos automáticos',
                  onTap: () => context.go(GuardianPaths.privacy),
                ),
                _Item(
                  icon: AppIcons.audit,
                  title: 'Registro de alterações',
                  subtitle: 'Quem mudou o quê e quando',
                  onTap: () => context.go(GuardianPaths.audit),
                ),
              ],
            ),
          ),
          const SectionGap(),
          AppSection(
            title: 'Sobre',
            child: AppListGroup(
              children: <Widget>[
                AppListRow(
                  leading: const AppIconTile(icon: AppIcons.server, tone: Tone.neutral),
                  title: 'Servidor em uso',
                  subtitle: serverAddressLabel(more.serverAddress),
                ),
                AppListRow(
                  leading: const BrandMark(size: AppSizes.iconTile),
                  title: AppConstants.appName,
                  subtitle: appVersionLabel(more.appVersion),
                ),
              ],
            ),
          ),
          const SectionGap(),
          AppListGroup(
            children: <Widget>[
              AppListRow(
                leading: const AppIconTile(icon: AppIcons.signOut, tone: Tone.danger),
                title: 'Sair da conta',
                subtitle: 'Este celular deixa de administrar a conta',
                showChevron: false,
                onTap: () => _signOut(context, account),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Item de navegacao da aba. Com algo esperando a pessoa ([waiting] maior que zero), o icone
/// ganha o tom de atencao; o texto de apoio ja diz quantos e o que fazer.
class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.waiting = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int waiting;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      leading: AppIconTile(icon: icon, tone: waiting > 0 ? Tone.warning : Tone.info),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}
