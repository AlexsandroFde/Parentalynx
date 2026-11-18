import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../tokens/colors.dart';

/// Estilo dos graficos, lido do tema atual. Os graficos (fl_chart) usam estas cores e textos
/// em vez de valores proprios, para seguirem a identidade nos temas claro e escuro.
///
/// Regras: grafico so quando a forma dos dados importa (evolucao por dia, distribuicao por
/// hora); um numero sozinho fica melhor em texto. Toda serie tem legenda em texto e o valor
/// exato aparece em uma lista ou no toque, nunca so na cor.
@immutable
class AppChartStyle {
  const AppChartStyle({
    required this.series,
    required this.primary,
    required this.track,
    required this.grid,
    required this.axisLabel,
    required this.valueLabel,
    required this.tooltipBackground,
    required this.tooltipText,
  });

  factory AppChartStyle.of(BuildContext context) {
    final AppColors c = context.colors;
    return AppChartStyle(
      series: c.chart,
      primary: c.primary,
      track: c.surfaceMuted,
      grid: c.hairline,
      axisLabel: context.text.bodySmall!.copyWith(color: c.textSecondary),
      valueLabel: context.textStyles.metricSmall,
      tooltipBackground: c.inverseSurface,
      tooltipText: context.text.bodySmall!.copyWith(color: c.onInverseSurface),
    );
  }

  /// Cores categoricas, na ordem de uso.
  final List<Color> series;

  /// Cor de uma serie unica.
  final Color primary;

  /// Fundo das barras (o "trilho" ate o maximo).
  final Color track;

  /// Linhas de grade.
  final Color grid;
  final TextStyle axisLabel;
  final TextStyle valueLabel;
  final Color tooltipBackground;
  final TextStyle tooltipText;

  Color seriesColor(int index) => series[index % series.length];
}
