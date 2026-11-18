import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/entities/app_entry.dart';
import '../services/app_icon_images.dart';

/// Icone de um app do aparelho monitorado.
///
/// O icone vem do servidor pelo [AppIconImages] da arvore de widgets. Enquanto carrega, se nao
/// existir ou se falhar, mostra a inicial do app sobre uma cor derivada do nome do pacote.
class AppIconView extends StatelessWidget {
  const AppIconView({
    required this.package,
    required this.label,
    this.iconPath,
    this.size = 40,
    super.key,
  });

  factory AppIconView.forApp(AppEntry app, {double size = 40, Key? key}) {
    return AppIconView(
      package: app.package,
      label: app.label,
      iconPath: app.iconPath,
      size: size,
      key: key,
    );
  }

  final String package;
  final String label;
  final String? iconPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = _LetterIcon(package: package, label: label, size: size);
    final ImageProvider<Object>? image = context.read<AppIconImages>().imageFor(iconPath);
    if (image == null) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image(
        image: image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        frameBuilder: (BuildContext context, Widget child, int? frame, bool sync) {
          return frame == null && !sync ? fallback : child;
        },
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) => fallback,
      ),
    );
  }
}

class _LetterIcon extends StatelessWidget {
  const _LetterIcon({required this.package, required this.label, required this.size});

  final String package;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    // Matiz estavel por pacote: o mesmo app tem sempre a mesma cor.
    final double hue = (package.hashCode & 0x7fffffff) % 360.0;
    final Color background = HSLColor.fromAHSL(1, hue, 0.45, dark ? 0.36 : 0.46).toColor();
    final String trimmed = label.trim();
    final String initial = trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.24),
        ),
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.46,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
