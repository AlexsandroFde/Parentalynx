import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../../shared/widgets/time_ring.dart';
import '../../agent/data/child_agent_repository.dart';
import '../../agent/domain/child_models.dart';
import '../../agent/presentation/child_session.dart';
import '../../child_paths.dart';
import '../../shared/child_widgets.dart';
import '../domain/home_texts.dart';
import 'child_home_controller.dart';
import 'time_request_sheet.dart';

/// Tela inicial da crianca: tempo restante, bloqueio em vigor, uso de hoje e regras.
class ChildHomePage extends ConsumerStatefulWidget {
  const ChildHomePage({super.key});

  @override
  ConsumerState<ChildHomePage> createState() => _ChildHomePageState();
}

class _ChildHomePageState extends ConsumerState<ChildHomePage> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    if (_syncing) {
      return;
    }
    setState(() => _syncing = true);
    try {
      final SyncResult result = await ref.read(childAgentRepositoryProvider).syncNow();
      await ref.read(agentStatusProvider.notifier).refresh();
      await ref.read(childHomeDataProvider.notifier).refresh();
      if (mounted) {
        showAppSnackBar(
          context,
          syncResultMessage(result),
          tone: result.ok ? Tone.success : Tone.warning,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _requestTime(ChildStatus status) async {
    final bool sent = await showTimeRequestSheet(context, guardianName: status.guardianName);
    if (!sent || !mounted) {
      return;
    }
    showAppSnackBar(context, 'Pedido enviado. Você vê a resposta aqui.', tone: Tone.success);
    await ref.read(childHomeDataProvider.notifier).refresh();
  }

  Future<void> _openBrowser() async {
    try {
      await ref.read(childAgentRepositoryProvider).openManagedBrowser();
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _launch(AllowedApp app) async {
    try {
      final bool opened = await ref.read(childAgentRepositoryProvider).launchApp(app.packageName);
      if (!opened && mounted) {
        showAppSnackBar(context, 'Não foi possível abrir ${app.label}.', tone: Tone.warning);
      }
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Regras novas chegam pela sincronizacao: recarrega o resumo quando a versao muda.
    ref.listen<int?>(
      agentStatusProvider.select((AsyncValue<ChildStatus> value) => value.value?.policyVersion),
      (int? previous, int? next) {
        if (previous != null && next != null && previous != next) {
          unawaited(ref.read(childHomeDataProvider.notifier).refresh());
        }
      },
    );
    final AsyncValue<ChildStatus> status = ref.watch(agentStatusProvider);
    return Scaffold(
      body: SafeArea(
        child: AsyncValueView<ChildStatus>(
          value: status,
          onRetry: () => ref.invalidate(agentStatusProvider),
          data: (ChildStatus data) => _HomeContent(
            status: data,
            data: ref.watch(childHomeDataProvider).value,
            syncing: _syncing,
            onSync: _syncNow,
            onRequestTime: () => _requestTime(data),
            onOpenBrowser: _openBrowser,
            onLaunch: _launch,
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.status,
    required this.data,
    required this.syncing,
    required this.onSync,
    required this.onRequestTime,
    required this.onOpenBrowser,
    required this.onLaunch,
  });

  final ChildStatus status;
  final ChildHomeData? data;
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onRequestTime;
  final VoidCallback onOpenBrowser;
  final ValueChanged<AllowedApp> onLaunch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LockMessage? lock = lockMessage(status);
    final String? relief = reliefMessage(status);
    final String? attention = attentionMessage(status);
    final ChildHomeData? details = data;
    final int? nextBlockAt = status.nextBlockAtMs;
    return ChildPageBody(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      status.childName.isEmpty ? 'Olá!' : 'Olá, ${status.childName}!',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const ActiveControlPill(),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Área do responsável',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => context.push(ChildPaths.guardianArea),
            ),
          ],
        ),
        if (attention != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          NoticeBanner(
            tone: Tone.warning,
            title: 'O controle precisa de atenção',
            message: attention,
            actionLabel: 'Ver permissões',
            onAction: () => context.push(ChildPaths.permissions),
          ),
        ],
        if (lock != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _LockCard(message: lock, lock: status.lock),
        ],
        if (relief != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          NoticeBanner(tone: Tone.success, icon: Icons.lock_open_rounded, message: relief),
        ],
        const SizedBox(height: AppSpacing.lg),
        _TimeCard(status: status),
        const SizedBox(height: AppSpacing.lg),
        BusyButton(
          label: 'Pedir mais tempo',
          icon: Icons.more_time_rounded,
          onPressed: onRequestTime,
        ),
        if (status.managedBrowserEnabled) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          BusyButton(
            label: 'Abrir o navegador seguro',
            icon: Icons.public_rounded,
            tonal: true,
            onPressed: onOpenBrowser,
          ),
        ],
        if (nextBlockAt != null && !status.isLocked) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          NoticeBanner(
            tone: Tone.neutral,
            icon: Icons.schedule_rounded,
            message:
                'Próxima pausa: ${_nextBlockLabel(status)} '
                '${formatReleaseTime(nextBlockAt, now: _now(status))}.',
          ),
        ],
        if (details != null && details.requests.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _RequestsCard(requests: details.requests.take(3).toList(), now: _now(status)),
        ],
        const SizedBox(height: AppSpacing.lg),
        _UsageCard(usage: details?.usage),
        const SizedBox(height: AppSpacing.lg),
        _ExceptionsCard(apps: details?.exceptions, onLaunch: onLaunch),
        const SizedBox(height: AppSpacing.lg),
        _RulesCard(status: status, data: details),
        const SizedBox(height: AppSpacing.lg),
        _ConnectionCard(status: status, syncing: syncing, onSync: onSync),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton.icon(
            onPressed: () => context.push(ChildPaths.about),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('O que este app faz e o que ele não vê'),
          ),
        ),
      ],
    );
  }

  static DateTime _now(ChildStatus status) => DateTime.fromMillisecondsSinceEpoch(status.nowMs);

  static String _nextBlockLabel(ChildStatus status) {
    final String? label = status.nextBlockLabel;
    return label == null || label.isEmpty ? 'começa' : label;
  }
}

class _LockCard extends StatelessWidget {
  const _LockCard({required this.message, required this.lock});

  final LockMessage message;
  final ChildLock lock;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final StatusColors colors = StatusColors.of(context);
    final IconData icon = switch (lock) {
      ChildLock.dailyLimit => Icons.hourglass_bottom_rounded,
      ChildLock.schedule => Icons.bedtime_outlined,
      ChildLock.manualLock => Icons.pause_circle_outline_rounded,
      ChildLock.tamperLock => Icons.gpp_maybe_outlined,
      ChildLock.none => Icons.info_outline,
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.warningContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: colors.warning, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(message.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(message.body, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    lockedStillWorks,
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
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.status});

  final ChildStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final StatusColors colors = StatusColors.of(context);
    final TimeDisplay display = timeDisplay(status);
    final Color ringColor = switch (display.level) {
      TimeLevel.unlimited || TimeLevel.plenty => theme.colorScheme.primary,
      TimeLevel.low => colors.warning,
      TimeLevel.over => colors.danger,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
        child: Column(
          children: <Widget>[
            TimeRing(
              progress: display.progress,
              color: ringColor,
              semanticLabel: '${display.headline} ${display.caption}',
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        display.headline,
                        maxLines: 1,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Text(
                      display.caption,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(display.detail, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (status.hasQuota) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'O tempo recomeça '
                '${formatReleaseTime(status.nextResetAtMs, now: DateTime.fromMillisecondsSinceEpoch(status.nowMs))}.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestsCard extends StatelessWidget {
  const _RequestsCard({required this.requests, required this.now});

  final List<TimeRequest> requests;

  /// Hora do agente, para o tempo relativo nao depender do relogio do aparelho.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      title: 'Seus pedidos',
      child: Column(
        children: <Widget>[
          for (final TimeRequest request in requests)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(timeRequestAmount(request), style: theme.textTheme.bodyLarge),
                        Text(
                          formatRelativeMs(request.createdAtMs, now: now),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: StatusPill(
                      label: timeRequestText(request),
                      tone: switch (request.state) {
                        TimeRequestState.approved => Tone.success,
                        TimeRequestState.denied => Tone.neutral,
                        TimeRequestState.expired => Tone.neutral,
                        TimeRequestState.pending => Tone.info,
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UsageCard extends StatefulWidget {
  const _UsageCard({required this.usage});

  final List<AppUsage>? usage;

  @override
  State<_UsageCard> createState() => _UsageCardState();
}

class _UsageCardState extends State<_UsageCard> {
  static const int _collapsedCount = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<AppUsage>? usage = widget.usage;
    if (usage == null) {
      return const SectionCard(title: 'Uso de hoje', child: LinearProgressIndicator());
    }
    if (usage.isEmpty) {
      return SectionCard(
        title: 'Uso de hoje',
        child: Text(
          'Nenhum app foi usado hoje ainda.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    final int top = usage.first.ms <= 0 ? 1 : usage.first.ms;
    final List<AppUsage> shown = _expanded ? usage : usage.take(_collapsedCount).toList();
    return SectionCard(
      title: 'Uso de hoje',
      child: Column(
        children: <Widget>[
          for (final AppUsage app in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  NativeAppIcon(packageName: app.packageName, size: 36),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(formatDurationMs(app.ms), style: theme.textTheme.labelLarge),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            value: (app.ms / top).clamp(0.0, 1.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (usage.length > _collapsedCount)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Mostrar menos' : 'Ver todos (${usage.length})'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExceptionsCard extends StatelessWidget {
  const _ExceptionsCard({required this.apps, required this.onLaunch});

  final List<AllowedApp>? apps;
  final ValueChanged<AllowedApp> onLaunch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<AllowedApp> list = apps ?? const <AllowedApp>[];
    return SectionCard(
      title: 'Sempre liberados',
      subtitle: 'Funcionam mesmo quando o tempo acaba.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (list.isNotEmpty) ...<Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final AllowedApp app in list)
                  ActionChip(
                    avatar: NativeAppIcon(packageName: app.packageName, size: 24),
                    label: Text(app.label),
                    tooltip: 'Abrir ${app.label}',
                    onPressed: () => onLaunch(app),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: <Widget>[
              Icon(Icons.emergency_outlined, size: 20, color: StatusColors.of(context).success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Ligações de emergência e as funções essenciais do aparelho nunca são '
                  'bloqueadas.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.status, required this.data});

  final ChildStatus status;
  final ChildHomeData? data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ChildHomeData? details = data;
    if (details == null) {
      return const SectionCard(title: 'Regras de hoje', child: LinearProgressIndicator());
    }
    final List<RuleLine> lines = details.policy == null
        ? const <RuleLine>[]
        : ruleLines(details.policy!, status: status);
    return SectionCard(
      title: 'Regras de hoje',
      subtitle: status.guardianName.isEmpty ? null : 'Definidas por ${status.guardianName}',
      child: lines.isEmpty
          ? Text(
              'As regras ainda não chegaram neste aparelho.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: <Widget>[
                for (final RuleLine line in lines)
                  BulletLine(
                    icon: switch (line.kind) {
                      RuleKind.dailyLimit => Icons.timer_outlined,
                      RuleKind.reset => Icons.restart_alt_rounded,
                      RuleKind.allowedHours => Icons.wb_sunny_outlined,
                      RuleKind.blockPeriod => Icons.bedtime_outlined,
                      RuleKind.blockedApps => Icons.block_rounded,
                      RuleKind.newApps => Icons.new_releases_outlined,
                      RuleKind.web => Icons.public_rounded,
                    },
                    text: line.text,
                  ),
              ],
            ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.status, required this.syncing, required this.onSync});

  final ChildStatus status;
  final bool syncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ConnectionText connection = connectionText(status);
    final StatusColors colors = StatusColors.of(context);
    return SectionCard(
      title: 'Responsável',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.person_outline, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  status.guardianName.isEmpty ? 'Seu responsável' : status.guardianName,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                connection.ok ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: connection.ok ? colors.success : colors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(connection.text, style: theme.textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          BusyButton(
            label: 'Sincronizar agora',
            icon: Icons.sync_rounded,
            tonal: true,
            busy: syncing,
            onPressed: onSync,
          ),
        ],
      ),
    );
  }
}
