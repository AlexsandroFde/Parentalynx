import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../domain/entities/alert_type.dart';
import '../../domain/entities/guardian_alert.dart';
import '../bloc/notification_permission/notification_permission_bloc.dart';
import '../bloc/notifications/notifications_bloc.dart';
import '../texts/notification_texts.dart';
import '../widgets/alert_icon.dart';
import '../widgets/notification_permission_prompt.dart';

/// Central de alertas: tudo o que o servidor avisou ao responsavel, do mais novo para o mais
/// antigo, agrupado por dia. Alertas novos tem a etiqueta "Novo" e o titulo em destaque (nao
/// so a cor); abrir um alerta marca como lido e mostra o que fazer a seguir.
///
/// Usa o [NotificationsBloc] e o [NotificationPermissionBloc] do painel e o [DevicesBloc]
/// (pedidos de tempo pendentes).
class AlertsCenterPage extends StatefulWidget {
  const AlertsCenterPage({super.key});

  @override
  State<AlertsCenterPage> createState() => _AlertsCenterPageState();
}

class _AlertsCenterPageState extends State<AlertsCenterPage> {
  /// Verdadeiro enquanto "marcar todos como lidos" esta em andamento, para confirmar so
  /// depois que o servidor respondeu.
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    context.read<NotificationsBloc>().add(const AlertsFeedRequested());
  }

  Future<void> _refresh() {
    final Completer<void> completer = Completer<void>();
    context.read<NotificationsBloc>().add(AlertsRefreshRequested(completer: completer));
    return completer.future;
  }

  Future<void> _markAllRead(int unread) async {
    final NotificationsBloc bloc = context.read<NotificationsBloc>();
    final bool confirmed = await showConfirmDialog(
      context,
      icon: AppIcons.checkAll,
      title: unread == 1 ? 'Marcar 1 alerta como lido?' : 'Marcar $unread alertas como lidos?',
      message: 'Eles continuam na central; só deixam de aparecer como novos.',
      consequence: 'Não é possível voltar a marcar como não lido.',
      confirmLabel: 'Marcar como lidos',
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _markingAll = true);
    bloc.add(const AllAlertsReadRequested());
  }

  void _onActionChanged(BuildContext context, NotificationsState state) {
    final ActionStatus action = state.action;
    if (action is ActionRunning) {
      return;
    }
    if (action case ActionFailed(:final failure)) {
      showFailure(context, failure);
    } else if (_markingAll) {
      showAppSnackBar(context, 'Todos os alertas foram marcados como lidos.', tone: Tone.success);
    }
    if (_markingAll) {
      setState(() => _markingAll = false);
    }
  }

  void _open(GuardianAlert alert, {required int pendingRequests}) {
    context.read<NotificationsBloc>().add(AlertReadRequested(alert.id));
    final DateTime now = context.read<Clock>().now();
    final GoRouter router = GoRouter.of(context);
    final DevicesBloc devices = context.read<DevicesBloc>();
    final String? deviceId = alert.deviceId;
    final String? typeLabel = AlertType.fromCode(alert.type)?.label;
    final String? child = alert.childName;
    final String moment = alertMomentLabel(
      DateTime.fromMillisecondsSinceEpoch(alert.createdAt),
      now: now,
    );
    unawaited(
      showAppSheet<void>(
        context,
        title: alert.title,
        subtitle: <String>[
          if (typeLabel != null && typeLabel != alert.title) typeLabel,
          if (child != null && child.isNotEmpty) child,
          moment,
        ].join(' · '),
        builder: (BuildContext sheetContext) {
          void close(void Function() navigate) {
            Navigator.of(sheetContext).pop();
            navigate();
          }

          return _AlertDetail(
            alert: alert,
            pendingRequests: pendingRequests,
            onRespond: () => close(() => router.go(GuardianPaths.timeRequests)),
            onOpenDevice: deviceId == null
                ? null
                : () => close(() => router.push(GuardianPaths.device(deviceId))),
            onOpenAppRules: deviceId == null
                ? null
                : () => close(() {
                    // As regras mostram o aparelho em foco: foca o aparelho do alerta antes.
                    devices.add(DeviceSelected(deviceId));
                    router.go(RulesPaths.apps);
                  }),
            onOpenPreferences: () => close(() => router.go(GuardianPaths.notificationPrefs)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NotificationsBloc, NotificationsState>(
      listenWhen: (NotificationsState previous, NotificationsState current) {
        return previous.action != current.action;
      },
      listener: _onActionChanged,
      builder: (BuildContext context, NotificationsState state) {
        final bool busy = state.action.isRunning || _markingAll;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Alertas'),
            actions: <Widget>[
              AppIconButton(
                icon: AppIcons.checkAll,
                tooltip: 'Marcar todos como lidos',
                onPressed: state.unread > 0 && !busy ? () => _markAllRead(state.unread) : null,
              ),
              AppIconButton(
                icon: AppIcons.settings,
                tooltip: 'Preferências de notificação',
                onPressed: () => context.go(GuardianPaths.notificationPrefs),
              ),
              const HelpButton(title: 'Como funcionam os alertas', topics: alertsHelpTopics),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
          body: AppPageBody(
            onRefresh: _refresh,
            children: <Widget>[
              const _AlertsBanners(),
              StateSwitcher(child: _feed(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _feed(BuildContext context, NotificationsState state) {
    final AlertsFeed feed = state.feed;
    return switch (feed) {
      AlertsFeedIdle() || AlertsFeedLoading() => const KeyedSubtree(
        key: ValueKey<String>('carregando'),
        child: SkeletonListGroup(rows: 4),
      ),
      AlertsFeedError(:final failure) => KeyedSubtree(
        key: const ValueKey<String>('erro'),
        child: AppPanel(
          child: ErrorState.fromError(
            failure,
            subject: 'os alertas',
            compact: true,
            onRetry: () => context.read<NotificationsBloc>().add(const AlertsFeedRequested()),
          ),
        ),
      ),
      AlertsFeedLoaded(:final List<GuardianAlert> alerts) when alerts.isEmpty => KeyedSubtree(
        key: const ValueKey<String>('vazio'),
        child: AppPanel(
          child: EmptyState(
            compact: true,
            icon: AppIcons.notificationNone,
            title: 'Nenhum alerta por enquanto',
            message:
                'Quando o limite acabar, a criança pedir mais tempo ou uma proteção for '
                'desativada, o aviso aparece aqui.',
            actionLabel: 'Escolher avisos',
            onAction: () => context.go(GuardianPaths.notificationPrefs),
          ),
        ),
      ),
      final AlertsFeedLoaded loaded => KeyedSubtree(
        key: const ValueKey<String>('lista'),
        child: _AlertsList(feed: loaded, onOpen: _open),
      ),
    };
  }
}

/// Alertas agrupados por dia, o botao de carregar os mais antigos e a nota sobre a entrega.
class _AlertsList extends StatelessWidget {
  const _AlertsList({required this.feed, required this.onOpen});

  final AlertsFeedLoaded feed;
  final void Function(GuardianAlert alert, {required int pendingRequests}) onOpen;

  @override
  Widget build(BuildContext context) {
    final DateTime now = context.read<Clock>().now();
    final List<ChildDevice> devices = context.select<DevicesBloc, List<ChildDevice>>(
      (DevicesBloc bloc) => bloc.state.active,
    );
    int pendingFor(String? deviceId) {
      int total = 0;
      for (final ChildDevice device in devices) {
        if (deviceId == null || device.id == deviceId) {
          total += device.pendingTimeRequests;
        }
      }
      return total;
    }

    // Os alertas chegam do mais novo para o mais antigo: cada troca de dia abre um grupo.
    final List<(String, List<GuardianAlert>)> groups = <(String, List<GuardianAlert>)>[];
    for (final GuardianAlert alert in feed.alerts) {
      final String label = alertDayLabel(
        DateTime.fromMillisecondsSinceEpoch(alert.createdAt),
        now: now,
      );
      if (groups.isEmpty || groups.last.$1 != label) {
        groups.add((label, <GuardianAlert>[]));
      }
      groups.last.$2.add(alert);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < groups.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.xl),
          AppSection(
            title: groups[i].$1,
            child: AppListGroup(
              children: <Widget>[
                for (final GuardianAlert alert in groups[i].$2)
                  _AlertRow(
                    alert: alert,
                    now: now,
                    showDay: groups[i].$1 == 'Hoje',
                    onTap: () => onOpen(alert, pendingRequests: pendingFor(alert.deviceId)),
                  ),
              ],
            ),
          ),
        ],
        if (feed.hasMore) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: AppButton.secondary(
              label: 'Carregar alertas mais antigos',
              icon: AppIcons.history,
              busy: feed.loadingMore,
              onPressed: () => context.read<NotificationsBloc>().add(const OlderAlertsRequested()),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(AppIcons.clock, size: AppSizes.iconSm, color: context.colors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(alertDeliveryNote, style: context.text.bodySmall)),
          ],
        ),
      ],
    );
  }
}

/// Linha de um alerta: icone do tipo, titulo, texto, crianca e quando chegou. Alertas novos
/// tem o titulo em negrito e a etiqueta "Novo", lida tambem pelo leitor de tela.
class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.alert,
    required this.now,
    required this.showDay,
    required this.onTap,
  });

  final GuardianAlert alert;
  final DateTime now;

  /// Hoje mostra o tempo relativo ("ha 3 min"); nos outros dias, o horario.
  final bool showDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DateTime created = DateTime.fromMillisecondsSinceEpoch(alert.createdAt);
    final String? child = alert.childName;
    final String meta = <String>[
      if (child != null && child.isNotEmpty) child,
      if (showDay) formatRelative(created, now: now) else formatClock(created),
    ].join(' · ');
    final bool unread = !alert.isRead;
    return AppListRow(
      leading: AlertIcon(type: alert.type),
      title: alert.title,
      titleStyle: context.text.bodyLarge?.copyWith(
        fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
      ),
      subtitle: alert.body.isEmpty ? null : alert.body,
      below: Text(meta, style: context.text.bodySmall),
      trailing: unread ? const StatusBadge(label: 'Novo', tone: Tone.info, showIcon: false) : null,
      showChevron: false,
      onTap: onTap,
    );
  }
}

/// Avisos que pedem uma acao, no topo da central: pedidos de tempo e notificacoes desligadas.
class _AlertsBanners extends StatelessWidget {
  const _AlertsBanners();

  @override
  Widget build(BuildContext context) {
    final bool notificationsOff = context.select<NotificationPermissionBloc, bool>(
      (NotificationPermissionBloc bloc) => bloc.state.isDenied,
    );
    final List<ChildDevice> waiting = context.select<DevicesBloc, List<ChildDevice>>(
      (DevicesBloc bloc) => <ChildDevice>[
        for (final ChildDevice device in bloc.state.active)
          if (device.pendingTimeRequests > 0) device,
      ],
    );
    final int pending = pendingTimeRequestsOf(waiting);
    final List<String> names = <String>[
      for (final ChildDevice device in waiting) device.displayName,
    ];
    final String who = names.length <= 1
        ? (names.isEmpty ? 'A criança' : names.first)
        : '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (pending > 0) ...<Widget>[
          AppBanner(
            icon: AppIcons.timeRequest,
            title: pending == 1
                ? '1 pedido de tempo aguardando resposta'
                : '$pending pedidos de tempo aguardando resposta',
            message:
                '$who ${names.length > 1 ? 'pediram' : 'pediu'} mais tempo de uso. Responda '
                'para liberar ou recusar.',
            actionLabel: 'Responder',
            onAction: () => context.go(GuardianPaths.timeRequests),
            liveRegion: true,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (notificationsOff) ...<Widget>[
          AppBanner(
            tone: Tone.warning,
            icon: AppIcons.notificationOff,
            title: 'Notificações desativadas',
            message: 'Sem a permissão de notificações você só vê os alertas quando abre o app.',
            actionLabel: 'Ativar notificações',
            onAction: () => requestNotificationsWithExplanation(context),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (pending > 0 || notificationsOff) const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Detalhe de um alerta na folha inferior: o texto completo, se gerou notificacao e o que
/// fazer a seguir (responder o pedido, ver o aparelho, ver as regras de apps).
class _AlertDetail extends StatelessWidget {
  const _AlertDetail({
    required this.alert,
    required this.pendingRequests,
    required this.onRespond,
    required this.onOpenDevice,
    required this.onOpenAppRules,
    required this.onOpenPreferences,
  });

  final GuardianAlert alert;

  /// Pedidos de tempo ainda sem resposta no aparelho do alerta.
  final int pendingRequests;
  final VoidCallback onRespond;
  final VoidCallback? onOpenDevice;
  final VoidCallback? onOpenAppRules;
  final VoidCallback onOpenPreferences;

  @override
  Widget build(BuildContext context) {
    final bool timeRequest = alert.type == AlertType.timeRequest.code;
    final bool aboutApps =
        alert.type == AlertType.blockedAppAttempt.code ||
        alert.type == AlertType.newAppInstalled.code;
    final String child = alert.childName ?? 'a criança';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AlertIcon(type: alert.type),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                alert.body.isEmpty ? alert.title : alert.body,
                style: context.text.bodyLarge,
              ),
            ),
          ],
        ),
        if (!alert.notify) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppBanner(
            tone: Tone.neutral,
            icon: AppIcons.notificationOff,
            message:
                'Este tipo de aviso está desligado nas preferências: ele aparece aqui, mas não '
                'tocou no celular.',
            actionLabel: 'Preferências',
            onAction: onOpenPreferences,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (timeRequest) ...<Widget>[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: pendingRequests > 0
                ? const StatusBadge(
                    label: 'Aguardando a sua resposta',
                    tone: Tone.warning,
                    icon: AppIcons.pending,
                  )
                : StatusBadge(
                    label: 'Nenhum pedido de $child aguardando',
                    tone: Tone.success,
                    icon: AppIcons.success,
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (pendingRequests > 0)
            AppButton.primary(
              label: 'Responder pedido',
              icon: AppIcons.timeRequest,
              expand: true,
              onPressed: onRespond,
            )
          else
            AppButton.secondary(
              label: 'Ver pedidos de tempo',
              icon: AppIcons.timeRequest,
              expand: true,
              onPressed: onRespond,
            ),
        ] else ...<Widget>[
          if (aboutApps && onOpenAppRules != null) ...<Widget>[
            AppButton.secondary(
              label: 'Ver regras de apps',
              icon: AppIcons.apps,
              expand: true,
              onPressed: onOpenAppRules,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (onOpenDevice != null)
            AppButton.tertiary(
              label: 'Ver aparelho',
              icon: AppIcons.device,
              expand: true,
              onPressed: onOpenDevice,
            ),
        ],
      ],
    );
  }
}
