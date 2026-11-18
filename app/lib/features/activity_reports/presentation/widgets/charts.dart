import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/report_summary.dart';
import 'chart_scale.dart';

// Os graficos usam so as cores e os textos de [AppChartStyle]. Regras do Design System: grafico
// so quando a forma dos dados importa (dia a dia, hora a hora), toda serie tem legenda em texto
// e os valores exatos ficam a um toque ("Ver valores"), nunca so na cor.

/// Escala maxima do texto dentro dos graficos. Os rotulos dos eixos tem lugar fixo; com fonte
/// maior, os mesmos valores aparecem por inteiro na lista de valores.
const double _chartMaxTextScale = 1.3;

/// Arredondamento do topo das barras e das amostras da legenda.
const double _barRadius = AppRadius.xs;
const double _swatchRadius = AppRadius.xs / 2;
const double _swatchSize = AppSizes.iconXs - 2;

/// Espaco entre a parte que conta no limite e a que nao conta, na cor do painel.
const double _stackGap = 2;

/// Folga no topo do grafico de horas para o rotulo do pico caber acima da barra.
const double _peakHeadroom = 1.18;

/// Item de legenda: amostra da cor e o nome da serie.
class ChartLegendItem {
  const ChartLegendItem(this.color, this.label);

  final Color color;
  final String label;
}

/// Legenda dos graficos, em texto.
class ChartLegend extends StatelessWidget {
  const ChartLegend({required this.items, super.key});

  final List<ChartLegendItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (final ChartLegendItem item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: _swatchSize,
                height: _swatchSize,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(_swatchRadius),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: Text(item.label, style: context.text.bodySmall)),
            ],
          ),
      ],
    );
  }
}

/// Secao de grafico: titulo com a conclusao principal, o grafico com legenda e a alternancia
/// para a lista dos valores exatos.
class ChartSection extends StatefulWidget {
  const ChartSection({
    required this.title,
    required this.subtitle,
    required this.semanticSummary,
    required this.chart,
    required this.values,
    this.legend = const <ChartLegendItem>[],
    this.height = 196,
    super.key,
  });

  final String title;

  /// A conclusao principal do grafico em texto ("Mais uso em seg 16/11: 4h").
  final String subtitle;

  /// Resumo lido pelo leitor de tela no lugar do desenho.
  final String semanticSummary;
  final Widget chart;

  /// Os mesmos dados em lista, com os valores exatos.
  final Widget values;
  final List<ChartLegendItem> legend;
  final double height;

  @override
  State<ChartSection> createState() => _ChartSectionState();
}

class _ChartSectionState extends State<ChartSection> {
  bool _values = false;

  @override
  Widget build(BuildContext context) {
    return AppSection(
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: AppIconButton(
        icon: _values ? AppIcons.reports : AppIcons.table,
        tooltip: _values ? 'Ver gráfico' : 'Ver valores',
        onPressed: () => setState(() => _values = !_values),
      ),
      child: StateSwitcher(
        child: _values
            ? KeyedSubtree(key: const ValueKey<String>('valores'), child: widget.values)
            : KeyedSubtree(
                key: const ValueKey<String>('grafico'),
                child: AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (widget.legend.isNotEmpty) ...<Widget>[
                        ChartLegend(items: widget.legend),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      Semantics(
                        container: true,
                        label: widget.semanticSummary,
                        child: ExcludeSemantics(
                          child: MediaQuery.withClampedTextScaling(
                            maxScaleFactor: _chartMaxTextScale,
                            child: SizedBox(height: widget.height, child: widget.chart),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Largura do maior rotulo, no estilo e na escala de texto atuais.
double _widestLabel(BuildContext context, TextStyle style, Iterable<String> labels) {
  final TextScaler scaler = MediaQuery.textScalerOf(context);
  double widest = 0;
  for (final String label in labels) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  return widest;
}

/// Eixo vertical de duracoes e eixo horizontal com os rotulos de [bottomLabel].
FlTitlesData _titles({
  required BuildContext context,
  required AppChartStyle style,
  required ({double interval, double max}) axis,
  required String? Function(int index) bottomLabel,
}) {
  final List<String> ticks = <String>[
    for (double value = 0; value <= axis.max; value += axis.interval) durationTick(value),
  ];
  final double reserved = _widestLabel(context, style.axisLabel, ticks) + AppSpacing.sm;
  final double bottomReserved =
      MediaQuery.textScalerOf(context).scale(style.axisLabel.fontSize ?? AppSpacing.md) +
      AppSpacing.md;
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: reserved,
        interval: axis.interval,
        getTitlesWidget: (double value, TitleMeta meta) {
          return SideTitleWidget(
            meta: meta,
            space: AppSpacing.xs,
            child: Text(durationTick(value), style: style.axisLabel),
          );
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: bottomReserved,
        interval: 1,
        getTitlesWidget: (double value, TitleMeta meta) {
          final String? label = value == value.roundToDouble() ? bottomLabel(value.round()) : null;
          return SideTitleWidget(
            meta: meta,
            space: AppSpacing.xs,
            child: label == null ? const SizedBox.shrink() : Text(label, style: style.axisLabel),
          );
        },
      ),
    ),
  );
}

FlGridData _grid(AppChartStyle style, double interval) {
  return FlGridData(
    drawVerticalLine: false,
    horizontalInterval: interval,
    getDrawingHorizontalLine: (double value) {
      return FlLine(color: style.grid, strokeWidth: AppSizes.hairline);
    },
  );
}

FlBorderData _baseline(AppChartStyle style) {
  return FlBorderData(
    border: Border(bottom: BorderSide(color: style.grid)),
  );
}

BarTouchData _touch(
  AppChartStyle style,
  ({String value, String detail}) Function(int index) describe,
) {
  return BarTouchData(
    touchTooltipData: BarTouchTooltipData(
      getTooltipColor: (BarChartGroupData group) => style.tooltipBackground,
      tooltipBorderRadius: BorderRadius.circular(AppRadius.xs),
      fitInsideHorizontally: true,
      fitInsideVertically: true,
      maxContentWidth: AppSpacing.maxFormWidth / 3,
      getTooltipItem: (BarChartGroupData group, int index, BarChartRodData rod, int rodIndex) {
        final ({String value, String detail}) text = describe(index);
        return BarTooltipItem(
          '${text.value}\n',
          style.tooltipText.copyWith(fontWeight: FontWeight.w800),
          children: <TextSpan>[TextSpan(text: text.detail, style: style.tooltipText)],
        );
      },
    ),
  );
}

/// Passo entre rotulos do eixo horizontal para caberem cerca de seis rotulos.
int _labelStep(int count) => math.max(1, (count / 6).ceil());

double _barWidth(double plotWidth, int count, {double max = 24}) {
  if (count <= 0) {
    return max;
  }
  return (plotWidth / count * 0.62).clamp(2.0, max);
}

const BorderRadius _barTop = BorderRadius.vertical(top: Radius.circular(_barRadius));

/// Uso por dia: a parte que contou no limite, a que nao contou (excecoes ou regras suspensas)
/// e, ao fundo, o trilho ate o limite do dia. A linha tracejada marca a media do periodo.
class DailyUsageChart extends StatelessWidget {
  const DailyUsageChart({
    required this.daily,
    required this.today,
    required this.averageMs,
    super.key,
  });

  final List<DailyUsage> daily;

  /// Dia da cota corrente do aparelho, para o rotulo "hoje".
  final String today;

  /// Media por dia informada pelo servidor (a mesma do resumo).
  final int averageMs;

  @override
  Widget build(BuildContext context) {
    final AppChartStyle style = AppChartStyle.of(context);
    final Color counted = style.seriesColor(0);
    final Color notCounted = style.seriesColor(1);
    final Color surface = context.colors.surface;
    double maxMinutes = 0;
    for (final DailyUsage day in daily) {
      maxMinutes = math.max(maxMinutes, math.max(day.totalMs, day.limitMs ?? 0) / 60000);
    }
    final ({double interval, double max}) axis = durationAxis(maxMinutes);
    final int step = _labelStep(daily.length);
    final bool week = daily.length <= 7;
    final double average = averageMs / 60000;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final FlTitlesData titles = _titles(
          context: context,
          style: style,
          axis: axis,
          bottomLabel: (int index) {
            if (index < 0 || index >= daily.length || index % step != 0) {
              return null;
            }
            final String day = daily[index].day;
            if (day == today) {
              return 'hoje';
            }
            final DateTime date = parseDay(day);
            return week ? weekdayShort(date.weekday) : formatShortDate(date);
          },
        );
        final double plotWidth = constraints.maxWidth - titles.leftTitles.sideTitles.reservedSize;
        final double width = _barWidth(plotWidth, daily.length);
        final double plotHeight =
            constraints.maxHeight - titles.bottomTitles.sideTitles.reservedSize;
        // O espaco entre os trechos da barra, convertido de pontos para minutos.
        final double gap = axis.max * _stackGap / math.max(1, plotHeight);
        return BarChart(
          duration: AppMotion.resolve(context, AppMotion.slow),
          BarChartData(
            maxY: axis.max,
            alignment: BarChartAlignment.spaceAround,
            gridData: _grid(style, axis.interval),
            borderData: _baseline(style),
            titlesData: titles,
            barTouchData: _touch(style, (int index) {
              final DailyUsage day = daily[index];
              final int? limit = day.limitMs;
              return (
                value: formatDurationMs(day.totalMs),
                detail:
                    '${formatDayLabel(day.day)}\n'
                    'no limite ${formatDurationMs(day.quotaMs)}'
                    '${limit == null ? '' : '\nlimite ${formatDurationMs(limit)}'}',
              );
            }),
            extraLinesData: ExtraLinesData(
              horizontalLines: <HorizontalLine>[
                if (average > 0)
                  HorizontalLine(
                    y: average,
                    color: context.colors.textSecondary,
                    strokeWidth: AppSizes.hairline,
                    dashArray: <int>[4, 4],
                  ),
              ],
            ),
            barGroups: <BarChartGroupData>[
              for (int i = 0; i < daily.length; i++)
                _group(i, daily[i], width, gap, counted, notCounted, surface, style.track),
            ],
          ),
        );
      },
    );
  }

  BarChartGroupData _group(
    int index,
    DailyUsage day,
    double width,
    double gap,
    Color counted,
    Color notCounted,
    Color surface,
    Color track,
  ) {
    final double quota = day.quotaMs / 60000;
    final double total = day.totalMs / 60000;
    final int? limit = day.limitMs;
    final bool split = quota > 0 && total - quota > gap * 2;
    return BarChartGroupData(
      x: index,
      barRods: <BarChartRodData>[
        BarChartRodData(
          toY: total,
          width: width,
          color: Colors.transparent,
          borderRadius: _barTop,
          rodStackItems: <BarChartRodStackItem>[
            BarChartRodStackItem(0, split ? quota : math.min(quota, total), counted),
            if (split) BarChartRodStackItem(quota, quota + gap, surface),
            if (total > quota) BarChartRodStackItem(split ? quota + gap : quota, total, notCounted),
          ],
          backDrawRodData: BackgroundBarChartRodData(
            show: limit != null,
            toY: (limit ?? 0) / 60000,
            color: track,
          ),
        ),
      ],
    );
  }
}

/// Tempo de uso por hora do dia, somado no periodo (24 colunas), com o valor do pico.
class HourlyChart extends StatelessWidget {
  const HourlyChart({required this.hourly, super.key});

  /// Milissegundos por hora local, 24 posicoes.
  final List<int> hourly;

  @override
  Widget build(BuildContext context) {
    final AppChartStyle style = AppChartStyle.of(context);
    int peak = -1;
    int peakMs = 0;
    for (int hour = 0; hour < hourly.length; hour++) {
      if (hourly[hour] > peakMs) {
        peakMs = hourly[hour];
        peak = hour;
      }
    }
    final ({double interval, double max}) axis = durationAxis(peakMs / 60000 * _peakHeadroom);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final FlTitlesData titles = _titles(
          context: context,
          style: style,
          axis: axis,
          bottomLabel: (int hour) => hour % 6 == 0 ? '${hour}h' : null,
        );
        final double width = _barWidth(
          constraints.maxWidth - titles.leftTitles.sideTitles.reservedSize,
          hourly.length,
          max: AppSpacing.md,
        );
        return BarChart(
          duration: AppMotion.resolve(context, AppMotion.slow),
          BarChartData(
            maxY: axis.max,
            alignment: BarChartAlignment.spaceAround,
            gridData: _grid(style, axis.interval),
            borderData: _baseline(style),
            titlesData: titles,
            barTouchData: _touch(style, (int hour) {
              return (
                value: formatDurationMs(hourly[hour]),
                detail: 'das ${hour}h às ${hour + 1}h',
              );
            }),
            barGroups: <BarChartGroupData>[
              for (int hour = 0; hour < hourly.length; hour++)
                BarChartGroupData(
                  x: hour,
                  barRods: <BarChartRodData>[
                    BarChartRodData(
                      toY: hourly[hour] / 60000,
                      width: width,
                      color: style.primary,
                      borderRadius: _barTop,
                      label: BarChartRodLabel(
                        show: hour == peak,
                        text: formatDurationMs(hourly[hour]),
                        style: style.valueLabel,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
