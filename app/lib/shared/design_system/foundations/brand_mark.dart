import 'package:material_ui/material_ui.dart';

import '../foundations/ds_context.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Simbolo da marca: a cabeca de um lince (orelhas com tufos, colar de pelos nas bochechas e
/// olhos ambar) sobre um quadrado arredondado de petroleo.
///
/// Usa as cores fixas da marca, iguais nos temas claro e escuro, para ser sempre reconhecida.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 56, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'ParentaLynx',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _LynxPainter()),
      ),
    );
  }
}

/// Simbolo seguido do nome do app.
class BrandLockup extends StatelessWidget {
  const BrandLockup({this.markSize = 40, super.key});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = context.text.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
    );
    return Semantics(
      label: 'ParentaLynx',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            BrandMark(size: markSize),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: <TextSpan>[
                    const TextSpan(text: 'Parenta'),
                    TextSpan(
                      text: 'Lynx',
                      style: TextStyle(color: context.colors.primary),
                    ),
                  ],
                ),
                style: style,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LynxPainter extends CustomPainter {
  const _LynxPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 100;
    Offset p(double x, double y) => Offset(x * s, y * s);

    // Fundo.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(28 * s)),
      Paint()..color = AppPalette.petrol600,
    );

    // Cabeca: rosto, orelhas e colar de pelos unidos em uma silhueta so.
    final Path face = Path()..addOval(Rect.fromCircle(center: p(50, 60), radius: 24 * s));
    final Path leftEar = Path()
      ..moveTo(p(28, 50).dx, p(28, 50).dy)
      ..lineTo(p(31, 16).dx, p(31, 16).dy)
      ..lineTo(p(47, 38).dx, p(47, 38).dy)
      ..close();
    final Path rightEar = Path()
      ..moveTo(p(72, 50).dx, p(72, 50).dy)
      ..lineTo(p(69, 16).dx, p(69, 16).dy)
      ..lineTo(p(53, 38).dx, p(53, 38).dy)
      ..close();
    final Path leftRuff = Path()
      ..moveTo(p(29, 62).dx, p(29, 62).dy)
      ..lineTo(p(15, 77).dx, p(15, 77).dy)
      ..lineTo(p(37, 80).dx, p(37, 80).dy)
      ..close();
    final Path rightRuff = Path()
      ..moveTo(p(71, 62).dx, p(71, 62).dy)
      ..lineTo(p(85, 77).dx, p(85, 77).dy)
      ..lineTo(p(63, 80).dx, p(63, 80).dy)
      ..close();
    Path head = face;
    for (final Path part in <Path>[leftEar, rightEar, leftRuff, rightRuff]) {
      head = Path.combine(PathOperation.union, head, part);
    }
    final Paint white = Paint()
      ..color = AppPalette.sand0
      ..isAntiAlias = true;
    canvas.drawPath(head, white);

    // Tufos das orelhas.
    final Paint tuft = Paint()
      ..color = AppPalette.sand0
      ..strokeWidth = 3.6 * s
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(p(31, 17), p(28.5, 8), tuft)
      ..drawLine(p(69, 17), p(71.5, 8), tuft);

    // Interior das orelhas.
    final Paint innerEar = Paint()..color = AppPalette.petrol100;
    canvas
      ..drawPath(
        Path()
          ..moveTo(p(32, 44).dx, p(32, 44).dy)
          ..lineTo(p(33, 25).dx, p(33, 25).dy)
          ..lineTo(p(42, 38).dx, p(42, 38).dy)
          ..close(),
        innerEar,
      )
      ..drawPath(
        Path()
          ..moveTo(p(68, 44).dx, p(68, 44).dy)
          ..lineTo(p(67, 25).dx, p(67, 25).dy)
          ..lineTo(p(58, 38).dx, p(58, 38).dy)
          ..close(),
        innerEar,
      );

    // Olhos ambar com pupilas em fenda.
    final Paint eye = Paint()..color = AppPalette.amber500;
    final Paint pupil = Paint()..color = AppPalette.petrol900;
    for (final double x in <double>[40.5, 59.5]) {
      canvas
        ..drawOval(Rect.fromCenter(center: p(x, 58), width: 11 * s, height: 7.5 * s), eye)
        ..drawOval(Rect.fromCenter(center: p(x, 58), width: 2.6 * s, height: 6.4 * s), pupil);
    }

    // Focinho.
    final Paint nose = Paint()
      ..color = AppPalette.petrol700
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.6 * s
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(p(46, 67).dx, p(46, 67).dy)
        ..lineTo(p(54, 67).dx, p(54, 67).dy)
        ..lineTo(p(50, 72).dx, p(50, 72).dy)
        ..close(),
      nose,
    );
  }

  @override
  bool shouldRepaint(covariant _LynxPainter oldDelegate) => false;
}
