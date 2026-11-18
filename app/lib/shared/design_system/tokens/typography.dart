import 'package:material_ui/material_ui.dart';

/// Tipografia: a familia Manrope, embutida no app.
///
/// Manrope tem desenho geometrico e humano ao mesmo tempo: firme o bastante para o painel do
/// responsavel e amigavel para a crianca. Os titulos usam espacamento entre letras levemente
/// negativo (mais compacto e com mais personalidade); o corpo usa peso 500, que fica mais
/// legivel em telas de baixa densidade.
abstract final class AppTypography {
  static const String family = 'Manrope';

  /// Algarismos de largura fixa: tempos e contagens nao "pulam" quando mudam.
  static const List<FontFeature> tabularFigures = <FontFeature>[FontFeature.tabularFigures()];

  /// Escala de texto do perfil. [scale] amplia corpo e titulos no modo crianca.
  static TextTheme textTheme({required Color primary, required Color secondary, double scale = 1}) {
    TextStyle style(
      double size,
      double height,
      FontWeight weight, {
      double letterSpacing = 0,
      Color? color,
    }) {
      final double scaled = size * scale;
      return TextStyle(
        fontFamily: family,
        fontSize: scaled,
        height: height / size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color ?? primary,
        leadingDistribution: TextLeadingDistribution.even,
      );
    }

    return TextTheme(
      displayLarge: style(52, 56, FontWeight.w800, letterSpacing: -1.6),
      displayMedium: style(44, 48, FontWeight.w800, letterSpacing: -1.2),
      displaySmall: style(36, 42, FontWeight.w800, letterSpacing: -0.9),
      headlineLarge: style(30, 36, FontWeight.w800, letterSpacing: -0.7),
      headlineMedium: style(26, 32, FontWeight.w700, letterSpacing: -0.5),
      headlineSmall: style(22, 28, FontWeight.w700, letterSpacing: -0.3),
      titleLarge: style(19, 26, FontWeight.w700, letterSpacing: -0.2),
      titleMedium: style(16, 22, FontWeight.w700, letterSpacing: -0.1),
      titleSmall: style(14, 20, FontWeight.w700),
      bodyLarge: style(16, 24, FontWeight.w500),
      bodyMedium: style(14, 20, FontWeight.w500),
      bodySmall: style(12.5, 17, FontWeight.w500, letterSpacing: 0.1, color: secondary),
      labelLarge: style(15, 20, FontWeight.w700),
      labelMedium: style(13, 18, FontWeight.w700, letterSpacing: 0.1),
      labelSmall: style(11.5, 16, FontWeight.w700, letterSpacing: 0.4),
    );
  }
}

/// Estilos que nao fazem parte da escala do Material: numeros de destaque e o sobretitulo.
/// Lidos com `context.textStyles`.
@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.metricHero,
    required this.metricLarge,
    required this.metricMedium,
    required this.metricSmall,
    required this.eyebrow,
  });

  /// Valor principal da tela (tempo restante no modo crianca).
  final TextStyle metricHero;

  /// Valor de destaque de um painel (tempo restante no painel do responsavel).
  final TextStyle metricLarge;

  /// Valores de uma linha de metricas.
  final TextStyle metricMedium;

  /// Valores pequenos alinhados em listas (minutos de cada app).
  final TextStyle metricSmall;

  /// Rotulo curto acima de um titulo ("APARELHO", "HOJE").
  final TextStyle eyebrow;

  static AppTextStyles build({required Color primary, required Color secondary, double scale = 1}) {
    TextStyle numeric(double size, double height, FontWeight weight, double spacing) {
      return TextStyle(
        fontFamily: AppTypography.family,
        fontSize: size * scale,
        height: height / size,
        fontWeight: weight,
        letterSpacing: spacing,
        color: primary,
        fontFeatures: AppTypography.tabularFigures,
        leadingDistribution: TextLeadingDistribution.even,
      );
    }

    return AppTextStyles(
      metricHero: numeric(52, 56, FontWeight.w800, -1.8),
      metricLarge: numeric(38, 44, FontWeight.w800, -1.2),
      metricMedium: numeric(22, 28, FontWeight.w700, -0.4),
      metricSmall: numeric(14, 20, FontWeight.w700, 0),
      eyebrow: TextStyle(
        fontFamily: AppTypography.family,
        fontSize: 11.5 * scale,
        height: 16 / 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: secondary,
      ),
    );
  }

  static AppTextStyles of(BuildContext context) {
    final AppTextStyles? styles = Theme.of(context).extension<AppTextStyles>();
    if (styles != null) {
      return styles;
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return build(primary: scheme.onSurface, secondary: scheme.onSurfaceVariant);
  }

  @override
  AppTextStyles copyWith({
    TextStyle? metricHero,
    TextStyle? metricLarge,
    TextStyle? metricMedium,
    TextStyle? metricSmall,
    TextStyle? eyebrow,
  }) {
    return AppTextStyles(
      metricHero: metricHero ?? this.metricHero,
      metricLarge: metricLarge ?? this.metricLarge,
      metricMedium: metricMedium ?? this.metricMedium,
      metricSmall: metricSmall ?? this.metricSmall,
      eyebrow: eyebrow ?? this.eyebrow,
    );
  }

  @override
  AppTextStyles lerp(ThemeExtension<AppTextStyles>? other, double t) {
    if (other is! AppTextStyles) {
      return this;
    }
    return AppTextStyles(
      metricHero: TextStyle.lerp(metricHero, other.metricHero, t)!,
      metricLarge: TextStyle.lerp(metricLarge, other.metricLarge, t)!,
      metricMedium: TextStyle.lerp(metricMedium, other.metricMedium, t)!,
      metricSmall: TextStyle.lerp(metricSmall, other.metricSmall, t)!,
      eyebrow: TextStyle.lerp(eyebrow, other.eyebrow, t)!,
    );
  }
}
