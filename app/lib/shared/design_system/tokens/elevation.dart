import 'package:material_ui/material_ui.dart';

import 'colors.dart';

/// Elevacao e sombras.
///
/// O conteudo fica no plano da pagina e se separa pelo contraste entre [AppColors.canvas] e
/// [AppColors.surface], nao por sombras. Sombra so marca o que flutua de verdade sobre a
/// pagina (folhas, menus, barra de acoes fixa). No tema escuro a separacao vem da superficie
/// mais clara, entao as sombras sao quase invisiveis.
abstract final class AppElevation {
  /// Conteudo no plano da pagina.
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Elementos levemente acima do conteudo: barra de acoes fixa, botao flutuante.
  static List<BoxShadow> raised(AppColors colors) => <BoxShadow>[
    BoxShadow(color: colors.shadow, blurRadius: 2, offset: const Offset(0, 1)),
    BoxShadow(
      color: colors.shadow.withValues(alpha: colors.shadow.a * 0.6),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Camadas sobre a pagina: folhas, dialogos, menus.
  static List<BoxShadow> overlay(AppColors colors) => <BoxShadow>[
    BoxShadow(color: colors.shadow, blurRadius: 6, offset: const Offset(0, 2)),
    BoxShadow(
      color: colors.shadow.withValues(alpha: colors.shadow.a * 0.8),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
}
