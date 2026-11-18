import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../domain/entities/report_summary.dart';
import 'chart_scale.dart';

/// Cores dos graficos nos dois temas.
///
/// As cores de serie foram conferidas com o validador de paletas (faixa de luminosidade,
/// croma, separacao para daltonismo e contraste) contra a superficie dos cartoes: branco no
/// tema claro e `#1a1b23` no escuro. O verde-agua fica abaixo de 3:1 no tema claro, por isso
/// todo grafico que o usa tem legenda com rotulo e a visao em tabela.
class ChartPalette {
  const ChartPalette({
    required this.usage,
    required this.outsideQuota,
    required this.blocked,
    required this.limitTrack,
    required this.grid,
    required this.axis,
    required this.ink,
    required this.muted,
    required this.surface,
    required this.tooltip,
    required this.tooltipInk,
  });

  factory ChartPalette.of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool dark = theme.brightness == Brightness.dark;
    return ChartPalette(
      usage: dark ? const Color(0xFF7387FF) : const Color(0xFF3046C5),
      outsideQuota: dark ? const Color(0xFF199E70) : const Color(0xFF1BAF7A),
      blocked: dark ? const Color(0xFFD95926) : const Color(0xFFEB6834),
      limitTrack: dark ? const Color(0xFF2A2F55) : const Color(0xFFDEE0FF),
      grid: scheme.outlineVariant.withValues(alpha: 0.5),
      axis: scheme.outlineVariant,
      ink: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      surface: theme.cardTheme.color ?? scheme.surface,
      tooltip: scheme.inverseSurface,
      tooltipInk: scheme.onInverseSurface,
    );
  }

  /// Tempo de uso (serie principal).
  final Color usage;

  /// Tempo que nao consumiu a cota.
  final Color outsideQuota;

  /// Tentativas bloqueadas.
  final Color blocked;

  /// Trilha clara, do mesmo tom da serie principal, ate o limite do dia.
  final Color limitTrack;
  final Color grid;
  final Color axis;
  final Color ink;
  final Color muted;
  final Color surface;
  final Color tooltip;
  final Color tooltipInk;

  TextStyle get tickStyle => TextStyle(color: muted, fontSize: 11, height: 1.1);

  TextStyle get tooltipValue {
    return TextStyle(color: tooltipInk, fontSize: 14, fontWeight: FontWeight.w700);
  }

  TextStyle get tooltipLabel {
    return TextStyle(color: tooltipInk, fontSize: 12, fontWeight: FontWeight.w400);
  }
}

/// Item de legenda: amostra da cor e o nome da serie.
class LegendItem {
  const LegendItem(this.color, this.label);

  final Color color;
  final String label;
}

/// Cartao de grafico com titulo, legenda e alternancia para a visao em tabela, que deixa
/// todos os valores acessiveis sem depender do toque no grafico.
class ChartCard extends StatefulWidget {
  const ChartCard({
    required this.title,
    required this.chart,
    required this.tableHeader,
    required this.tableRows,
    required this.semanticSummary,
    this.subtitle,
    this.legend = const <LegendItem>[],
    this.height = 200,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget chart;
  final List<String> tableHeader;
  final List<List<String>> tableRows;

  /// Resumo do grafico para leitores de tela.
  final String semanticSummary;
  final List<LegendItem> legend;
  final double height;

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: IconButton(
        tooltip: _table ? 'Ver gráfico' : 'Ver em tabela',
        icon: Icon(_table ? Icons.bar_chart : Icons.table_rows_outlined),
        onPressed: () => setState(() => _table = !_table),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.legend.length > 1 && !_table) ...<Widget>[
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final LegendItem item in widget.legend)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(item.label, style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_table)
            _ValuesTable(header: widget.tableHeader, rows: widget.tableRows)
          else
            Semantics(
              label: widget.semanticSummary,
              container: true,
              child: ExcludeSemantics(
                // Folga para rotulos acima das barras e para o marcador do fim da linha.
                child: Padding(
                  padding: const EdgeInsets.only(top: 14, right: 10),
                  child: SizedBox(height: widget.height, child: widget.chart),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ValuesTable extends StatelessWidget {
  const _ValuesTable({required this.header, required this.rows});

  final List<String> header;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    TableRow row(List<String> cells, {required bool head}) {
      return TableRow(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerTheme.color ?? theme.dividerColor)),
        ),
        children: <Widget>[
          for (int i = 0; i < cells.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                cells[i],
                textAlign: i == 0 ? TextAlign.start : TextAlign.end,
                style: (head ? theme.textTheme.labelMedium : theme.textTheme.bodyMedium)?.copyWith(
                  color: head ? theme.colorScheme.onSurfaceVariant : null,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      );
    }

    return Table(
      columnWidths: const <int, TableColumnWidth>{0: FlexColumnWidth(1.4)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: <TableRow>[
        row(header, head: true),
        for (final List<String> cells in rows) row(cells, head: false),
      ],
    );
  }
}

FlTitlesData _titles({
  required ChartPalette palette,
  required double leftInterval,
  required String Function(double value) leftLabel,
  required Widget? Function(int index) bottomLabel,
}) {
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 46,
        interval: leftInterval,
        getTitlesWidget: (double value, TitleMeta meta) {
          return SideTitleWidget(
            meta: meta,
            space: 6,
            child: Text(leftLabel(value), style: palette.tickStyle),
          );
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 26,
        interval: 1,
        getTitlesWidget: (double value, TitleMeta meta) {
          final Widget? label = value == value.roundToDouble() ? bottomLabel(value.round()) : null;
          return SideTitleWidget(meta: meta, space: 6, child: label ?? const SizedBox.shrink());
        },
      ),
    ),
  );
}

FlGridData _grid(ChartPalette palette, double interval) {
  return FlGridData(
    drawVerticalLine: false,
    horizontalInterval: interval,
    getDrawingHorizontalLine: (double value) => FlLine(color: palette.grid, strokeWidth: 1),
  );
}

FlBorderData _baseline(ChartPalette palette) {
  return FlBorderData(
    border: Border(bottom: BorderSide(color: palette.axis)),
  );
}

/// Passo entre rotulos do eixo horizontal para caberem cerca de seis rotulos.
int _labelStep(int count) => math.max(1, (count / 6).ceil());

double _barWidth(double plotWidth, int count) {
  if (count <= 0) {
    return 8;
  }
  return (plotWidth / count - 2).clamp(2.0, 24.0);
}

const BorderRadius _barTop = BorderRadius.vertical(top: Radius.circular(4));

/// Uso por dia: a parte que consumiu a cota, a parte fora da cota e a trilha do limite.
class DailyUsageChart extends StatelessWidget {
  const DailyUsageChart({required this.daily, super.key});

  final List<DailyUsage> daily;

  @override
  Widget build(BuildContext context) {
    final ChartPalette palette = ChartPalette.of(context);
    double maxMinutes = 0;
    for (int i = 0; i < daily.length; i++) {
      final double total = daily[i].totalMs / 60000;
      maxMinutes = math.max(maxMinutes, math.max(total, (daily[i].limitMs ?? 0) / 60000));
    }
    final ({double interval, double max}) axis = durationAxis(maxMinutes);
    final int step = _labelStep(daily.length);
    final bool week = daily.length <= 7;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = _barWidth(constraints.maxWidth - 46, daily.length);
        // Espaco de 2 px na cor da superficie entre os dois trechos da barra.
        final double gap = axis.max * 2 / math.max(1, constraints.maxHeight - 26);
        return BarChart(
          BarChartData(
            maxY: axis.max,
            alignment: BarChartAlignment.spaceAround,
            gridData: _grid(palette, axis.interval),
            borderData: _baseline(palette),
            titlesData: _titles(
              palette: palette,
              leftInterval: axis.interval,
              leftLabel: durationTick,
              bottomLabel: (int index) {
                if (index < 0 || index >= daily.length || index % step != 0) {
                  return null;
                }
                final DateTime date = parseDay(daily[index].day);
                return Text(
                  week ? weekdayShort(date.weekday) : formatShortDate(date),
                  style: palette.tickStyle,
                );
              },
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (BarChartGroupData group) => palette.tooltip,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem:
                    (BarChartGroupData group, int groupIndex, BarChartRodData rod, int rodIndex) {
                      final DailyUsage day = daily[groupIndex];
                      final int? limit = day.limitMs;
                      return BarTooltipItem(
                        '${formatDurationMs(day.totalMs)}\n',
                        palette.tooltipValue,
                        children: <TextSpan>[
                          TextSpan(text: formatDayLabel(day.day), style: palette.tooltipLabel),
                          if (limit != null)
                            TextSpan(
                              text: '\nlimite ${formatDurationMs(limit)}',
                              style: palette.tooltipLabel,
                            ),
                        ],
                      );
                    },
              ),
            ),
            barGroups: <BarChartGroupData>[
              for (int i = 0; i < daily.length; i++) _dailyGroup(i, daily[i], palette, width, gap),
            ],
          ),
        );
      },
    );
  }

  BarChartGroupData _dailyGroup(
    int index,
    DailyUsage day,
    ChartPalette palette,
    double width,
    double gap,
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
            BarChartRodStackItem(0, split ? quota : math.min(quota, total), palette.usage),
            if (split) BarChartRodStackItem(quota, quota + gap, palette.surface),
            if (total > quota)
              BarChartRodStackItem(split ? quota + gap : quota, total, palette.outsideQuota),
          ],
          backDrawRodData: BackgroundBarChartRodData(
            show: limit != null,
            toY: (limit ?? 0) / 60000,
            color: palette.limitTrack,
          ),
        ),
      ],
    );
  }
}

/// Tempo de uso por hora do dia (24 colunas).
class HourlyChart extends StatelessWidget {
  const HourlyChart({required this.hourly, super.key});

  /// Milissegundos por hora local, 24 posicoes.
  final List<int> hourly;

  @override
  Widget build(BuildContext context) {
    final ChartPalette palette = ChartPalette.of(context);
    int peak = -1;
    int peakMs = 0;
    for (int hour = 0; hour < hourly.length; hour++) {
      if (hourly[hour] > peakMs) {
        peakMs = hourly[hour];
        peak = hour;
      }
    }
    // Folga de 15% no topo para o rotulo do pico caber acima da barra.
    final ({double interval, double max}) axis = durationAxis(peakMs / 60000 * 1.15);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = _barWidth(constraints.maxWidth - 46, hourly.length);
        return BarChart(
          BarChartData(
            maxY: axis.max,
            alignment: BarChartAlignment.spaceAround,
            gridData: _grid(palette, axis.interval),
            borderData: _baseline(palette),
            titlesData: _titles(
              palette: palette,
              leftInterval: axis.interval,
              leftLabel: durationTick,
              bottomLabel: (int hour) {
                return hour % 6 == 0 ? Text('${hour}h', style: palette.tickStyle) : null;
              },
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (BarChartGroupData group) => palette.tooltip,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem:
                    (BarChartGroupData group, int groupIndex, BarChartRodData rod, int rodIndex) {
                      return BarTooltipItem(
                        '${formatDurationMs(hourly[groupIndex])}\n',
                        palette.tooltipValue,
                        children: <TextSpan>[
                          TextSpan(
                            text: 'das ${groupIndex}h às ${groupIndex + 1}h',
                            style: palette.tooltipLabel,
                          ),
                        ],
                      );
                    },
              ),
            ),
            barGroups: <BarChartGroupData>[
              for (int hour = 0; hour < hourly.length; hour++)
                BarChartGroupData(
                  x: hour,
                  barRods: <BarChartRodData>[
                    BarChartRodData(
                      toY: hourly[hour] / 60000,
                      width: width,
                      color: palette.usage,
                      borderRadius: _barTop,
                      label: BarChartRodLabel(
                        show: hour == peak,
                        text: formatMinutes((hourly[hour] / 60000).round()),
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
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

/// Evolucao do uso total por dia, com a media do periodo como referencia.
class EvolutionChart extends StatelessWidget {
  const EvolutionChart({required this.daily, super.key});

  final List<DailyUsage> daily;

  @override
  Widget build(BuildContext context) {
    final ChartPalette palette = ChartPalette.of(context);
    final List<double> minutes = daily.map((DailyUsage day) => day.totalMs / 60000).toList();
    final double maxMinutes = minutes.fold<double>(0, math.max);
    final double average = minutes.isEmpty
        ? 0
        : minutes.reduce((double a, double b) => a + b) / minutes.length;
    final ({double interval, double max}) axis = durationAxis(maxMinutes);
    final int step = _labelStep(daily.length);
    final bool week = daily.length <= 7;
    final int last = daily.length - 1;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: axis.max,
        minX: 0,
        maxX: math.max(1, last).toDouble(),
        gridData: _grid(palette, axis.interval),
        borderData: _baseline(palette),
        titlesData: _titles(
          palette: palette,
          leftInterval: axis.interval,
          leftLabel: durationTick,
          bottomLabel: (int index) {
            if (index < 0 || index > last || index % step != 0) {
              return null;
            }
            final DateTime date = parseDay(daily[index].day);
            return Text(
              week ? weekdayShort(date.weekday) : formatShortDate(date),
              style: palette.tickStyle,
            );
          },
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: <HorizontalLine>[
            if (average > 0)
              HorizontalLine(
                y: average,
                color: palette.muted,
                strokeWidth: 1,
                dashArray: <int>[4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 4, bottom: 2),
                  style: TextStyle(color: palette.muted, fontSize: 11),
                  labelResolver: (HorizontalLine line) {
                    return 'média ${formatMinutes(average.round())}';
                  },
                ),
              ),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (LineBarSpot spot) => palette.tooltip,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (List<LineBarSpot> spots) {
              return <LineTooltipItem>[
                for (final LineBarSpot spot in spots)
                  LineTooltipItem(
                    '${formatMinutes(spot.y.round())}\n',
                    palette.tooltipValue,
                    children: <TextSpan>[
                      TextSpan(
                        text: formatDayLabel(daily[spot.x.round().clamp(0, last)].day),
                        style: palette.tooltipLabel,
                      ),
                    ],
                  ),
              ];
            },
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: <FlSpot>[
              for (int i = 0; i < minutes.length; i++) FlSpot(i.toDouble(), minutes[i]),
            ],
            color: palette.usage,
            barWidth: 2,
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            belowBarData: BarAreaData(show: true, color: palette.usage.withValues(alpha: 0.10)),
            dotData: FlDotData(
              checkToShowDot: (FlSpot spot, LineChartBarData bar) => spot.x.round() == last,
              getDotPainter: (FlSpot spot, double percent, LineChartBarData bar, int index) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: palette.usage,
                  strokeWidth: 2,
                  strokeColor: palette.surface,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Tentativas de abrir apps bloqueados por dia.
class BlockedAttemptsChart extends StatelessWidget {
  const BlockedAttemptsChart({required this.daily, super.key});

  final List<DailyUsage> daily;

  @override
  Widget build(BuildContext context) {
    final ChartPalette palette = ChartPalette.of(context);
    final int maxCount = daily.fold<int>(
      0,
      (int best, DailyUsage day) => math.max(best, day.blockedAttempts),
    );
    final double interval = math.max(1, (maxCount / 4).ceil()).toDouble();
    final double top = math.max(interval, (maxCount / interval).ceil() * interval);
    final int step = _labelStep(daily.length);
    final bool week = daily.length <= 7;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = _barWidth(constraints.maxWidth - 46, daily.length);
        return BarChart(
          BarChartData(
            maxY: top,
            alignment: BarChartAlignment.spaceAround,
            gridData: _grid(palette, interval),
            borderData: _baseline(palette),
            titlesData: _titles(
              palette: palette,
              leftInterval: interval,
              leftLabel: (double value) => value.round().toString(),
              bottomLabel: (int index) {
                if (index < 0 || index >= daily.length || index % step != 0) {
                  return null;
                }
                final DateTime date = parseDay(daily[index].day);
                return Text(
                  week ? weekdayShort(date.weekday) : formatShortDate(date),
                  style: palette.tickStyle,
                );
              },
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (BarChartGroupData group) => palette.tooltip,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem:
                    (BarChartGroupData group, int groupIndex, BarChartRodData rod, int rodIndex) {
                      final DailyUsage day = daily[groupIndex];
                      return BarTooltipItem(
                        '${day.blockedAttempts}\n',
                        palette.tooltipValue,
                        children: <TextSpan>[
                          TextSpan(text: formatDayLabel(day.day), style: palette.tooltipLabel),
                        ],
                      );
                    },
              ),
            ),
            barGroups: <BarChartGroupData>[
              for (int i = 0; i < daily.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: <BarChartRodData>[
                    BarChartRodData(
                      toY: daily[i].blockedAttempts.toDouble(),
                      width: width,
                      color: palette.blocked,
                      borderRadius: _barTop,
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

/// Linha de uma lista de barras ordenadas.
class RankedItem {
  const RankedItem({
    required this.leading,
    required this.label,
    required this.value,
    required this.fraction,
    this.note,
  });

  final Widget leading;
  final String label;

  /// Valor em texto, mostrado ao lado do nome.
  final String value;

  /// Comprimento da barra em relacao ao maior item, de 0 a 1.
  final double fraction;
  final String? note;
}

/// Barras horizontais ordenadas, uma cor so: nome, valor e a barra abaixo do nome. E a forma
/// indicada para comparar itens com rotulos longos (apps e categorias).
class RankedBars extends StatelessWidget {
  const RankedBars({required this.items, required this.color, super.key});

  final List<RankedItem> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        for (final RankedItem item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                item.leading,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              item.label,
                              style: theme.textTheme.bodyLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(item.value, style: theme.textTheme.labelLarge),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints constraints) {
                          final double width = math.max(
                            4,
                            constraints.maxWidth * item.fraction.clamp(0.0, 1.0),
                          );
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: width,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(4),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (item.note != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item.note!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
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
}
