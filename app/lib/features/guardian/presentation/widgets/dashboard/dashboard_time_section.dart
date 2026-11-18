import 'package:material_ui/material_ui.dart';

import '../../../../../core/time/formatters.dart';
import '../../../../../shared/design_system/design_system.dart';
import '../../../../child_device/domain/entities/child_device.dart';
import '../../../domain/entities/today_usage.dart';
import '../../bloc/dashboard/guardian_dashboard_bloc.dart';

/// Tempo de hoje: quanto falta (o numero principal do painel), os numeros do dia e, logo
/// abaixo, o tempo extra, que muda exatamente esse numero.
class DashboardTimeSection extends StatelessWidget {
  const DashboardTimeSection({
    required this.device,
    required this.extraMinutesToday,
    required this.running,
    required this.now,
    required this.onExtraTime,
    required this.onCustomExtraTime,
    required this.onAdjustLimit,
    super.key,
  });

  final ChildDevice device;

  /// Minutos extras ja concedidos hoje.
  final int extraMinutesToday;

  /// Comando em andamento: os botoes ficam fora de alcance e o tocado mostra o andamento.
  final DashboardCommand? running;
  final DateTime now;
  final ValueChanged<int> onExtraTime;
  final VoidCallback onCustomExtraTime;
  final VoidCallback onAdjustLimit;

  /// Valores prontos de tempo extra.
  static const List<int> presets = <int>[15, 30, 60];

  @override
  Widget build(BuildContext context) {
    final TodayUsage? today = TodayUsage.of(device);
    return AppSection(
      title: 'Tempo de hoje',
      actionLabel: today != null && !today.hasLimit ? 'Definir limite' : 'Ajustar limite',
      onAction: onAdjustLimit,
      child: AppPanel(
        child: today == null
            ? const EmptyState(
                compact: true,
                icon: AppIcons.pending,
                title: 'Aguardando a primeira sincronização',
                message:
                    'Abra o ParentaLynx no aparelho da criança e confira se ele está conectado '
                    'à internet. O tempo de hoje aparece aqui assim que ele sincronizar.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (today.hasLimit) _Remaining(today: today) else _UsedWithoutLimit(today),
                  if (today.hasLimit) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    MetricRow(
                      metrics: <MetricTile>[
                        MetricTile(value: formatDurationMs(today.usedMs), label: 'Usado'),
                        MetricTile(
                          value: formatDurationMs(today.limitMs ?? 0),
                          label: 'Limite de hoje',
                        ),
                        MetricTile(value: formatDurationMs(today.totalMs), label: 'Uso total'),
                      ],
                    ),
                  ],
                  if (today.includesExtra)
                    _Note(
                      icon: AppIcons.extraTime,
                      text:
                          'O limite de hoje inclui ${formatDurationMs(today.extraMs)} de tempo '
                          'extra.',
                    ),
                  if (today.stale)
                    _Note(
                      icon: AppIcons.syncProblem,
                      text:
                          'Ainda sem dados de hoje: o aparelho sincronizou pela última vez '
                          '${formatRelativeMs(today.reportedAt, now: now)}.',
                    ),
                  if (today.hasLimit) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(height: AppSizes.hairline),
                    const SizedBox(height: AppSpacing.lg),
                    _ExtraTime(
                      extraMinutesToday: extraMinutesToday,
                      running: running,
                      outsideAllowedHours: device.snapshot?.lockState == DeviceLockState.schedule,
                      onExtraTime: onExtraTime,
                      onCustomExtraTime: onCustomExtraTime,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// O tempo que falta em destaque e uma barra com a parte do limite ja usada. Com fonte ampliada,
/// a frase completa aparece logo abaixo.
class _Remaining extends StatelessWidget {
  const _Remaining({required this.today});

  final TodayUsage today;

  @override
  Widget build(BuildContext context) {
    final int remaining = today.remainingMs ?? 0;
    final int limit = today.limitMs ?? 0;
    final Color color = switch (today.level) {
      QuotaLevel.normal => context.colors.primary,
      QuotaLevel.attention => context.colors.warning,
      // Limite atingido e descanso combinado, nao erro.
      QuotaLevel.exhausted => context.colors.rest,
    };
    final String sentence =
        'Restam ${formatDurationMs(remaining)} de ${formatDurationMs(limit)} hoje.';
    final bool largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Semantics(
      container: true,
      label: sentence,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: <Widget>[
              Text(
                formatDurationMs(remaining),
                key: const ValueKey<String>('dashboard-headline'),
                style: context.textStyles.metricLarge,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs + AppSpacing.xxs),
                child: Text(
                  'restam hoje',
                  style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          UsageBar(fraction: today.fraction, color: color, height: AppSpacing.xs + AppSpacing.xxs),
          if (largeText) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(sentence, style: context.text.titleSmall),
          ],
        ],
      ),
    );
  }
}

/// Sem limite diario o tempo so e acompanhado: um numero, sem anel.
class _UsedWithoutLimit extends StatelessWidget {
  const _UsedWithoutLimit(this.today);

  final TodayUsage today;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MetricTile(value: formatDurationMs(today.totalMs), label: 'usados hoje', emphasis: true),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Sem limite diário: o tempo é só acompanhado. Para limitar, defina um limite nas '
          'regras.',
          style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

/// Linha de observacao dentro do painel do tempo.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Icon(icon, size: AppSizes.iconSm, color: context.colors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: context.text.bodySmall)),
        ],
      ),
    );
  }
}

/// Tempo extra para hoje: valores prontos e um valor proprio. Um toque envia; o botao tocado
/// mostra o andamento e os outros esperam.
class _ExtraTime extends StatelessWidget {
  const _ExtraTime({
    required this.extraMinutesToday,
    required this.running,
    required this.outsideAllowedHours,
    required this.onExtraTime,
    required this.onCustomExtraTime,
  });

  final int extraMinutesToday;
  final DashboardCommand? running;
  final bool outsideAllowedHours;
  final ValueChanged<int> onExtraTime;
  final VoidCallback onCustomExtraTime;

  @override
  Widget build(BuildContext context) {
    final bool idle = running == null;
    final int? sending = running?.kind == DashboardCommandKind.extraTime ? running?.minutes : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    child: Text('Tempo extra para hoje', style: context.text.titleSmall),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Soma ao limite de hoje. Amanhã volta ao normal.',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton.tertiary(
              label: 'Outro valor',
              size: AppButtonSize.compact,
              busy: sending != null && !DashboardTimeSection.presets.contains(sending),
              onPressed: idle ? onCustomExtraTime : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final int minutes in DashboardTimeSection.presets)
              AppButton.secondary(
                label: '+ ${formatMinutes(minutes)}',
                size: AppButtonSize.compact,
                busy: sending == minutes,
                onPressed: idle ? () => onExtraTime(minutes) : null,
              ),
          ],
        ),
        if (extraMinutesToday > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Hoje você já deu ${formatMinutes(extraMinutesToday)} a mais.',
            style: context.text.bodySmall,
          ),
        ],
        if (outsideAllowedHours) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'O tempo extra não libera o aparelho fora do horário permitido.',
            style: context.text.bodySmall,
          ),
        ],
      ],
    );
  }
}
