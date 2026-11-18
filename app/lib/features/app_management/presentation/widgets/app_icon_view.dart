import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/app_entry.dart';
import '../services/app_icon_images.dart';

/// Icone de um app do aparelho monitorado.
///
/// O icone vem do servidor pelo [AppIconImages] da arvore de widgets. Enquanto carrega, se nao
/// existir ou se falhar, mostra a inicial do app em um quadrado com a cor da marca (sem cores
/// aleatorias: o nome do app ao lado identifica o app). Decorativo para o leitor de tela.
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
    final Widget fallback = _LetterIcon(label: label, size: size);
    final ImageProvider<Object>? image = context.read<AppIconImages>().imageFor(iconPath);
    if (image == null) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: context.shapes.tileRadius,
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
  const _LetterIcon({required this.label, required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
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
          color: Tone.info.background(context),
          borderRadius: context.shapes.tileRadius,
        ),
        // A letra acompanha o tamanho do quadrado, sem depender da escala de fonte.
        child: SizedBox.square(
          dimension: size / 2,
          child: FittedBox(
            child: Text(
              initial,
              textScaler: TextScaler.noScaling,
              style: context.text.titleLarge?.copyWith(
                height: 1,
                fontWeight: FontWeight.w800,
                color: Tone.info.foreground(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
