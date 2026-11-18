import 'package:material_ui/material_ui.dart';

/// Tipografia: a familia Manrope, embutida no app.
///
/// A hierarquia vem do tamanho e da cor, nao do excesso de peso: titulos, rotulos e numeros em
/// seminegrito (600) e texto corrido em medio (500), que na Manrope fica firme sem pesar e
/// continua legivel em telas de baixa densidade. Titulos grandes tem espacamento entre letras
/// levemente negativo, para ficarem compactos sem precisar de mais peso.
///
/// Textos de ate 13 pontos usam 600: com hastes mais finas, a medicao de contraste dos testes
/// (feita em uma imagem de 1x) confunde o serrilhado com a cor do texto.
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
      displayLarge: style(48, 52, FontWeight.w600, letterSpacing: -1.4),
      displayMedium: style(40, 46, FontWeight.w600, letterSpacing: -1.1),
      displaySmall: style(34, 40, FontWeight.w600, letterSpacing: -0.8),
      headlineLarge: style(28, 34, FontWeight.w600, letterSpacing: -0.6),
      headlineMedium: style(24, 30, FontWeight.w600, letterSpacing: -0.5),
      headlineSmall: style(20, 26, FontWeight.w600, letterSpacing: -0.3),
      titleLarge: style(18, 24, FontWeight.w600, letterSpacing: -0.2),
      titleMedium: style(15, 20, FontWeight.w600, letterSpacing: -0.1),
      titleSmall: style(14, 20, FontWeight.w600),
      bodyLarge: style(16, 24, FontWeight.w500),
      bodyMedium: style(14, 20, FontWeight.w500),
      bodySmall: style(12.5, 18, FontWeight.w500, letterSpacing: 0.1, color: secondary),
      labelLarge: style(15, 20, FontWeight.w600),
      labelMedium: style(13, 18, FontWeight.w600),
      labelSmall: style(11.5, 16, FontWeight.w600, letterSpacing: 0.2),
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

  /// Rotulo curto acima de um titulo ("Hoje", "Passo 1 de 3"), em caixa normal.
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
      metricHero: numeric(48, 52, FontWeight.w600, -1.6),
      metricLarge: numeric(34, 40, FontWeight.w600, -1.0),
      metricMedium: numeric(20, 26, FontWeight.w600, -0.4),
      metricSmall: numeric(14, 20, FontWeight.w600, 0),
      eyebrow: TextStyle(
        fontFamily: AppTypography.family,
        fontSize: 13 * scale,
        height: 18 / 13,
        fontWeight: FontWeight.w600,
        color: secondary,
        leadingDistribution: TextLeadingDistribution.even,
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
