import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/platform/native_providers.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../alerts/presentation/alerts_center_page.dart';
import '../../auth/domain/guardian_account.dart';
import '../../auth/presentation/session_controller.dart';
import '../../devices/presentation/devices_providers.dart';
import '../../guardian_paths.dart';
import '../../time_requests/presentation/time_requests_controller.dart';

/// Subcaminhos da aba Mais.
abstract final class SettingsPaths {
  static const String account = '${GuardianPaths.more}/account';
  static const String sessions = '${GuardianPaths.more}/sessions';
  static const String security = '${GuardianPaths.more}/security';
  static const String privacy = '${GuardianPaths.more}/privacy';
  static const String audit = '${GuardianPaths.more}/audit';
}

/// Versao do app instalada, lida do lado nativo.
final FutureProvider<String?> appVersionProvider = FutureProvider<String?>((Ref ref) async {
  try {
    return (await ref.watch(deviceApiProvider).getDeviceInfo()).appVersion;
  } on PlatformException {
    return null;
  }
});

/// Aba Mais: aparelhos, conta, alertas, dados e saida.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Sair da conta?',
      message:
          'Este aparelho deixa de receber alertas e de administrar as regras. Os aparelhos '
          'das crianças continuam vinculados e as regras continuam valendo.',
      confirmLabel: 'Sair',
    );
    if (!confirmed) {
      return;
    }
    await ref.read(guardianSessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GuardianAccount? account = ref.watch(guardianAccountProvider);
    final int deviceCount = ref.watch(activeDevicesProvider).length;
    final int pendingLinks = ref.watch(pendingDevicesProvider).length;
    final int pendingRequests = ref.watch(pendingTimeRequestsCountProvider);
    final String serverUrl = ref.watch(serverUrlProvider);
    final String? version = ref.watch(appVersionProvider).value;
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
                subtitle: pendingLinks > 0
                    ? '$pendingLinks pedido(s) aguardando aprovação'
                    : 'Gerar código para o aparelho da criança',
                highlight: pendingLinks > 0,
                onTap: () => context.push(GuardianPaths.pairing),
              ),
              _Item(
                icon: Icons.devices_other_outlined,
                title: 'Aparelhos vinculados',
                subtitle: deviceCount == 0
                    ? 'Nenhum aparelho ativo'
                    : deviceCount == 1
                    ? '1 aparelho ativo'
                    : '$deviceCount aparelhos ativos',
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
                onTap: () => context.go(SettingsPaths.account),
              ),
              _Item(
                icon: Icons.phonelink_lock_outlined,
                title: 'Sessões conectadas',
                subtitle: 'Aparelhos de responsáveis com acesso à conta',
                onTap: () => context.go(SettingsPaths.sessions),
              ),
              _Item(
                icon: Icons.lock_clock_outlined,
                title: 'Bloqueio do painel',
                subtitle: 'Quando pedir a senha de novo',
                onTap: () => context.go(SettingsPaths.security),
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
                onTap: () => context.go(AlertsPaths.preferences),
              ),
              _Item(
                icon: Icons.more_time,
                title: 'Pedidos de tempo',
                subtitle: pendingRequests > 0
                    ? '$pendingRequests aguardando resposta'
                    : 'Nenhum pedido aguardando',
                highlight: pendingRequests > 0,
                onTap: () => context.go(AlertsPaths.timeRequests),
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
                onTap: () => context.go(SettingsPaths.privacy),
              ),
              _Item(
                icon: Icons.history,
                title: 'Registro de alterações',
                subtitle: 'Quem mudou o quê e quando',
                onTap: () => context.go(SettingsPaths.audit),
              ),
            ],
          ),
          _Group(
            title: 'Sobre',
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Servidor em uso'),
                subtitle: Text(serverUrl.isEmpty ? 'Não configurado' : serverUrl),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text(AppConfig.appName),
                subtitle: Text(version == null ? 'Controle parental' : 'Versão $version'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _signOut(context, ref),
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
    final String name = account.displayName.isEmpty ? 'Responsável' : account.displayName;
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
