import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../guardian_paths.dart';
import '../../time_requests/presentation/time_requests_controller.dart';
import '../domain/alert.dart';
import 'alert_visuals.dart';
import 'alerts_controller.dart';
import 'notification_permission.dart';

/// Subcaminhos da aba Alertas.
abstract final class AlertsPaths {
  static const String preferences = '${GuardianPaths.alerts}/preferences';
  static const String timeRequests = '${GuardianPaths.alerts}/time-requests';
}

/// Central de alertas: tudo o que o servidor avisou ao responsavel, do mais novo para o
/// mais antigo.
class AlertsCenterPage extends ConsumerWidget {
  const AlertsCenterPage({super.key});

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(alertsProvider.notifier).markAllRead();
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(alertsProvider.notifier).loadMore();
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  void _open(BuildContext context, WidgetRef ref, GuardianAlert alert) {
    unawaited(ref.read(alertsProvider.notifier).markRead(alert.id));
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
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AlertsState> alerts = ref.watch(alertsProvider);
    final int unread = ref.watch(unreadAlertsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Marcar todos como lidos',
            icon: const Icon(Icons.done_all),
            onPressed: unread > 0 ? () => _markAll(context, ref) : null,
          ),
          IconButton(
            tooltip: 'Preferências de notificação',
            icon: const Icon(Icons.tune),
            onPressed: () => context.go(AlertsPaths.preferences),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(alertsProvider.notifier).refresh(),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: <Widget>[
                const _AlertsHeader(),
                if (alerts.hasValue)
                  ..._alertTiles(context, ref, alerts.requireValue)
                else if (alerts.hasError)
                  SizedBox(
                    height: 360,
                    child: FailureView(
                      error: alerts.error!,
                      onRetry: () => ref.invalidate(alertsProvider),
                    ),
                  )
                else
                  const SizedBox(height: 240, child: LoadingView()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _alertTiles(BuildContext context, WidgetRef ref, AlertsState state) {
    if (state.alerts.isEmpty) {
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
    return <Widget>[
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            for (int index = 0; index < state.alerts.length; index++) ...<Widget>[
              if (index > 0) const Divider(height: 1, indent: 72),
              _AlertTile(
                alert: state.alerts[index],
                onTap: () => _open(context, ref, state.alerts[index]),
              ),
            ],
          ],
        ),
      ),
      if (state.hasMore)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Center(
            child: state.loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : TextButton(
                    onPressed: () => _loadMore(context, ref),
                    child: const Text('Carregar alertas mais antigos'),
                  ),
          ),
        ),
    ];
  }
}

/// Avisos fixos no topo da central: notificacoes desativadas, pedidos de tempo e a nota
/// sobre a entrega dos alertas.
class _AlertsHeader extends ConsumerWidget {
  const _AlertsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool notificationsOff = ref.watch(notificationsAllowedProvider).value == false;
    final int pendingRequests = ref.watch(pendingTimeRequestsCountProvider);
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
            onAction: () => context.go(AlertsPaths.timeRequests),
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
            onAction: () => requestNotificationsWithExplanation(context, ref),
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
  const _AlertTile({required this.alert, required this.onTap});

  final GuardianAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String meta = <String>[
      if (alert.childName != null && alert.childName!.isNotEmpty) alert.childName!,
      formatRelativeMs(alert.createdAt),
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
          if (alert.type == 'time_request')
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  // O roteador e obtido antes de fechar a folha, enquanto o contexto e valido.
                  final GoRouter router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.go(AlertsPaths.timeRequests);
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
                  router.push('${GuardianPaths.devices}/${Uri.encodeComponent(deviceId)}');
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
