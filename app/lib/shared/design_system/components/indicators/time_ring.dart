import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../tokens/motion.dart';

/// Anel do tempo de uso, com o valor no centro.
///
/// [progress] vai de 0 a 1 e representa a fracao ja usada. A cor nunca e o unico sinal: quem
/// usa o componente coloca o valor em texto no centro e um [semanticLabel] completo
/// ("1 hora e 20 minutos restantes de 2 horas e 30 minutos").
///
/// O conteudo do centro diminui para caber no anel (o valor nunca quebra em duas linhas); com
/// fonte ampliada, o mesmo valor deve aparecer tambem em texto fora do anel.
class TimeRing extends StatelessWidget {
  const TimeRing({
    required this.progress,
    required this.child,
    this.size = 200,
    this.strokeWidth = 14,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final double progress;
  final Widget child;
  final double size;
  final double strokeWidth;

  /// Cor do arco. Por padrao, a cor primaria.
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color track = context.colors.surfaceMuted;
    final Color arc = color ?? context.colors.primary;
    return Semantics(
      label: semanticLabel,
      container: semanticLabel != null,
      excludeSemantics: semanticLabel != null,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
          duration: AppMotion.resolve(context, AppMotion.emphasis),
          curve: AppMotion.emphasized,
          builder: (BuildContext context, double value, Widget? center) {
            return CustomPaint(
              painter: _RingPainter(
                progress: value,
                strokeWidth: strokeWidth,
                trackColor: track,
                arcColor: arc,
              ),
              child: center,
            );
          },
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(strokeWidth + 10),
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.arcColor,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color arcColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);
    if (progress <= 0) {
      return;
    }
    final Paint arc = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
