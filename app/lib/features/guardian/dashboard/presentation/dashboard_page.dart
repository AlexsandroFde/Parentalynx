import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/domain/policy.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../../shared/widgets/time_ring.dart';
import '../../apps/data/apps_repository.dart';
import '../../apps/domain/app_entry.dart';
import '../../apps/presentation/app_icon.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/devices_providers.dart';
import '../../guardian_paths.dart';
import '../../rules/presentation/protection_page.dart' show guaranteesOf;
import '../data/dashboard_data.dart';
import '../domain/dashboard_texts.dart';
import 'dashboard_actions.dart';
import 'widgets/device_selector.dart';

/// Painel do responsavel: estado do aparelho em foco, tempo de hoje e acoes rapidas.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({this.now, super.key});

  /// Momento de referencia para textos relativos. So para testes.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Device>> devices = ref.watch(devicesProvider);
    final Device? device = ref.watch(selectedDeviceProvider);
    final Widget body;
    if (!devices.hasValue) {
      body = devices.hasError
          ? FailureView(
              error: devices.error!,
              onRetry: () => ref.read(devicesProvider.notifier).refresh(),
            )
          : const LoadingView(message: 'Carregando os aparelhos');
    } else if (device == null) {
      body = _NoDevice(pending: ref.watch(pendingDevicesProvider).length);
    } else {
      body = RefreshIndicator(
        onRefresh: () async {
          await ref.read(devicesProvider.notifier).refresh();
          ref
            ..invalidate(deviceAppsProvider(device.id))
            ..invalidate(recentAlertsProvider);
        },
        child: _DeviceDashboard(device: device, now: now),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Início')),
      body: body,
    );
  }
}

class _NoDevice extends StatelessWidget {
  const _NoDevice({required this.pending});

  final int pending;

  @override
  Widget build(BuildContext context) {
    if (pending > 0) {
      return EmptyState(
        icon: Icons.phonelink_ring_outlined,
        title: 'Um aparelho aguarda a sua aprovação',
        message: 'Confira o número de confirmação mostrado nos dois aparelhos e aprove o vínculo.',
        actionLabel: 'Ver pedido de vínculo',
        onAction: () => context.push(GuardianPaths.pairing),
      );
    }
    return EmptyState(
      icon: Icons.phonelink_setup_outlined,
      title: 'Nenhum aparelho vinculado',
      message:
          'Instale o ParentaLynx no aparelho da criança, escolha "Este é o aparelho da '
          'criança" e use o código de vinculação gerado aqui.',
      actionLabel: 'Vincular aparelho',
      onAction: () => context.push(GuardianPaths.pairing),
    );
  }
}

class _DeviceDashboard extends ConsumerWidget {
  const _DeviceDashboard({required this.device, this.now});

  final Device device;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DeviceState? state = device.state;
    final Policy? policy = ref.watch(devicePolicySnapshotProvider(device.id)).value?.policy;
    final int nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final bool paused = policy?.overrides.manualLock.isActiveAt(nowMs) ?? false;
    final Suspension? suspension = policy?.overrides.suspension;
    final bool suspended = suspension?.isActiveAt(nowMs) ?? false;

    return PageBody(
      children: <Widget>[
        const DeviceSelector(),
        _DeviceHeader(device: device, now: now),
        const SizedBox(height: AppSpacing.md),
        _TimeCard(device: device, now: now),
        if (state != null && (state.lockState.isLocked || paused)) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _LockBanner(device: device, state: state, paused: paused, now: now),
        ],
        if (suspended && suspension != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          NoticeBanner(
            icon: Icons.pause_circle_outline,
            title: 'Regras suspensas até ${formatClockMs(suspension.until)}',
            message:
                'Suspenso: ${suspension.scopes.map((SuspensionScope s) => s.label.toLowerCase()).join(', ')}.',
            actionLabel: 'Encerrar suspensão',
            onAction: () => endSuspension(context, ref, device),
          ),
        ],
        if (device.pendingTimeRequests > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          NoticeBanner(
            tone: Tone.warning,
            icon: Icons.more_time,
            title: device.pendingTimeRequests == 1
                ? '${device.displayName} pediu mais tempo'
                : '${device.displayName} fez ${device.pendingTimeRequests} pedidos de tempo',
            message: 'Responda para a criança saber se pode continuar.',
            actionLabel: 'Ver pedidos',
            onAction: () => context.go(GuardianPaths.alerts),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _QuickActions(device: device, policy: policy, paused: paused, suspended: suspended),
        if (state != null) ..._issueBanners(state),
        const SizedBox(height: AppSpacing.md),
        _TopApps(device: device),
        const SizedBox(height: AppSpacing.md),
        _RecentAlerts(now: now),
        const SizedBox(height: AppSpacing.md),
        _ProtectionCard(device: device),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  List<Widget> _issueBanners(DeviceState state) {
    return <Widget>[
      if (!state.enforcementActive) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        const NoticeBanner(
          tone: Tone.danger,
          title: 'Controle inativo no aparelho',
          message: 'O aparelho informou que as regras não estão sendo aplicadas.',
        ),
      ],
      for (final String issue in state.issues) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        NoticeBanner(
          tone: Tone.warning,
          title: describeIssue(issue).title,
          message: describeIssue(issue).message,
        ),
      ],
    ];
  }
}

class _DeviceHeader extends StatelessWidget {
  const _DeviceHeader({required this.device, this.now});

  final Device device;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? lastSync = device.lastSyncAt;
    final StatusPill connection;
    if (device.online) {
      connection = const StatusPill(label: 'Online', tone: Tone.success, icon: Icons.wifi);
    } else if (lastSync == null) {
      connection = const StatusPill(
        label: 'Nunca sincronizou',
        tone: Tone.warning,
        icon: Icons.cloud_off_outlined,
      );
    } else {
      final int ageMs = (now ?? DateTime.now()).millisecondsSinceEpoch - lastSync;
      connection = StatusPill(
        label: 'Visto ${formatRelativeMs(lastSync, now: now)}',
        tone: ageMs > const Duration(hours: 3).inMilliseconds ? Tone.warning : Tone.neutral,
        icon: Icons.cloud_off_outlined,
      );
    }
    final int? battery = device.state?.batteryPercent;
    final String name = device.displayName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(
                    name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(name, style: theme.textTheme.titleLarge),
                      Text(
                        battery == null
                            ? device.hardwareLabel
                            : '${device.hardwareLabel}. Bateria $battery%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                connection,
                if (device.policyPending)
                  const StatusPill(
                    label: 'Aguardando o aparelho confirmar',
                    tone: Tone.info,
                    icon: Icons.sync,
                  )
                else
                  const StatusPill(
                    label: 'Regras aplicadas no aparelho',
                    tone: Tone.success,
                    icon: Icons.check_circle_outline,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.device, this.now});

  final Device device;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DeviceState? state = device.state;
    if (state == null) {
      return const SectionCard(
        title: 'Tempo de hoje',
        child: NoticeBanner(
          icon: Icons.hourglass_empty,
          message:
              'Aguardando a primeira sincronização do aparelho. Abra o ParentaLynx no '
              'aparelho da criança e confira a conexão com a internet.',
        ),
      );
    }
    // O retrato pode ser de um dia anterior, se o aparelho ainda nao sincronizou hoje.
    final bool stale = device.today.isNotEmpty && state.day != device.today;
    final int used = stale ? 0 : state.quotaUsedMs;
    final int total = stale ? 0 : state.totalUsedMs;
    final int? limit = state.limitMs;
    final int? remaining = limit == null
        ? null
        : math.max(0, stale ? limit : (state.remainingMs ?? limit - used));
    final double fraction = limit == null ? 0 : (limit <= 0 ? 1 : (used / limit).clamp(0.0, 1.0));
    final StatusColors status = StatusColors.of(context);
    final Color ringColor = switch (quotaLevel(fraction)) {
      QuotaLevel.normal => theme.colorScheme.primary,
      QuotaLevel.attention => status.warning,
      QuotaLevel.exhausted => status.danger,
    };
    final String headline = remaining == null
        ? formatDurationMs(total)
        : formatDurationMs(remaining);
    final String caption = remaining == null ? 'usado hoje' : 'restante hoje';
    final TextStyle? muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return SectionCard(
      title: 'Tempo de hoje',
      child: Column(
        children: <Widget>[
          TimeRing(
            progress: fraction,
            color: ringColor,
            size: 196,
            semanticLabel: remaining == null
                ? 'Sem limite diário. Usado hoje: ${formatDurationMs(total)}'
                : 'Restam ${formatDurationMs(remaining)} de ${formatDurationMs(limit ?? 0)}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    headline,
                    key: const ValueKey<String>('dashboard-headline'),
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                Text(caption, style: muted),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _Figure(label: 'Usado', value: formatDurationMs(used)),
              ),
              Expanded(
                child: _Figure(
                  label: 'Limite de hoje',
                  value: limit == null ? 'Sem limite' : formatDurationMs(limit),
                ),
              ),
              Expanded(
                child: _Figure(label: 'Total no aparelho', value: formatDurationMs(total)),
              ),
            ],
          ),
          if (state.extraMs > 0 && !stale)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'O limite de hoje inclui ${formatDurationMs(state.extraMs)} de tempo extra.',
                style: muted,
              ),
            ),
          if (stale)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Sem dados de hoje. O aparelho sincronizou pela última vez '
                '${formatRelativeMs(state.reportedAt, now: now)}.',
                style: muted,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(value, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LockBanner extends ConsumerWidget {
  const _LockBanner({required this.device, required this.state, required this.paused, this.now});

  final Device device;
  final DeviceState state;
  final bool paused;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool reported = state.lockState.isLocked;
    final int? release = state.lockReleaseAt;
    final String title = reported ? state.lockState.label : DeviceLockState.manualLock.label;
    final String message;
    if (!reported) {
      message = 'Pausa enviada. Aguardando o aparelho confirmar.';
    } else if (release != null) {
      message = 'Liberação prevista ${formatReleaseTime(release, now: now)}.';
    } else if (state.lockState == DeviceLockState.manualLock) {
      message = 'Fica pausado até você retomar.';
    } else {
      message = 'Só as exceções estão disponíveis.';
    }
    return NoticeBanner(
      tone: Tone.danger,
      icon: Icons.lock_outline,
      title: title,
      message: message,
      actionLabel: paused ? 'Retomar agora' : null,
      onAction: paused ? () => resumeDevice(context, ref, device) : null,
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({
    required this.device,
    required this.policy,
    required this.paused,
    required this.suspended,
  });

  final Device device;
  final Policy? policy;
  final bool paused;
  final bool suspended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final int extraToday = policy?.overrides.extraMinutesFor(device.today) ?? 0;
    return SectionCard(
      title: 'Ações rápidas',
      subtitle: 'Enviadas na hora ao aparelho de ${device.displayName}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Tempo extra para hoje', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final int minutes in const <int>[15, 30, 60])
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(formatMinutes(minutes)),
                  onPressed: () => grantExtraTime(context, ref, device, minutes),
                ),
              ActionChip(
                label: const Text('Outro valor'),
                onPressed: () => grantCustomExtraTime(context, ref, device),
              ),
            ],
          ),
          if (extraToday > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Hoje já foram concedidos ${formatMinutes(extraToday)} extras.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          // Um botao por linha: os rotulos cabem inteiros mesmo com fonte grande.
          if (paused)
            FilledButton.icon(
              onPressed: () => resumeDevice(context, ref, device),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Retomar'),
            )
          else
            FilledButton.tonalIcon(
              onPressed: () => pauseDevice(context, ref, device),
              icon: const Icon(Icons.pause),
              label: const Text('Pausar agora'),
            ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: suspended
                ? () => endSuspension(context, ref, device)
                : () => suspendRules(context, ref, device),
            icon: Icon(suspended ? Icons.play_circle_outline : Icons.pause_circle_outline),
            label: Text(suspended ? 'Encerrar suspensão' : 'Suspender regras'),
          ),
        ],
      ),
    );
  }
}

class _TopApps extends ConsumerWidget {
  const _TopApps({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<DeviceApps> apps = ref.watch(deviceAppsProvider(device.id));
    final List<AppEntry> top = apps.value?.topToday() ?? const <AppEntry>[];
    final int maxMs = top.isEmpty ? 1 : top.first.todayMs;
    final Widget content;
    if (!apps.hasValue) {
      content = apps.hasError
          ? Text(
              'Não foi possível carregar os apps. Puxe para atualizar.',
              style: theme.textTheme.bodyMedium,
            )
          : const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
    } else if (top.isEmpty) {
      content = Text(
        'Nenhum uso registrado hoje.',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    } else {
      content = Column(
        children: <Widget>[
          for (final AppEntry app in top)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  AppIconView.forApp(app, size: 36),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                app.label,
                                style: theme.textTheme.bodyLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(formatDurationMs(app.todayMs), style: theme.textTheme.labelLarge),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (app.todayMs / maxMs).clamp(0.0, 1.0),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return SectionCard(
      title: 'Mais usados hoje',
      trailing: TextButton(
        onPressed: () => context.go(GuardianPaths.reports),
        child: const Text('Relatórios'),
      ),
      child: content,
    );
  }
}

/// Icone e tom de um tipo de alerta do protocolo.
({IconData icon, Tone tone}) _alertVisual(String type) {
  return switch (type) {
    'limit_reached' => (icon: Icons.timer_off_outlined, tone: Tone.warning),
    'low_time' => (icon: Icons.hourglass_bottom, tone: Tone.info),
    'blocked_app_attempt' => (icon: Icons.block, tone: Tone.danger),
    'sync_stale' || 'device_offline' => (icon: Icons.cloud_off_outlined, tone: Tone.warning),
    'policy_changed' => (icon: Icons.tune, tone: Tone.info),
    'enforcement_failure' => (icon: Icons.gpp_bad_outlined, tone: Tone.danger),
    'time_request' => (icon: Icons.more_time, tone: Tone.info),
    'permission_changed' => (icon: Icons.admin_panel_settings_outlined, tone: Tone.warning),
    'new_app_installed' => (icon: Icons.apps_outlined, tone: Tone.info),
    'security_event' => (icon: Icons.security, tone: Tone.danger),
    'device_linked' => (icon: Icons.link, tone: Tone.success),
    _ => (icon: Icons.notifications_none, tone: Tone.neutral),
  };
}

class _RecentAlerts extends ConsumerWidget {
  const _RecentAlerts({this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<AlertPreview>> alerts = ref.watch(recentAlertsProvider);
    final List<AlertPreview> items = alerts.value ?? const <AlertPreview>[];
    final TextStyle? muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final Widget content;
    if (!alerts.hasValue) {
      content = alerts.hasError
          ? Text('Não foi possível carregar os alertas.', style: muted)
          : const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
    } else if (items.isEmpty) {
      content = Text('Nenhum alerta recente.', style: muted);
    } else {
      content = Column(
        children: <Widget>[
          for (final AlertPreview alert in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _alertVisual(alert.type).tone.background(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _alertVisual(alert.type).icon,
                      size: 20,
                      color: _alertVisual(alert.type).tone.foreground(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(alert.title, style: theme.textTheme.titleSmall),
                        Text(alert.body, style: theme.textTheme.bodySmall),
                        Text(
                          formatRelativeMs(alert.createdAt, now: now),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return SectionCard(
      title: 'Alertas recentes',
      trailing: TextButton(
        onPressed: () => context.go(GuardianPaths.alerts),
        child: const Text('Ver todos'),
      ),
      child: content,
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  const _ProtectionCard({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DeviceManagementMode mode = device.managementMode;
    final ({List<String> guaranteed, List<String> notGuaranteed}) info = guaranteesOf(mode);
    return SectionCard(
      title: 'Nível de proteção',
      subtitle: 'Modo: ${mode.label}',
      trailing: mode.isSystemEnforced
          ? const StatusPill(
              label: 'Garantido pelo sistema',
              tone: Tone.success,
              icon: Icons.verified_user_outlined,
            )
          : const StatusPill(
              label: 'Não garantido',
              tone: Tone.warning,
              icon: Icons.report_gmailerrorred,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String item in mode.isSystemEnforced ? info.guaranteed : info.notGuaranteed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item', style: theme.textTheme.bodyMedium),
            ),
          if (!mode.isSystemEnforced)
            Text(
              'Tudo o que depende de permissões que a criança pode desativar é avisado a você '
              'por alerta, mas não pode ser impedido neste modo.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
