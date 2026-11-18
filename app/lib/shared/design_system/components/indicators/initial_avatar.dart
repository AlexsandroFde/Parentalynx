import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/sizes.dart';

/// Avatar com a inicial do nome (de uma crianca ou de um aparelho), em um circulo neutro.
///
/// Decorativo: o nome aparece em texto ao lado. [tone] colore so a letra, e so quando o tom
/// carrega um estado (atencao, erro); por padrao a letra usa a cor do texto.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    required this.name,
    this.size = AppSizes.avatarMd,
    this.tone = Tone.info,
    super.key,
  });

  final String name;
  final double size;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final String trimmed = name.trim();
    final String initial = trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
    final Color letter = switch (tone) {
      Tone.warning || Tone.danger => tone.foreground(context),
      _ => context.colors.textSecondary,
    };
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: context.colors.surfaceMuted, shape: BoxShape.circle),
        child: Text(
          initial,
          textScaler: TextScaler.noScaling,
          style: context.text.titleMedium?.copyWith(
            fontSize: size * 0.4,
            height: 1,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: letter,
          ),
        ),
      ),
    );
  }
}
