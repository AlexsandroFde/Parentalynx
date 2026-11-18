import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../app_management/domain/entities/allowed_app.dart';
import '../../../app_management/domain/entities/app_usage.dart';
import '../../../app_management/presentation/widgets/native_app_icon.dart';
import '../../../screen_time/domain/entities/child_time_request.dart';
import '../../../screen_time/presentation/texts/child_time_request_texts.dart';
import '../../../screen_time/presentation/widgets/child_time_request_sheet.dart';
import '../../domain/entities/agent_status.dart';
import '../../domain/entities/child_home_summary.dart';
import '../../domain/entities/child_lock.dart';
import '../../domain/services/permission_steps.dart';
import '../bloc/child_device_status/child_device_status_bloc.dart';
import '../bloc/child_home/child_home_bloc.dart';
import '../texts/home_texts.dart';
import '../widgets/active_control_pill.dart';
import '../widgets/child_problem_view.dart';

/// Tela inicial da crianca: quanto tempo resta (ou por que o aparelho esta em pausa e quando
/// volta), o pedido de mais tempo, o que continua liberado, o uso de hoje, as regras e quem
/// cuida delas.
///
/// Precisa, acima na arvore, do [ChildDeviceStatusBloc] (casca do modo crianca), do
/// [ChildHomeBloc] e do `TimeRequestSheetBloc` (rota da tela).
class ChildHomePage extends StatelessWidget {
  const ChildHomePage({super.key});

  Future<void> _requestTime(BuildContext context, AgentStatus status) async {
    final ChildHomeBloc home = context.read<ChildHomeBloc>();
    final ChildTimeRequest? pending = home.state.summary?.requests
        .where((ChildTimeRequest r) => r.status == ChildTimeRequestStatus.pending)
        .firstOrNull;
    final bool sent = await showChildTimeRequestSheet(
      context,
      guardianName: status.guardianName,
      pending: pending,
      now: status.now,
    );
    if (sent) {
      home.add(const ChildHomeTimeRequestSent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <BlocListener<Object?, Object?>>[
        // Regras novas chegam pela sincronizacao: recarrega o resumo quando a versao muda.
        BlocListener<ChildDeviceStatusBloc, ChildDeviceStatusState>(
          listenWhen: (ChildDeviceStatusState previous, ChildDeviceStatusState current) {
            final int? before = previous.statusOrNull?.policyVersion;
            final int? after = current.statusOrNull?.policyVersion;
            return before != null && after != null && before != after;
          },
          listener: (BuildContext context, ChildDeviceStatusState state) {
            context.read<ChildHomeBloc>().add(const ChildHomeRefreshRequested());
          },
        ),
        BlocListener<ChildHomeBloc, ChildHomeState>(
          listenWhen: (ChildHomeState previous, ChildHomeState current) {
            return previous.syncing && !current.syncing;
          },
          listener: (BuildContext context, ChildHomeState state) {
            // A atualizacao pode ter mudado o retrato do agente (regras, bloqueio).
            context.read<ChildDeviceStatusBloc>().add(
              const ChildDeviceStatusRefreshRequested(force: true),
            );
          },
        ),
        BlocListener<ChildHomeBloc, ChildHomeState>(
          listenWhen: (ChildHomeState previous, ChildHomeState current) {
            return current.notice != null && previous.notice != current.notice;
          },
          listener: (BuildContext context, ChildHomeState state) {
            final HomeNotice notice = state.notice!;
            showAppSnackBar(
              context,
              notice.message,
              tone: switch (notice.kind) {
                HomeNoticeKind.success => Tone.success,
                HomeNoticeKind.warning => Tone.warning,
                HomeNoticeKind.failure => Tone.danger,
              },
            );
          },
        ),
      ],
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<ChildDeviceStatusBloc, ChildDeviceStatusState>(
            builder: (BuildContext context, ChildDeviceStatusState state) {
              return StateSwitcher(
                child: switch (state) {
                  ChildDeviceStatusLoaded(:final AgentStatus status) => KeyedSubtree(
                    key: const ValueKey<String>('conteudo'),
                    child: BlocBuilder<ChildHomeBloc, ChildHomeState>(
                      builder: (BuildContext context, ChildHomeState home) {
                        final ChildHomeBloc bloc = context.read<ChildHomeBloc>();
                        return _HomeContent(
                          status: status,
                          data: home.summary,
                          syncing: home.syncing,
                          onSync: () => bloc.add(const ChildHomeSyncRequested()),
                          onRequestTime: () => _requestTime(context, status),
                          onOpenBrowser: () => bloc.add(const ChildHomeBrowserRequested()),
                          onLaunch: (AllowedApp app) => bloc.add(ChildHomeAppLaunchRequested(app)),
                        );
                      },
                    ),
                  ),
                  ChildDeviceStatusFailure() => KeyedSubtree(
                    key: const ValueKey<String>('erro'),
                    child: ChildProblemView(
                      onRetry: () => context.read<ChildDeviceStatusBloc>().add(
                        const ChildDeviceStatusRefreshRequested(force: true),
                      ),
                    ),
                  ),
                  ChildDeviceStatusInitial() || ChildDeviceStatusLoading() => const KeyedSubtree(
                    key: ValueKey<String>('carregando'),
                    child: _HomeSkeleton(),
                  ),
                },
              );
            },
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

  final AgentStatus status;
  final ChildHomeSummary? data;
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onRequestTime;
  final VoidCallback onOpenBrowser;
  final ValueChanged<AllowedApp> onLaunch;

  @override
  Widget build(BuildContext context) {
    final LockMessage? lock = lockMessage(status);
    final ChildLock activeLock = status.isLocked ? status.lock : ChildLock.none;
    final ReliefMessage? relief = reliefMessage(status);
    // No bloqueio por permissao desligada o painel principal ja explica e leva as permissoes.
    final String? attention = activeLock == ChildLock.tamperLock ? null : attentionMessage(status);
    final ChildTimeRequest? latest = data?.requests.firstOrNull;
    final String? nextPause = nextPauseText(status);
    final Widget? requestButton = _requestButton(activeLock);
    void openPermissions() => context.push(ChildPaths.permissions);
    return ChildPageBody(
      children: <Widget>[
        _Greeting(status: status),
        if (attention != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppBanner(
            tone: Tone.warning,
            icon: AppIcons.protectionWeak,
            title: 'O controle precisa de atenção',
            message: attention,
            actionLabel: attentionNeedsPermissions(status) ? 'Ver permissões' : null,
            onAction: openPermissions,
            liveRegion: true,
          ),
        ],
        if (relief != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppBanner(
            tone: Tone.success,
            icon: AppIcons.unlock,
            title: relief.title,
            message: relief.body,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (lock != null)
          _LockPanel(
            lock: activeLock,
            message: lock,
            onPermissions: activeLock == ChildLock.tamperLock ? openPermissions : null,
          )
        else
          _TimePanel(status: status),
        if (requestButton != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          requestButton,
        ],
        if (latest != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _RequestStatus(request: latest, now: status.now),
        ],
        if (nextPause != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          BulletLine(icon: AppIcons.bedtime, tone: Tone.rest, text: nextPause),
        ],
        if (status.managedBrowserEnabled) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppListGroup(
            children: <Widget>[
              AppListRow(
                leading: const AppIconTile(icon: AppIcons.web),
                title: 'Navegador seguro',
                subtitle: 'Para pesquisar e abrir sites com filtro.',
                onTap: onOpenBrowser,
              ),
            ],
          ),
        ],
        const SectionGap(),
        _AllowedSection(apps: data?.exceptions, onLaunch: onLaunch),
        const SectionGap(),
        _UsageSection(usage: data?.usage),
        const SectionGap(),
        _RulesSection(status: status, data: data),
        const SectionGap(),
        _GuardianSection(status: status, syncing: syncing, onSync: onSync),
        const SectionGap(),
        _AboutSection(status: status),
      ],
    );
  }

  /// "Pedir mais tempo": a acao principal quando o tempo conta ou acabou; de apoio durante uma
  /// pausa (o pedido chega ao responsavel, que decide); ausente sem limite ou com o controle
  /// desligado, quando pedir tempo nao muda nada.
  Widget? _requestButton(ChildLock activeLock) {
    switch (activeLock) {
      case ChildLock.none:
        return status.hasQuota
            ? AppButton.primary(
                label: 'Pedir mais tempo',
                icon: AppIcons.extraTime,
                expand: true,
                onPressed: onRequestTime,
              )
            : null;
      case ChildLock.dailyLimit:
        return AppButton.primary(
          label: 'Pedir mais tempo',
          icon: AppIcons.extraTime,
          expand: true,
          onPressed: onRequestTime,
        );
      case ChildLock.schedule || ChildLock.manualLock:
        return AppButton.secondary(
          label: 'Pedir mais tempo',
          icon: AppIcons.extraTime,
          expand: true,
          onPressed: onRequestTime,
        );
      case ChildLock.tamperLock:
        return null;
    }
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.status});

  final AgentStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppPageHeader(
          eyebrow: weekdayLong(status.now.weekday),
          title: status.childName.isEmpty ? 'Olá!' : 'Olá, ${status.childName}!',
          bottomSpacing: AppSpacing.sm,
        ),
        const ActiveControlPill(),
      ],
    );
  }
}

/// Tempo de hoje: o anel com o que resta (ou o aviso de que hoje nao ha limite).
class _TimePanel extends StatelessWidget {
  const _TimePanel({required this.status});

  final AgentStatus status;

  static const double _ringSize = 224;

  @override
  Widget build(BuildContext context) {
    final TimeDisplay display = timeDisplay(status);
    final AppColors colors = context.colors;
    final bool largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    if (display.level == TimeLevel.unlimited) {
      return AppPanel(
        padding: const EdgeInsets.all(AppSpacing.xl),
        semanticLabel: display.spoken,
        child: Column(
          children: <Widget>[
            const _Medallion(icon: AppIcons.available, tone: Tone.success),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Sem limite de tempo hoje',
              textAlign: TextAlign.center,
              style: context.text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              display.detail,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }
    final Color ring = switch (display.level) {
      TimeLevel.low => colors.warning,
      TimeLevel.over => colors.rest,
      TimeLevel.plenty || TimeLevel.unlimited => colors.primary,
    };
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: <Widget>[
          TimeRing(
            progress: display.progress,
            size: _ringSize,
            strokeWidth: AppSpacing.md,
            color: ring,
            semanticLabel: display.spoken,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _HeroValue(parts: display.parts),
                Text(
                  display.caption,
                  style: context.text.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Com a fonte ampliada o valor dentro do anel diminui: o mesmo valor vem em texto.
          if (largeText) ...<Widget>[
            Text(
              'Restam ${display.headline} para usar hoje.',
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(display.detail, textAlign: TextAlign.center, style: context.text.bodyLarge),
          if (display.level == TimeLevel.low) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              lowTimeHint,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ] else ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(resetText(status), textAlign: TextAlign.center, style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Numero em destaque com as unidades menores: `1`h `20`min.
class _HeroValue extends StatelessWidget {
  const _HeroValue({required this.parts});

  final List<(String, String)> parts;

  @override
  Widget build(BuildContext context) {
    final TextStyle number = context.textStyles.metricHero;
    final TextStyle unit = context.textStyles.metricMedium.copyWith(
      color: context.colors.textSecondary,
    );
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          for (int i = 0; i < parts.length; i++) ...<InlineSpan>[
            if (i > 0) TextSpan(text: ' ', style: unit),
            TextSpan(text: parts[i].$1, style: number),
            TextSpan(text: parts[i].$2, style: unit),
          ],
        ],
      ),
      maxLines: 1,
      softWrap: false,
    );
  }
}

/// Icone em destaque no topo dos paineis de estado.
class _Medallion extends StatelessWidget {
  const _Medallion({required this.icon, required this.tone});

  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return IconMedallion(icon: icon, tone: tone, size: AppSizes.illustration);
  }
}

/// Bloqueio em vigor: o motivo, quando acaba e o que continua funcionando. O icone usa o tom
/// de descanso (nunca o vermelho): uma pausa combinada, nao um castigo.
class _LockPanel extends StatelessWidget {
  const _LockPanel({required this.lock, required this.message, required this.onPermissions});

  final ChildLock lock;
  final LockMessage message;
  final VoidCallback? onPermissions;

  @override
  Widget build(BuildContext context) {
    final Tone tone = lock == ChildLock.tamperLock ? Tone.neutral : Tone.rest;
    final Color secondary = context.colors.textSecondary;
    final IconData icon = switch (lock) {
      ChildLock.dailyLimit => AppIcons.timeRunningOut,
      ChildLock.schedule => AppIcons.bedtime,
      ChildLock.manualLock => AppIcons.pause,
      ChildLock.tamperLock => AppIcons.protectionWeak,
      ChildLock.none => AppIcons.info,
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Medallion(icon: icon, tone: tone),
            const SizedBox(height: AppSpacing.lg),
            Semantics(header: true, child: Text(message.title, style: context.text.headlineSmall)),
            const SizedBox(height: AppSpacing.sm),
            Text(message.body, style: context.text.bodyLarge?.copyWith(color: secondary)),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(AppIcons.allowed, size: AppSizes.iconMd, color: secondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    lockedStillWorks,
                    style: context.text.bodyMedium?.copyWith(color: secondary),
                  ),
                ),
              ],
            ),
            if (onPermissions != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              AppButton.primary(
                label: 'Ver permissões',
                icon: AppIcons.protection,
                expand: true,
                onPressed: onPermissions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ultimo pedido de tempo e a resposta do responsavel.
class _RequestStatus extends StatelessWidget {
  const _RequestStatus({required this.request, required this.now});

  final ChildTimeRequest request;

  /// Hora do agente, para o tempo relativo nao depender do relogio do aparelho.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Tone tone) = switch (request.status) {
      ChildTimeRequestStatus.pending when !request.delivered => (AppIcons.offline, Tone.neutral),
      ChildTimeRequestStatus.pending => (AppIcons.pending, Tone.warning),
      ChildTimeRequestStatus.approved => (AppIcons.success, Tone.success),
      ChildTimeRequestStatus.denied => (AppIcons.info, Tone.neutral),
      ChildTimeRequestStatus.expired => (AppIcons.history, Tone.neutral),
    };
    // Fica no fundo da pagina, logo abaixo do botao: e o retorno do pedido, nao outro cartao.
    return MergeSemantics(
      child: Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppIconTile(icon: icon, tone: tone),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(childTimeRequestTitle(request), style: context.text.titleSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      childTimeRequestDetail(request, now: now),
                      style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    StatusBadge(
                      label: childTimeRequestStatusText(request),
                      tone: tone,
                      showIcon: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Apps que funcionam mesmo durante as pausas, a um toque de abrir.
class _AllowedSection extends StatelessWidget {
  const _AllowedSection({required this.apps, required this.onLaunch});

  final List<AllowedApp>? apps;
  final ValueChanged<AllowedApp> onLaunch;

  @override
  Widget build(BuildContext context) {
    final List<AllowedApp>? list = apps;
    return AppSection(
      title: 'Sempre liberados',
      subtitle: 'Funcionam mesmo quando o tempo acaba.',
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (list == null) ...<Widget>[
              const Skeleton(
                child: Row(
                  children: <Widget>[
                    SkeletonBox(width: _AppTile.iconSize, height: _AppTile.iconSize),
                    SizedBox(width: AppSpacing.lg),
                    SkeletonBox(width: _AppTile.iconSize, height: _AppTile.iconSize),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ] else if (list.isNotEmpty) ...<Widget>[
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final AllowedApp app in list) _AppTile(app: app, onTap: () => onLaunch(app)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const BulletLine(
              icon: AppIcons.emergency,
              tone: Tone.success,
              text: 'Ligações de emergência sempre funcionam.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Um app sempre liberado: icone e nome, como na tela inicial do aparelho.
class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.onTap});

  final AllowedApp app;
  final VoidCallback onTap;

  static const double iconSize = AppSizes.avatarLg - AppSpacing.sm;
  static const double _width = AppSizes.avatarLg + AppSpacing.xl;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Abrir ${app.label}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.shapes.controlRadius,
        child: SizedBox(
          width: _width,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: <Widget>[
                NativeAppIcon(packageName: app.packageName, size: iconSize),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  app.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.text.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Uso de hoje por app, com os mais usados primeiro.
class _UsageSection extends StatefulWidget {
  const _UsageSection({required this.usage});

  final List<AppUsage>? usage;

  @override
  State<_UsageSection> createState() => _UsageSectionState();
}

class _UsageSectionState extends State<_UsageSection> {
  static const int _collapsedCount = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final List<AppUsage>? usage = widget.usage;
    final bool canExpand = usage != null && usage.length > _collapsedCount;
    return AppSection(
      title: 'Uso de hoje',
      actionLabel: canExpand ? (_expanded ? 'Mostrar menos' : 'Ver todos (${usage.length})') : null,
      onAction: canExpand ? () => setState(() => _expanded = !_expanded) : null,
      child: switch (usage) {
        null => const SkeletonListGroup(),
        <AppUsage>[] => const AppPanel(
          child: EmptyState(
            compact: true,
            icon: AppIcons.apps,
            title: 'Nenhum app usado ainda hoje',
            message: 'O tempo de cada app aparece aqui.',
          ),
        ),
        final List<AppUsage> list => _UsageList(
          usage: _expanded ? list : list.take(_collapsedCount).toList(),
          top: list.first.ms,
        ),
      },
    );
  }
}

class _UsageList extends StatelessWidget {
  const _UsageList({required this.usage, required this.top});

  final List<AppUsage> usage;

  /// Uso do app mais usado, que enche a barra.
  final int top;

  @override
  Widget build(BuildContext context) {
    final int reference = top <= 0 ? 1 : top;
    return AppListGroup(
      children: <Widget>[
        for (final AppUsage app in usage)
          AppListRow(
            leading: NativeAppIcon(packageName: app.packageName, size: AppSizes.iconTile),
            title: app.label,
            titleStyle: context.text.bodyLarge,
            trailing: Text(formatDurationMs(app.ms), style: context.textStyles.metricSmall),
            below: UsageBar(fraction: app.ms / reference),
          ),
      ],
    );
  }
}

/// Regras que valem hoje, com o motivo de cada uma em frases curtas.
class _RulesSection extends StatelessWidget {
  const _RulesSection({required this.status, required this.data});

  final AgentStatus status;
  final ChildHomeSummary? data;

  @override
  Widget build(BuildContext context) {
    final ChildHomeSummary? details = data;
    final List<RuleLine>? lines = details == null
        ? null
        : details.policy == null
        ? const <RuleLine>[]
        : ruleLines(details.policy!, status: status);
    return AppSection(
      title: 'Regras de hoje',
      subtitle: status.guardianName.isEmpty ? null : 'Definidas por ${status.guardianName}',
      child: switch (lines) {
        null => const Skeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FractionallySizedBox(widthFactor: 0.7, child: SkeletonBox()),
              SizedBox(height: AppSpacing.md),
              FractionallySizedBox(widthFactor: 0.55, child: SkeletonBox()),
            ],
          ),
        ),
        <RuleLine>[] => Text(
          'As regras ainda não chegaram neste aparelho.',
          style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
        ),
        final List<RuleLine> list => Column(
          children: <Widget>[
            for (final RuleLine line in list)
              BulletLine(icon: _ruleIcon(line.kind), tone: _ruleTone(line.kind), text: line.text),
          ],
        ),
      },
    );
  }

  static IconData _ruleIcon(RuleKind kind) {
    return switch (kind) {
      RuleKind.dailyLimit => AppIcons.dailyLimit,
      RuleKind.reset => AppIcons.reset,
      RuleKind.allowedHours => AppIcons.allowedHours,
      RuleKind.blockPeriod => AppIcons.bedtime,
      RuleKind.blockedApps => AppIcons.blocked,
      RuleKind.newApps => AppIcons.newApp,
      RuleKind.web => AppIcons.web,
    };
  }

  /// Tom de cada regra. Bloqueios usam o neutro e pausas o descanso: nunca o vermelho.
  static Tone _ruleTone(RuleKind kind) {
    return switch (kind) {
      RuleKind.dailyLimit || RuleKind.reset || RuleKind.web => Tone.info,
      RuleKind.allowedHours => Tone.success,
      RuleKind.blockPeriod => Tone.rest,
      RuleKind.blockedApps || RuleKind.newApps => Tone.neutral,
    };
  }
}

/// Quem cuida das regras e se elas estao em dia neste aparelho.
class _GuardianSection extends StatelessWidget {
  const _GuardianSection({required this.status, required this.syncing, required this.onSync});

  final AgentStatus status;
  final bool syncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final ConnectionText connection = connectionText(status);
    final String guardian = status.guardianName.isEmpty ? 'Seu responsável' : status.guardianName;
    return AppSection(
      title: 'Responsável',
      child: AppListGroup(
        children: <Widget>[
          AppListRow(
            leading: InitialAvatar(name: guardian),
            title: guardian,
            subtitle: 'Cuida das regras deste aparelho',
          ),
          AppListRow(
            leading: AppIconTile(
              icon: connection.ok ? AppIcons.synced : AppIcons.offline,
              tone: connection.ok ? Tone.success : Tone.neutral,
            ),
            title: connection.title,
            subtitle: connection.detail,
            below: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.secondary(
                label: 'Atualizar agora',
                icon: AppIcons.refresh,
                size: AppButtonSize.compact,
                busy: syncing,
                onPressed: onSync,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Transparencia, permissoes e a area protegida do responsavel.
class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.status});

  final AgentStatus status;

  @override
  Widget build(BuildContext context) {
    final bool permissionsOk = requiredPermissionsGranted(
      buildPermissionSteps(status.permissions, manufacturer: ''),
    );
    return AppSection(
      title: 'Sobre o controle',
      child: AppListGroup(
        children: <Widget>[
          AppListRow(
            leading: const AppIconTile(icon: AppIcons.privacy),
            title: 'O que este app faz e o que ele não vê',
            onTap: () => context.push(ChildPaths.about),
          ),
          AppListRow(
            leading: AppIconTile(
              icon: AppIcons.protection,
              tone: permissionsOk ? Tone.info : Tone.warning,
            ),
            title: 'Permissões do controle',
            subtitle: permissionsOk ? 'Tudo ligado' : 'Falta ligar alguma permissão',
            onTap: () => context.push(ChildPaths.permissions),
          ),
          AppListRow(
            leading: const AppIconTile(icon: AppIcons.lock, tone: Tone.neutral),
            title: 'Área do responsável',
            subtitle: 'Só com a senha do responsável',
            onTap: () => context.push(ChildPaths.guardianArea),
          ),
        ],
      ),
    );
  }
}

/// Forma da tela inicial enquanto o agente responde pela primeira vez.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ChildPageBody(
      children: <Widget>[
        Skeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FractionallySizedBox(widthFactor: 0.3, child: SkeletonBox(height: AppSpacing.md)),
              SizedBox(height: AppSpacing.sm),
              FractionallySizedBox(widthFactor: 0.5, child: SkeletonBox(height: AppSpacing.xl)),
              SizedBox(height: AppSpacing.md),
              FractionallySizedBox(widthFactor: 0.55, child: SkeletonBox(height: AppSpacing.xl)),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xl),
        SkeletonPanel(height: _TimePanel._ringSize + AppSpacing.xxxl * 2),
        SizedBox(height: AppSpacing.xl),
        SkeletonListGroup(),
      ],
    );
  }
}
