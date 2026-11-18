import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/sizes.dart';

/// Avatar com a inicial do nome (de uma crianca ou de um aparelho).
///
/// Decorativo: o nome aparece em texto ao lado.
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
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tone.background(context), shape: BoxShape.circle),
        child: Text(
          initial,
          textScaler: TextScaler.noScaling,
          style: context.text.titleMedium?.copyWith(
            fontSize: size * 0.42,
            height: 1,
            fontWeight: FontWeight.w800,
            color: tone.foreground(context),
          ),
        ),
      ),
    );
  }
}
