import 'package:material_ui/material_ui.dart';

import 'colors.dart';

/// Elevacao e sombras.
///
/// O conteudo fica no plano da pagina e se separa por uma linha fina ([AppColors.hairline]) e
/// pelo contraste entre [AppColors.canvas] e [AppColors.surface], nao por sombras. Sombra so
/// marca o que flutua de verdade sobre a pagina (folhas, menus). No tema escuro a separacao vem
/// da superficie mais clara, entao as sombras sao quase invisiveis.
abstract final class AppElevation {
  /// Conteudo no plano da pagina.
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Elementos levemente acima do conteudo: o seletor de um controle segmentado.
  static List<BoxShadow> raised(AppColors colors) => <BoxShadow>[
    BoxShadow(color: colors.shadow, blurRadius: 2, offset: const Offset(0, 1)),
  ];

  /// Camadas sobre a pagina: folhas, dialogos, menus.
  static List<BoxShadow> overlay(AppColors colors) => <BoxShadow>[
    BoxShadow(color: colors.shadow, blurRadius: 4, offset: const Offset(0, 1)),
    BoxShadow(
      color: colors.shadow.withValues(alpha: colors.shadow.a * 0.8),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
