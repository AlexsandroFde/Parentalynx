import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/spacing.dart';

/// Valor numerico com rotulo ("1h 10min" / "Usado hoje"). Algarismos de largura fixa, para o
/// valor nao "pular" quando muda. O valor fica sempre em uma linha (diminui se nao couber); o
/// rotulo quebra linha normalmente.
class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.value,
    required this.label,
    this.emphasis = false,
    this.tone,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    super.key,
  });

  final String value;
  final String label;

  /// Valor principal da tela, em tamanho grande.
  final bool emphasis;

  /// Cor do valor quando ele carrega um significado (por exemplo, pouco tempo restante).
  final Tone? tone;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = emphasis
        ? context.textStyles.metricLarge
        : context.textStyles.metricMedium;
    final TextAlign align = switch (crossAxisAlignment) {
      CrossAxisAlignment.center => TextAlign.center,
      CrossAxisAlignment.end => TextAlign.end,
      _ => TextAlign.start,
    };
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: switch (crossAxisAlignment) {
              CrossAxisAlignment.center => Alignment.center,
              CrossAxisAlignment.end => AlignmentDirectional.centerEnd,
              _ => AlignmentDirectional.centerStart,
            },
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              textAlign: align,
              style: tone == null ? base : base.copyWith(color: tone!.foreground(context)),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, textAlign: align, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

/// Linha de metricas lado a lado, separadas por espaco.
class MetricRow extends StatelessWidget {
  const MetricRow({required this.metrics, super.key});

  final List<MetricTile> metrics;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < metrics.length; i++) {
      if (i > 0) {
        children.add(const SizedBox(width: AppSpacing.lg));
      }
      children.add(Expanded(child: metrics[i]));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
