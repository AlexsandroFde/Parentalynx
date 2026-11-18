import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/presentation/bloc/auth/auth_bloc.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../domain/entities/devices_overview.dart';
import '../bloc/more/more_bloc.dart';
import '../texts/settings_texts.dart';

/// Aba Mais: aparelhos, conta, alertas, dados e saida.
///
/// Espera acima na arvore o [AuthBloc] (conta e saida), o [DevicesBloc] (contagens dos
/// aparelhos) e o [MoreBloc] (servidor e versao do app).
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  Future<void> _signOut(BuildContext context) async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Sair da conta?',
      message:
          'Este aparelho deixa de receber alertas e de administrar as regras. Os aparelhos '
          'das crianças continuam vinculados e as regras continuam valendo.',
      confirmLabel: 'Sair',
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
      body: PageBody(
        children: <Widget>[
          if (account != null) _AccountHeader(account: account),
          const SizedBox(height: AppSpacing.lg),
          _Group(
            title: 'Aparelhos',
            children: <Widget>[
              _Item(
                icon: Icons.add_link,
                title: 'Vincular aparelho',
                subtitle: pendingLinksLabel(devices.pendingLinks),
                highlight: devices.pendingLinks > 0,
                onTap: () => context.push(GuardianPaths.pairing),
              ),
              _Item(
                icon: Icons.devices_other_outlined,
                title: 'Aparelhos vinculados',
                subtitle: activeDevicesLabel(devices.activeDevices),
                onTap: () => context.push(GuardianPaths.devices),
              ),
            ],
          ),
          _Group(
            title: 'Conta',
            children: <Widget>[
              _Item(
                icon: Icons.person_outline,
                title: 'Conta e senha',
                subtitle: 'Nome, senha administrativa e chave de recuperação',
                onTap: () => context.go(GuardianPaths.account),
              ),
              _Item(
                icon: Icons.phonelink_lock_outlined,
                title: 'Sessões conectadas',
                subtitle: 'Aparelhos de responsáveis com acesso à conta',
                onTap: () => context.go(GuardianPaths.sessions),
              ),
              _Item(
                icon: Icons.lock_clock_outlined,
                title: 'Bloqueio do painel',
                subtitle: 'Quando pedir a senha de novo',
                onTap: () => context.go(GuardianPaths.security),
              ),
            ],
          ),
          _Group(
            title: 'Alertas',
            children: <Widget>[
              _Item(
                icon: Icons.notifications_active_outlined,
                title: 'Preferências de notificação',
                subtitle: 'Escolher quais avisos notificar',
                onTap: () => context.go(GuardianPaths.notificationPrefs),
              ),
              _Item(
                icon: Icons.more_time,
                title: 'Pedidos de tempo',
                subtitle: pendingTimeRequestsLabel(devices.pendingTimeRequests),
                highlight: devices.pendingTimeRequests > 0,
                onTap: () => context.go(GuardianPaths.timeRequests),
              ),
            ],
          ),
          _Group(
            title: 'Dados',
            children: <Widget>[
              _Item(
                icon: Icons.privacy_tip_outlined,
                title: 'Dados e privacidade',
                subtitle: 'O que é coletado, retenção e limiares de alerta',
                onTap: () => context.go(GuardianPaths.privacy),
              ),
              _Item(
                icon: Icons.history,
                title: 'Registro de alterações',
                subtitle: 'Quem mudou o quê e quando',
                onTap: () => context.go(GuardianPaths.audit),
              ),
            ],
          ),
          _Group(
            title: 'Sobre',
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Servidor em uso'),
                subtitle: Text(serverAddressLabel(more.serverAddress)),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text(AppConstants.appName),
                subtitle: Text(appVersionLabel(more.appVersion)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sair da conta'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.account});

  final GuardianAccount account;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = accountTitle(account);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 26,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Text(
                name.characters.first.toUpperCase(),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name, style: theme.textTheme.titleMedium),
                  Text(
                    account.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int index = 0; index < children.length; index++) ...<Widget>[
                  if (index > 0) const Divider(height: 1, indent: 56),
                  children[index],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Destaca o item quando ha algo aguardando a pessoa.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: highlight ? theme.colorScheme.primary : null),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: highlight
            ? theme.textTheme.bodyMedium?.copyWith(
                color: Tone.info.foreground(context),
                fontWeight: FontWeight.w600,
              )
            : null,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
