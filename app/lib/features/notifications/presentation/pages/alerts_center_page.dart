import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../domain/entities/alert_type.dart';
import '../../domain/entities/guardian_alert.dart';
import '../bloc/notification_permission/notification_permission_bloc.dart';
import '../bloc/notifications/notifications_bloc.dart';
import '../texts/notification_texts.dart';
import '../widgets/alert_icon.dart';
import '../widgets/notification_permission_prompt.dart';

/// Central de alertas: tudo o que o servidor avisou ao responsavel, do mais novo para o
/// mais antigo.
///
/// Usa o [NotificationsBloc] e o [NotificationPermissionBloc] do painel e o [DevicesBloc]
/// (pedidos de tempo pendentes).
class AlertsCenterPage extends StatefulWidget {
  const AlertsCenterPage({super.key});

  @override
  State<AlertsCenterPage> createState() => _AlertsCenterPageState();
}

class _AlertsCenterPageState extends State<AlertsCenterPage> {
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

  void _open(GuardianAlert alert) {
    context.read<NotificationsBloc>().add(AlertReadRequested(alert.id));
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (BuildContext sheetContext) => _AlertDetailSheet(alert: alert),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NotificationsBloc, NotificationsState>(
      listenWhen: (NotificationsState previous, NotificationsState current) {
        return previous.action != current.action;
      },
      listener: (BuildContext context, NotificationsState state) {
        if (state.action case ActionFailed(:final failure)) {
          showFailure(context, failure);
        }
      },
      builder: (BuildContext context, NotificationsState state) {
        final AlertsFeed feed = state.feed;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Alertas'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Marcar todos como lidos',
                icon: const Icon(Icons.done_all),
                onPressed: state.unread > 0
                    ? () => context.read<NotificationsBloc>().add(const AllAlertsReadRequested())
                    : null,
              ),
              IconButton(
                tooltip: 'Preferências de notificação',
                icon: const Icon(Icons.tune),
                onPressed: () => context.go(GuardianPaths.notificationPrefs),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: <Widget>[
                    const _AlertsHeader(),
                    ...switch (feed) {
                      AlertsFeedLoaded() => _alertTiles(context, feed),
                      AlertsFeedError(:final failure) => <Widget>[
                        SizedBox(
                          height: 360,
                          child: FailureView(
                            error: failure,
                            onRetry: () {
                              context.read<NotificationsBloc>().add(const AlertsFeedRequested());
                            },
                          ),
                        ),
                      ],
                      AlertsFeedIdle() || AlertsFeedLoading() => const <Widget>[
                        SizedBox(height: 240, child: LoadingView()),
                      ],
                    },
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _alertTiles(BuildContext context, AlertsFeedLoaded feed) {
    if (feed.alerts.isEmpty) {
      return const <Widget>[
        SizedBox(
          height: 360,
          child: EmptyState(
            icon: Icons.notifications_none,
            title: 'Nenhum alerta por enquanto',
            message:
                'Quando o limite for atingido, a criança pedir mais tempo ou uma proteção '
                'for desativada, o aviso aparece aqui.',
          ),
        ),
      ];
    }
    final DateTime now = context.read<Clock>().now();
    return <Widget>[
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            for (int index = 0; index < feed.alerts.length; index++) ...<Widget>[
              if (index > 0) const Divider(height: 1, indent: 72),
              _AlertTile(
                alert: feed.alerts[index],
                now: now,
                onTap: () => _open(feed.alerts[index]),
              ),
            ],
          ],
        ),
      ),
      if (feed.hasMore)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Center(
            child: feed.loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : TextButton(
                    onPressed: () {
                      context.read<NotificationsBloc>().add(const OlderAlertsRequested());
                    },
                    child: const Text('Carregar alertas mais antigos'),
                  ),
          ),
        ),
    ];
  }
}

/// Avisos fixos no topo da central: notificacoes desativadas, pedidos de tempo e a nota
/// sobre a entrega dos alertas.
class _AlertsHeader extends StatelessWidget {
  const _AlertsHeader();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool notificationsOff = context.select<NotificationPermissionBloc, bool>(
      (NotificationPermissionBloc bloc) => bloc.state.isDenied,
    );
    final int pendingRequests = context.select<DevicesBloc, int>(
      (DevicesBloc bloc) => pendingTimeRequestsOf(bloc.state.active),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (pendingRequests > 0) ...<Widget>[
          NoticeBanner(
            icon: Icons.more_time,
            title: pendingRequests == 1
                ? '1 pedido de tempo aguardando resposta'
                : '$pendingRequests pedidos de tempo aguardando resposta',
            message: 'A criança pediu mais tempo de uso.',
            actionLabel: 'Responder',
            onAction: () => context.go(GuardianPaths.timeRequests),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (notificationsOff) ...<Widget>[
          NoticeBanner(
            tone: Tone.warning,
            icon: Icons.notifications_off_outlined,
            title: 'Notificações desativadas',
            message: 'Sem a permissão de notificações você só vê os alertas quando abre o app.',
            actionLabel: 'Ativar notificações',
            onAction: () => requestNotificationsWithExplanation(context),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.schedule, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alertDeliveryNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, required this.now, required this.onTap});

  final GuardianAlert alert;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String meta = <String>[
      if (alert.childName != null && alert.childName!.isNotEmpty) alert.childName!,
      formatRelativeMs(alert.createdAt, now: now),
    ].join(' · ');
    return Semantics(
      button: true,
      label: alert.isRead ? null : 'Não lido',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AlertIcon(type: alert.type),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      alert.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: alert.isRead ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                    if (alert.body.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        alert.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!alert.isRead) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertDetailSheet extends StatelessWidget {
  const _AlertDetailSheet({required this.alert});

  final GuardianAlert alert;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime when = DateTime.fromMillisecondsSinceEpoch(alert.createdAt);
    final String? typeLabel = AlertType.fromCode(alert.type)?.label;
    final String? deviceId = alert.deviceId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AlertIcon(type: alert.type, size: 48),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: Text(alert.title, style: theme.textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (alert.body.isNotEmpty) Text(alert.body, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.md),
          Text(
            <String>[
              ?typeLabel,
              if (alert.childName != null && alert.childName!.isNotEmpty) alert.childName!,
              '${formatShortDate(when)} às ${formatClock(when)}',
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (!alert.notify) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Este tipo de alerta está desligado nas preferências, por isso não gerou '
              'notificação.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          if (alert.type == AlertType.timeRequest.code)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  // O roteador e obtido antes de fechar a folha, enquanto o contexto e valido.
                  final GoRouter router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.go(GuardianPaths.timeRequests);
                },
                icon: const Icon(Icons.more_time),
                label: const Text('Responder pedido'),
              ),
            )
          else if (deviceId != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final GoRouter router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push(GuardianPaths.device(deviceId));
                },
                icon: const Icon(Icons.smartphone_outlined),
                label: const Text('Ver aparelho'),
              ),
            ),
        ],
      ),
    );
  }
}
