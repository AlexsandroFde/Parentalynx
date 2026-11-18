import 'package:material_ui/material_ui.dart';

/// Raios de borda.
///
/// As constantes sao a escala do perfil do responsavel. Os componentes leem a forma do perfil
/// atual com `context.shapes` ([AppShapes]): no modo crianca tudo fica mais arredondado, sem
/// que cada tela precise saber disso.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
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

  /// Botoes, campos, chips grandes.
  final double control;

  /// Paineis, listas agrupadas, cartoes.
  final double container;

  /// Folhas inferiores e dialogos.
  final double sheet;

  /// Quadrados de icone e de app.
  final double tile;

  static const AppShapes guardian = AppShapes(
    control: AppRadius.md,
    container: AppRadius.lg,
    sheet: AppRadius.xl,
    tile: AppRadius.sm,
  );

  static const AppShapes child = AppShapes(control: 20, container: 28, sheet: 32, tile: 16);

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
