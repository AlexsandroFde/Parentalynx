import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../app_management/presentation/widgets/app_category_ui.dart';
import '../../../app_management/presentation/widgets/app_icon_view.dart';
import '../../domain/entities/event_group.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/entities/report_summary.dart';
import '../texts/report_texts.dart';
import 'charts.dart';

/// Endereco da lista de eventos do periodo, ja filtrada por um grupo.
String eventsLocation(String from, String to, {EventGroup group = EventGroup.all}) {
  final String base = ReportsPaths.eventsIn(from, to);
  return group == EventGroup.all ? base : '$base&group=${group.name}';
}

/// Conteudo do relatorio de um periodo: o resumo primeiro e os detalhes abaixo (graficos so
/// onde a forma dos dados importa, listas com o valor exato e os atalhos para os detalhes).
class ReportBody extends StatelessWidget {
  const ReportBody({required this.summary, required this.period, required this.today, super.key});

  final ReportSummary summary;

  /// Periodo dos dados mostrados (pode ser o anterior enquanto o novo carrega).
  final ReportPeriod period;

  /// Dia da cota corrente do aparelho.
  final String today;

  @override
  Widget build(BuildContext context) {
    final bool empty = !summary.hasUsage && summary.totals.blockedAttempts == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (empty)
          const AppPanel(
            child: EmptyState(
              compact: true,
              icon: AppIcons.elapsed,
              title: 'Sem uso registrado neste período',
              message:
                  'Se o aparelho foi usado, confira se ele está conectado e se a permissão de '
                  'acesso ao uso continua ativa.',
            ),
          )
        else ...<Widget>[
          _SummarySection(summary: summary, period: period, today: today),
          if (summary.isMultiDay) ...<Widget>[
            const SectionGap(),
            _DailySection(summary: summary, today: today),
          ],
          if (summary.apps.isNotEmpty) ...<Widget>[
            const SectionGap(),
            _AppsSection(summary: summary),
          ],
          if (summary.hasUsage) ...<Widget>[const SectionGap(), _HourlySection(summary: summary)],
          if (summary.usedCategories.isNotEmpty) ...<Widget>[
            const SectionGap(),
            _CategoriesSection(summary: summary),
          ],
          if (summary.blockedByApp.isNotEmpty) ...<Widget>[
            const SectionGap(),
            _BlockedSection(summary: summary, period: period),
          ],
        ],
        const SectionGap(),
        _DetailsSection(period: period),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary, required this.period, required this.today});

  final ReportSummary summary;
  final ReportPeriod period;
  final String today;

  @override
  Widget build(BuildContext context) {
    final ReportTotals totals = summary.totals;
    final int outside = totals.totalMs - totals.quotaMs;
    final int? dayLimit = summary.daily.length == 1 ? summary.daily.single.limitMs : null;
    final List<MetricTile> metrics = summary.isMultiDay || summary.daily.isEmpty
        ? <MetricTile>[
            MetricTile(value: formatDurationMs(totals.avgPerDayMs), label: 'Média por dia'),
            MetricTile(value: '${totals.blockedAttempts}', label: 'Tentativas bloqueadas'),
            MetricTile(value: '${totals.opens}', label: 'Aberturas de apps'),
          ]
        : <MetricTile>[
            MetricTile(value: formatDurationMs(totals.quotaMs), label: 'Conta no limite'),
            MetricTile(
              value: dayLimit == null ? 'Sem limite' : formatDurationMs(dayLimit),
              label: 'Limite do dia',
            ),
            MetricTile(value: '${totals.blockedAttempts}', label: 'Tentativas bloqueadas'),
          ];
    return AppSection(
      title: 'Resumo',
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      formatDurationMs(totals.totalMs),
                      key: const ValueKey<String>('report-total'),
                      maxLines: 1,
                      style: context.textStyles.metricLarge,
                    ),
                  ),
                  Text(
                    period.totalCaption(today: today),
                    style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (outside > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${formatDurationMs(outside)} não contaram no limite (apps de exceção ou regras '
                'suspensas).',
                style: context.text.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            MetricRow(metrics: metrics),
          ],
        ),
      ),
    );
  }
}

class _DailySection extends StatelessWidget {
  const _DailySection({required this.summary, required this.today});

  final ReportSummary summary;
  final String today;

  @override
  Widget build(BuildContext context) {
    final List<DailyUsage> daily = summary.daily;
    final AppChartStyle style = AppChartStyle.of(context);
    DailyUsage most = daily.first;
    DailyUsage least = daily.first;
    for (final DailyUsage day in daily) {
      if (day.totalMs > most.totalMs) {
        most = day;
      }
      if (day.totalMs < least.totalMs) {
        least = day;
      }
    }
    final String average = formatDurationMs(summary.totals.avgPerDayMs);
    final String mostLabel = '${formatDayLabel(most.day)}, ${formatDurationMs(most.totalMs)}';
    return ChartSection(
      title: 'Uso por dia',
      subtitle: 'Mais uso em $mostLabel. Média de $average por dia.',
      semanticSummary:
          'Gráfico de barras do uso por dia. Mais uso em $mostLabel; menos uso em '
          '${formatDayLabel(least.day)}, ${formatDurationMs(least.totalMs)}. Média de $average '
          'por dia. Os valores de cada dia estão em Ver valores.',
      legend: <ChartLegendItem>[
        ChartLegendItem(style.seriesColor(0), 'Conta no limite'),
        ChartLegendItem(style.seriesColor(1), 'Não conta no limite'),
        ChartLegendItem(style.track, 'Limite do dia'),
        ChartLegendItem(context.colors.textSecondary, 'Média do período (linha tracejada)'),
      ],
      chart: DailyUsageChart(daily: daily, today: today, averageMs: summary.totals.avgPerDayMs),
      values: AppListGroup(
        footer: 'Toque em um dia para ver a linha do tempo.',
        children: <Widget>[
          for (final DailyUsage day in daily)
            AppListRow(
              title: formatDayRelative(day.day, today: today) == formatDayLabel(day.day)
                  ? formatDayLabel(day.day)
                  : '${formatDayRelative(day.day, today: today)}, ${formatDayLabel(day.day)}',
              titleStyle: context.text.bodyLarge,
              subtitle: _dayDetail(day),
              trailing: Text(formatDurationMs(day.totalMs), style: context.textStyles.metricSmall),
              showChevron: true,
              onTap: () => context.push(ReportsPaths.sessionsOf(day.day)),
            ),
        ],
      ),
    );
  }

  static String _dayDetail(DailyUsage day) {
    if (day.totalMs <= 0 && day.blockedAttempts == 0) {
      return 'Sem uso';
    }
    final int? limit = day.limitMs;
    return <String>[
      'no limite ${formatDurationMs(day.quotaMs)}'
          '${limit == null ? ', sem limite' : ' de ${formatDurationMs(limit)}'}',
      if (day.blockedAttempts > 0)
        '${day.blockedAttempts} ${day.blockedAttempts == 1 ? 'bloqueio' : 'bloqueios'}',
    ].join(' · ');
  }
}

class _HourlySection extends StatelessWidget {
  const _HourlySection({required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final List<int> hourly = summary.hourly;
    final int? peak = summary.peakHour;
    final List<int> used = <int>[
      for (int hour = 0; hour < hourly.length; hour++)
        if (hourly[hour] > 0) hour,
    ];
    final int peakMs = peak == null ? 1 : hourly[peak];
    final String takeaway = peak == null
        ? 'Sem uso por hora no período.'
        : 'Mais uso entre ${peak}h e ${peak + 1}h: ${formatDurationMs(peakMs)} no período.';
    return ChartSection(
      title: 'Horários de uso',
      subtitle: takeaway,
      semanticSummary: used.isEmpty
          ? 'Gráfico de uso por hora do dia, sem uso no período.'
          : 'Gráfico de barras do uso por hora do dia. Uso entre ${used.first}h e '
                '${used.last + 1}h. $takeaway',
      height: 176,
      chart: HourlyChart(hourly: hourly),
      values: AppListGroup(
        children: <Widget>[
          for (final int hour in used)
            AppListRow(
              title: hourRangeLabel(hour),
              titleStyle: context.text.bodyLarge,
              trailing: Text(formatDurationMs(hourly[hour]), style: context.textStyles.metricSmall),
              below: UsageBar(fraction: hourly[hour] / peakMs),
            ),
        ],
      ),
    );
  }
}

/// Apps do periodo, do mais usado para o menos usado, com os 8 primeiros a vista.
class _AppsSection extends StatefulWidget {
  const _AppsSection({required this.summary});

  final ReportSummary summary;

  @override
  State<_AppsSection> createState() => _AppsSectionState();
}

class _AppsSectionState extends State<_AppsSection> {
  static const int _preview = 8;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final ReportSummary summary = widget.summary;
    final List<AppUsage> apps = _all ? summary.apps : summary.topApps(limit: _preview);
    final int maxMs = summary.apps.isEmpty ? 1 : summary.apps.first.totalMs;
    final bool more = summary.apps.length > _preview;
    return AppSection(
      title: 'Aplicativos mais usados',
      subtitle:
          '${summary.apps.length} ${summary.apps.length == 1 ? 'app usado' : 'apps usados'} '
          'no período',
      actionLabel: more ? (_all ? 'Ver menos' : 'Ver todos') : null,
      onAction: more ? () => setState(() => _all = !_all) : null,
      child: AppListGroup(
        children: <Widget>[
          for (final AppUsage app in apps)
            AppListRow(
              leading: AppIconView(package: app.package, label: app.label, size: AppSizes.iconTile),
              title: app.label,
              titleStyle: context.text.bodyLarge,
              subtitle: <String>[
                opensLabel(app.opens),
                if (summary.percentOfTotal(app.totalMs) case final int percent)
                  '$percent% do tempo',
                if (app.blockedAttempts > 0) '${timesLabel(app.blockedAttempts)} bloqueado',
              ].join(' · '),
              trailing: Text(formatDurationMs(app.totalMs), style: context.textStyles.metricSmall),
              below: UsageBar(fraction: maxMs <= 0 ? 0 : app.totalMs / maxMs),
            ),
        ],
      ),
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final List<CategoryUsage> categories = summary.usedCategories;
    final int maxMs = categories.first.totalMs;
    return AppSection(
      title: 'Por categoria',
      child: AppListGroup(
        children: <Widget>[
          for (final CategoryUsage category in categories)
            AppListRow(
              leading: AppIconTile(icon: category.category.icon, tone: Tone.neutral),
              title: category.category.label,
              titleStyle: context.text.bodyLarge,
              subtitle: switch (summary.percentOfTotal(category.totalMs)) {
                final int percent => '$percent% do tempo',
                null => null,
              },
              trailing: Text(
                formatDurationMs(category.totalMs),
                style: context.textStyles.metricSmall,
              ),
              below: UsageBar(fraction: maxMs <= 0 ? 0 : category.totalMs / maxMs),
            ),
        ],
      ),
    );
  }
}

class _BlockedSection extends StatelessWidget {
  const _BlockedSection({required this.summary, required this.period});

  final ReportSummary summary;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final List<BlockedApp> apps = summary.blockedByApp.take(8).toList();
    final int maxCount = apps.first.count;
    return AppSection(
      title: 'Apps bloqueados que tentou abrir',
      subtitle: '${timesLabel(summary.totals.blockedAttempts)} no período',
      actionLabel: 'Ver eventos',
      onAction: () =>
          context.push(eventsLocation(period.from, period.to, group: EventGroup.blocks)),
      child: AppListGroup(
        children: <Widget>[
          for (final BlockedApp app in apps)
            AppListRow(
              leading: AppIconView(package: app.package, label: app.label, size: AppSizes.iconTile),
              title: app.label,
              titleStyle: context.text.bodyLarge,
              trailing: Text(timesLabel(app.count), style: context.textStyles.metricSmall),
              below: UsageBar(
                fraction: maxCount <= 0 ? 0 : app.count / maxCount,
                color: context.colors.danger,
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.period});

  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    return AppSection(
      title: 'Detalhes do período',
      child: AppListGroup(
        children: <Widget>[
          AppListRow(
            leading: const AppIconTile(icon: AppIcons.timeline),
            title: 'Linha do tempo',
            subtitle: 'Apps abertos em ${formatDayLabel(period.to)}, com início, fim e pausas.',
            onTap: () => context.push(ReportsPaths.sessionsOf(period.to)),
          ),
          AppListRow(
            leading: const AppIconTile(icon: AppIcons.list),
            title: 'Eventos do aparelho',
            subtitle: 'Bloqueios, limites, pedidos de tempo, permissões e segurança.',
            onTap: () => context.push(eventsLocation(period.from, period.to)),
          ),
          AppListRow(
            leading: const AppIconTile(icon: AppIcons.web),
            title: 'Histórico de navegação',
            subtitle: 'Páginas abertas no navegador ParentaLynx.',
            onTap: () => context.push(ReportsPaths.browsingIn(period.from, period.to)),
          ),
        ],
      ),
    );
  }
}
