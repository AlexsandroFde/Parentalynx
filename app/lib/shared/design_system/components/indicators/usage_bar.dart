import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../tokens/motion.dart';
import '../../tokens/radius.dart';
import '../../tokens/sizes.dart';

/// Barra fina de uso (por exemplo, minutos de cada app em relacao ao mais usado).
///
/// Decorativa para o leitor de tela: a informacao vem do texto ao lado (o valor em minutos).
class UsageBar extends StatelessWidget {
  const UsageBar({required this.fraction, this.color, this.height = AppSizes.usageBar, super.key});

  /// De 0 a 1.
  final double fraction;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(AppRadius.pill);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(color: context.colors.surfaceMuted),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: fraction.clamp(0.0, 1.0)),
              duration: AppMotion.resolve(context, AppMotion.emphasis),
              curve: AppMotion.emphasized,
              builder: (BuildContext context, double value, Widget? _) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color ?? context.colors.primary,
                      borderRadius: radius,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
