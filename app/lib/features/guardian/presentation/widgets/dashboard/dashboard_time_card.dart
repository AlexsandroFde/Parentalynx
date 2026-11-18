import 'package:material_ui/material_ui.dart';

import '../../../../../core/time/formatters.dart';
import '../../../../../shared/theme/app_theme.dart';
import '../../../../../shared/widgets/feedback_views.dart';
import '../../../../../shared/widgets/form_widgets.dart';
import '../../../../../shared/widgets/time_ring.dart';
import '../../../domain/entities/today_usage.dart';

/// Tempo de hoje: anel com o restante (ou o usado, sem limite) e os numeros do dia.
class DashboardTimeCard extends StatelessWidget {
  const DashboardTimeCard({required this.usage, required this.now, super.key});

  /// Nulo enquanto o aparelho nao sincronizou pela primeira vez.
  final TodayUsage? usage;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TodayUsage? today = usage;
    if (today == null) {
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
    final int? limit = today.limitMs;
    final int? remaining = today.remainingMs;
    final StatusColors status = StatusColors.of(context);
    final Color ringColor = switch (today.level) {
      QuotaLevel.normal => theme.colorScheme.primary,
      QuotaLevel.attention => status.warning,
      QuotaLevel.exhausted => status.danger,
    };
    final String headline = remaining == null
        ? formatDurationMs(today.totalMs)
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
            progress: today.fraction,
            color: ringColor,
            size: 196,
            semanticLabel: remaining == null
                ? 'Sem limite diário. Usado hoje: ${formatDurationMs(today.totalMs)}'
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
                child: _Figure(label: 'Usado', value: formatDurationMs(today.usedMs)),
              ),
              Expanded(
                child: _Figure(
                  label: 'Limite de hoje',
                  value: limit == null ? 'Sem limite' : formatDurationMs(limit),
                ),
              ),
              Expanded(
                child: _Figure(label: 'Total no aparelho', value: formatDurationMs(today.totalMs)),
              ),
            ],
          ),
          if (today.includesExtra)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'O limite de hoje inclui ${formatDurationMs(today.extraMs)} de tempo extra.',
                style: muted,
              ),
            ),
          if (today.stale)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Sem dados de hoje. O aparelho sincronizou pela última vez '
                '${formatRelativeMs(today.reportedAt, now: now)}.',
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
