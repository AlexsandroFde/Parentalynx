import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../notifications/domain/entities/guardian_alert.dart';
import '../../../notifications/presentation/bloc/notification_permission/notification_permission_bloc.dart';
import '../../../notifications/presentation/bloc/notifications/notifications_bloc.dart';
import '../../../notifications/presentation/widgets/notification_permission_prompt.dart';
import '../bloc/shell/guardian_shell_bloc.dart';

/// Casca do painel do responsavel: as cinco abas e os avisos que valem em qualquer aba.
///
/// Usa o [GuardianShellBloc] (acao de abertura do app) e, do escopo da sessao, o
/// [NotificationsBloc] (selo de nao lidos e alertas que chegam em tempo real) e o
/// [NotificationPermissionBloc] (pedido de permissao da primeira vez).
class GuardianShell extends StatefulWidget {
  const GuardianShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Posicao da aba Alertas.
  static const int alertsTab = 3;

  @override
  State<GuardianShell> createState() => _GuardianShellState();
}

class _GuardianShellState extends State<GuardianShell> {
  /// Tempo que o aviso de um alerta novo fica na tela.
  static const Duration _bannerDuration = Duration(seconds: 5);

  GuardianAlert? _bannerAlert;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFirstFrame());
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _afterFirstFrame() {
    if (!mounted) {
      return;
    }
    _handleLaunchAction(context.read<GuardianShellBloc>().state);
    // Na primeira vez que o painel abre, explica as notificacoes e pede a permissao.
    context.read<NotificationPermissionBloc>().add(const NotificationFirstRunCheckRequested());
  }

  void _handleLaunchAction(GuardianShellState state) {
    if (!state.opensAlerts) {
      return;
    }
    context.read<GuardianShellBloc>().add(const GuardianShellLaunchActionHandled());
    widget.navigationShell.goBranch(GuardianShell.alertsTab, initialLocation: true);
  }

  Future<void> _askForNotifications() async {
    context.read<NotificationPermissionBloc>().add(const NotificationFirstRunPromptShown());
    await requestNotificationsWithExplanation(context);
  }

  /// Um alerta chegou em tempo real com o app aberto: mostra o aviso.
  void _showBanner(GuardianAlert alert) {
    // O aviso fica no topo, e nao em uma barra flutuante embaixo, para nunca cobrir os botoes
    // de acao das telas (como o Salvar das regras).
    _bannerTimer?.cancel();
    _bannerTimer = Timer(_bannerDuration, _dismissBanner);
    setState(() => _bannerAlert = alert);
  }

  void _dismissBanner() {
    _bannerTimer?.cancel();
    if (mounted && _bannerAlert != null) {
      setState(() => _bannerAlert = null);
    }
  }

  void _openAlertsFromBanner() {
    _dismissBanner();
    widget.navigationShell.goBranch(GuardianShell.alertsTab, initialLocation: true);
  }

  @override
  Widget build(BuildContext context) {
    final int unread = context.select((NotificationsBloc bloc) => bloc.state.unread);
    final int current = widget.navigationShell.currentIndex;
    final GuardianAlert? banner = _bannerAlert;
    final MediaQueryData media = MediaQuery.of(context);
    return MultiBlocListener(
      listeners: <BlocListener<Object?, Object?>>[
        BlocListener<GuardianShellBloc, GuardianShellState>(
          listenWhen: (GuardianShellState previous, GuardianShellState current) {
            return current.opensAlerts && !previous.opensAlerts;
          },
          listener: (BuildContext context, GuardianShellState state) => _handleLaunchAction(state),
        ),
        BlocListener<NotificationsBloc, NotificationsState>(
          listenWhen: (NotificationsState previous, NotificationsState current) {
            return current.lastIncoming != null && current.lastIncoming != previous.lastIncoming;
          },
          listener: (BuildContext context, NotificationsState state) {
            _showBanner(state.lastIncoming!);
          },
        ),
        BlocListener<NotificationPermissionBloc, NotificationPermissionState>(
          listenWhen: (NotificationPermissionState previous, NotificationPermissionState current) {
            return current.firstRunPrompt && !previous.firstRunPrompt;
          },
          listener: (BuildContext context, NotificationPermissionState state) {
            unawaited(_askForNotifications());
          },
        ),
      ],
      child: Scaffold(
        body: Column(
          children: <Widget>[
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: banner == null
                  ? const SizedBox(width: double.infinity)
                  : _AlertBanner(
                      alert: banner,
                      onOpen: _openAlertsFromBanner,
                      onDismiss: _dismissBanner,
                    ),
            ),
            Expanded(
              // Com o aviso visivel, ele ja ocupa a area da barra de status. O MediaQuery fica
              // sempre na arvore para as abas nao serem recriadas quando o aviso entra e sai.
              child: MediaQuery(
                data: banner == null ? media : media.removePadding(removeTop: true),
                child: widget.navigationShell,
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: current,
          // Tocar na aba ja selecionada volta para a raiz dela.
          onDestinationSelected: (int index) =>
              widget.navigationShell.goBranch(index, initialLocation: index == current),
          destinations: <Widget>[
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Início',
            ),
            const NavigationDestination(
              icon: Icon(Icons.rule_outlined),
              selectedIcon: Icon(Icons.rule),
              label: 'Regras',
            ),
            const NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Relatórios',
            ),
            NavigationDestination(
              icon: _AlertsBadge(unread: unread, child: const Icon(Icons.notifications_outlined)),
              selectedIcon: _AlertsBadge(unread: unread, child: const Icon(Icons.notifications)),
              label: 'Alertas',
              tooltip: unread > 0 ? 'Alertas, $unread não lidos' : 'Alertas',
            ),
            const NavigationDestination(
              icon: Icon(Icons.menu),
              selectedIcon: Icon(Icons.menu_open),
              label: 'Mais',
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso de um alerta que chegou com o app aberto. Fica no topo por alguns segundos.
class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.alert, required this.onOpen, required this.onDismiss});

  final GuardianAlert alert;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    // A faixa cobre a barra de status: os icones do sistema precisam contrastar com o fundo dela.
    final SystemUiOverlayStyle overlay = scheme.brightness == Brightness.light
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return Semantics(
      container: true,
      liveRegion: true,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlay,
        child: Material(
          color: scheme.inverseSurface,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.notifications_active_outlined,
                    color: scheme.onInverseSurface,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          alert.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onInverseSurface,
                          ),
                        ),
                        if (alert.body.isNotEmpty)
                          Text(
                            alert.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onInverseSurface,
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onOpen,
                    style: TextButton.styleFrom(foregroundColor: scheme.inversePrimary),
                    child: const Text('Ver'),
                  ),
                  IconButton(
                    tooltip: 'Dispensar aviso',
                    onPressed: onDismiss,
                    color: scheme.onInverseSurface,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertsBadge extends StatelessWidget {
  const _AlertsBadge({required this.unread, required this.child});

  final int unread;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: unread > 0,
      label: Text(unread > 99 ? '99+' : '$unread'),
      child: child,
    );
  }
}
