import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../../notifications/domain/entities/guardian_alert.dart';
import '../../../notifications/presentation/bloc/notification_permission/notification_permission_bloc.dart';
import '../../../notifications/presentation/bloc/notifications/notifications_bloc.dart';
import '../../../notifications/presentation/widgets/alert_icon.dart';
import '../../../notifications/presentation/widgets/notification_permission_prompt.dart';
import '../bloc/shell/guardian_shell_bloc.dart';

/// Casca do painel do responsavel: as cinco abas e os avisos que valem em qualquer aba.
///
/// Usa o [GuardianShellBloc] (acao de abertura do app) e, do escopo da sessao, o
/// [NotificationsBloc] (selo de nao lidos e alertas que chegam em tempo real), o
/// [NotificationPermissionBloc] (pedido de permissao da primeira vez) e o [DevicesBloc].
///
/// O pedido de permissao de notificacoes espera o primeiro aparelho vinculado: os avisos sao
/// sobre o aparelho da crianca, e so a partir dele a explicacao faz sentido.
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
  bool _notificationsChecked = false;

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
    _checkNotificationsOnce(context.read<DevicesBloc>().state);
  }

  /// Na primeira vez que ha um aparelho ativo, explica as notificacoes e pede a permissao.
  void _checkNotificationsOnce(DevicesState devices) {
    if (_notificationsChecked || devices.active.isEmpty) {
      return;
    }
    _notificationsChecked = true;
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
    // de acao das telas (como o Salvar das regras). Com o leitor de tela ligado ele so sai
    // quando a pessoa dispensa, para dar tempo de ouvir e agir.
    _bannerTimer?.cancel();
    if (!MediaQuery.accessibleNavigationOf(context)) {
      _bannerTimer = Timer(_bannerDuration, _dismissBanner);
    }
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
        BlocListener<DevicesBloc, DevicesState>(
          listenWhen: (DevicesState previous, DevicesState current) {
            return previous.active.isEmpty && current.active.isNotEmpty;
          },
          listener: (BuildContext context, DevicesState state) => _checkNotificationsOnce(state),
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
              duration: AppMotion.resolve(context, AppMotion.base),
              curve: AppMotion.standard,
              alignment: Alignment.topCenter,
              child: banner == null
                  ? const SizedBox(width: double.infinity)
                  : _AlertToast(
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
        // Linha fina no topo: a barra se separa do conteudo sem sombra.
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: context.colors.hairline, width: AppSizes.hairline),
            ),
          ),
          child: NavigationBar(
            selectedIndex: current,
            // Tocar na aba ja selecionada volta para a raiz dela.
            onDestinationSelected: (int index) =>
                widget.navigationShell.goBranch(index, initialLocation: index == current),
            destinations: <Widget>[
              const NavigationDestination(
                icon: Icon(AppIcons.home),
                selectedIcon: Icon(AppIcons.homeSelected),
                label: 'Início',
              ),
              const NavigationDestination(
                icon: Icon(AppIcons.rules),
                selectedIcon: Icon(AppIcons.rulesSelected),
                label: 'Regras',
              ),
              const NavigationDestination(
                icon: Icon(AppIcons.reports),
                selectedIcon: Icon(AppIcons.reportsSelected),
                label: 'Relatórios',
              ),
              NavigationDestination(
                icon: _AlertsBadge(unread: unread, child: const Icon(AppIcons.alerts)),
                selectedIcon: _AlertsBadge(
                  unread: unread,
                  child: const Icon(AppIcons.alertsSelected),
                ),
                label: 'Alertas',
                tooltip: unread == 0
                    ? 'Alertas'
                    : unread == 1
                    ? 'Alertas, 1 não lido'
                    : 'Alertas, $unread não lidos',
              ),
              const NavigationDestination(
                icon: Icon(AppIcons.more),
                selectedIcon: Icon(AppIcons.moreSelected),
                label: 'Mais',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso de um alerta que chegou com o app aberto: o icone do tipo de alerta, o que houve e o
/// atalho para a central. Fica no topo por alguns segundos.
class _AlertToast extends StatelessWidget {
  const _AlertToast({required this.alert, required this.onOpen, required this.onDismiss});

  final GuardianAlert alert;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color background = context.colors.inverseSurface;
    final Color foreground = context.colors.onInverseSurface;
    // A faixa cobre a barra de status: os icones do sistema precisam contrastar com o fundo dela.
    final SystemUiOverlayStyle overlay = theme.brightness == Brightness.light
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    // O botao "Ver" usa a mesma cor do texto do aviso, que ja contrasta com o fundo invertido,
    // mantendo o resto do estilo do botao.
    final ThemeData inverted = theme.copyWith(
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(foregroundColor: WidgetStatePropertyAll<Color>(foreground))
            .merge(theme.textButtonTheme.style),
      ),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlay,
        child: Material(
          color: background,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  ExcludeSemantics(
                    child: Icon(
                      AlertVisual.forType(alert.type).icon,
                      color: foreground,
                      size: AppSizes.iconLg,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          alert.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(color: foreground),
                        ),
                        if (alert.body.isNotEmpty)
                          Text(
                            alert.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(color: foreground),
                          ),
                      ],
                    ),
                  ),
                  Theme(
                    data: inverted,
                    child: AppButton.tertiary(
                      label: 'Ver',
                      size: AppButtonSize.compact,
                      onPressed: onOpen,
                    ),
                  ),
                  AppIconButton(
                    icon: AppIcons.close,
                    tooltip: 'Dispensar aviso',
                    color: foreground,
                    onPressed: onDismiss,
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
