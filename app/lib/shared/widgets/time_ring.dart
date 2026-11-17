import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Anel de progresso do tempo de uso, com conteudo no centro.
///
/// [progress] vai de 0 a 1 e representa a fracao ja usada. O anel muda de cor conforme se
/// aproxima do limite, e nunca depende so da cor: quem usa o componente coloca o valor em
/// texto no centro.
class TimeRing extends StatelessWidget {
  const TimeRing({
    required this.progress,
    required this.child,
    this.size = 200,
    this.strokeWidth = 16,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final double progress;
  final Widget child;
  final double size;
  final double strokeWidth;

  /// Cor do arco. Por padrao usa a cor primaria do tema.
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      container: semanticLabel != null,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double value, Widget? center) {
            return CustomPaint(
              painter: _RingPainter(
                progress: value,
                strokeWidth: strokeWidth,
                trackColor: scheme.surfaceContainerHighest,
                arcColor: color ?? scheme.primary,
              ),
              child: center,
            );
          },
          child: Center(
            child: Padding(padding: EdgeInsets.all(strokeWidth + 8), child: child),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
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
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);
    if (progress <= 0) {
      return;
    }
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = arcColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.arcColor != arcColor;
  }
}
