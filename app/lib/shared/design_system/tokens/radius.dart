import 'package:material_ui/material_ui.dart';

/// Raios de borda.
///
/// Raios contidos: controles em 8, paineis em 12, folhas em 16. Elementos dentro de um painel
/// usam um raio menor que o do painel, para os cantos acompanharem uns aos outros. As
/// constantes sao a escala do perfil do responsavel; os componentes leem a forma do perfil
/// atual com `context.shapes` ([AppShapes]): no modo crianca os cantos ficam um pouco mais
/// suaves, sem que cada tela precise saber disso.
abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 20;
  static const double pill = 999;
}

/// Formas do perfil atual: raio dos controles (botoes, campos), dos conteineres (paineis,
/// listas) e das folhas e dialogos.
@immutable
class AppShapes extends ThemeExtension<AppShapes> {
  const AppShapes({
    required this.control,
    required this.container,
    required this.sheet,
    required this.tile,
  });

  /// Botoes, campos, chips.
  final double control;

  /// Paineis, listas agrupadas, avisos.
  final double container;

  /// Folhas inferiores e dialogos.
  final double sheet;

  /// Icones de app e quadrados de icone.
  final double tile;

  static const AppShapes guardian = AppShapes(
    control: AppRadius.md,
    container: AppRadius.lg,
    sheet: AppRadius.xl,
    tile: AppRadius.md,
  );

  static const AppShapes child = AppShapes(
    control: AppRadius.lg,
    container: AppRadius.xl,
    sheet: AppRadius.xxl,
    tile: AppRadius.lg,
  );

  BorderRadius get controlRadius => BorderRadius.circular(control);

  BorderRadius get containerRadius => BorderRadius.circular(container);

  BorderRadius get tileRadius => BorderRadius.circular(tile);

  static AppShapes of(BuildContext context) => Theme.of(context).extension<AppShapes>() ?? guardian;

  @override
  AppShapes copyWith({double? control, double? container, double? sheet, double? tile}) {
    return AppShapes(
      control: control ?? this.control,
      container: container ?? this.container,
      sheet: sheet ?? this.sheet,
      tile: tile ?? this.tile,
    );
  }

  @override
  AppShapes lerp(ThemeExtension<AppShapes>? other, double t) {
    if (other is! AppShapes) {
      return this;
    }
    double mix(double a, double b) => a + (b - a) * t;
    return AppShapes(
      control: mix(control, other.control),
      container: mix(container, other.container),
      sheet: mix(sheet, other.sheet),
      tile: mix(tile, other.tile),
    );
  }
}
