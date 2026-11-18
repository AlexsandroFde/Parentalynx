import 'package:material_ui/material_ui.dart';

/// Paleta base (primitivas) da identidade "Lince".
///
/// So os temas leem estas cores. Telas e componentes usam os papeis de [AppColors] (o que a
/// cor significa), nunca a primitiva (qual cor e). Assim trocar um tom muda o app inteiro e o
/// significado de cada cor continua o mesmo em todas as telas.
///
/// A interface e quase toda neutra: grafite para texto, linhas e superficies, petroleo so no
/// que e interativo e na marca, e as cores de estado (verde, ocre, coral, anil) so em icones e
/// textos curtos de estado, nunca como fundo decorativo.
abstract final class AppPalette {
  // Petroleo: a cor da marca e da acao. Azul-esverdeado profundo, transmite calma e confianca
  // sem o azul generico dos templates.
  static const Color petrol50 = Color(0xFFEDF5F6);
  static const Color petrol100 = Color(0xFFD5E8EA);
  static const Color petrol200 = Color(0xFFA7D0D5);
  static const Color petrol300 = Color(0xFF6DBAC3);
  static const Color petrol400 = Color(0xFF3F9CA8);
  static const Color petrol500 = Color(0xFF22808C);
  static const Color petrol600 = Color(0xFF136874);
  static const Color petrol700 = Color(0xFF0F5661);
  static const Color petrol800 = Color(0xFF0C444D);
  static const Color petrol900 = Color(0xFF082F36);
  static const Color petrol950 = Color(0xFF0F2629);

  // Ambar: os olhos do lince. Exclusivo da marca (logotipo); nunca indica estado.
  static const Color amber300 = Color(0xFFF6C46A);
  static const Color amber500 = Color(0xFFE59B32);

  // Grafite: neutros levemente frios do tema claro.
  static const Color graphite0 = Color(0xFFFFFFFF);
  static const Color graphite50 = Color(0xFFF6F6F7);
  static const Color graphite100 = Color(0xFFF0F0F2);
  static const Color graphite150 = Color(0xFFE6E6EA);
  static const Color graphite200 = Color(0xFFD8D8DE);
  static const Color graphite300 = Color(0xFFC2C2C9);
  static const Color graphite400 = Color(0xFF8B8B94);
  static const Color graphite500 = Color(0xFF73737D);
  static const Color graphite600 = Color(0xFF5C5C66);
  static const Color graphite700 = Color(0xFF3F3F46);
  static const Color graphite800 = Color(0xFF27272B);
  static const Color graphite900 = Color(0xFF17171A);

  // Noite: neutros do tema escuro, da mesma familia do grafite.
  static const Color night1000 = Color(0xFF0F0F11);
  static const Color night900 = Color(0xFF18181B);
  static const Color night850 = Color(0xFF1F1F23);
  static const Color night800 = Color(0xFF26262B);
  static const Color night750 = Color(0xFF2C2C31);
  static const Color night700 = Color(0xFF36363D);
  static const Color night500 = Color(0xFF6E6E78);
  static const Color night400 = Color(0xFF808089);
  static const Color night300 = Color(0xFFA3A3AD);
  static const Color night100 = Color(0xFFECECEF);

  // Verde: permitido, aplicado, online.
  static const Color green50 = Color(0xFFEDF6F0);
  static const Color green300 = Color(0xFF7FD3A6);
  static const Color green600 = Color(0xFF1A6E44);
  static const Color green800 = Color(0xFF0E4A2C);
  static const Color green950 = Color(0xFF12241A);

  // Ocre: atencao, pendente, pouco tempo.
  static const Color ochre50 = Color(0xFFFBF3E6);
  static const Color ochre300 = Color(0xFFF2BF6C);
  static const Color ochre600 = Color(0xFF8A5100);
  static const Color ochre800 = Color(0xFF5C3600);
  static const Color ochre950 = Color(0xFF2A2113);

  // Coral: erro, acao destrutiva, tentativa bloqueada.
  static const Color coral50 = Color(0xFFFBEEEC);
  static const Color coral300 = Color(0xFFFF9F93);
  static const Color coral600 = Color(0xFFB4372F);
  static const Color coral800 = Color(0xFF7A221C);
  static const Color coral900 = Color(0xFF3B0D09);
  static const Color coral950 = Color(0xFF2D1715);

  // Anil: descanso (hora de dormir, pausa, periodo bloqueado). Um estado combinado, nao um
  // erro: por isso nao usa o vermelho.
  static const Color indigo50 = Color(0xFFF0EFFA);
  static const Color indigo300 = Color(0xFFB7AFF3);
  static const Color indigo600 = Color(0xFF5248A8);
  static const Color indigo800 = Color(0xFF362F78);
  static const Color indigo950 = Color(0xFF1E1C33);

  // Cores categoricas dos graficos (ordem fixa, contraste conferido nos dois temas).
  static const Color chartPetrol = Color(0xFF22808C);
  static const Color chartAmber = Color(0xFFD08A1E);
  static const Color chartViolet = Color(0xFF6E5BC9);
  static const Color chartGreen = Color(0xFF2E8B57);
  static const Color chartRose = Color(0xFFC0507A);
  static const Color chartSlate = Color(0xFF6C7A86);
}

/// Papeis de cor do Design System. Lidos com `context.colors` (ver `ds_context.dart`).
///
/// Cada papel tem um significado fixo em todo o app:
/// - [canvas]: fundo das paginas.
/// - [surface]: conteudo sobre o fundo (paineis, listas, folhas, campos).
/// - [surfaceMuted]: areas de apoio (trilhos, avatares, campos de leitura).
/// - [hairline], [border], [outline]: linhas, da mais leve (divisores e contorno de paineis)
///   a mais forte (contorno de campos).
/// - [primary]: a marca e tudo o que e interativo (botoes, links, selecao, foco).
/// - [success], [warning], [danger], [rest]: estados, sempre em icone e texto curto.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceStrong,
    required this.hairline,
    required this.border,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.brandAccent,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.rest,
    required this.restContainer,
    required this.onRestContainer,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.shadow,
    required this.scrim,
    required this.chart,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceMuted;

  /// Trilhos e esqueletos de carregamento: um passo acima de [surfaceMuted].
  final Color surfaceStrong;

  /// Divisores e contorno de paineis e listas.
  final Color hairline;

  /// Contorno de controles que ja se identificam pelo texto (botao secundario, chips).
  final Color border;

  /// Contornos que precisam ser percebidos (campos, caixas de selecao): 3:1 sobre o fundo.
  final Color outline;

  final Color textPrimary;

  /// Texto de apoio. Contraste de pelo menos 4,5:1 sobre [canvas] e [surface].
  final Color textSecondary;

  /// Texto de exemplo dos campos. Contraste de 4,5:1 sobre [surface].
  final Color textTertiary;

  final Color primary;
  final Color onPrimary;

  /// Fundo leve da selecao (chip escolhido, texto selecionado).
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Ambar da marca: so no logotipo e em momentos da marca, nunca como estado.
  final Color brandAccent;

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;
  final Color rest;
  final Color restContainer;
  final Color onRestContainer;
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color shadow;
  final Color scrim;

  /// Cores categoricas dos graficos, na ordem de uso.
  final List<Color> chart;

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  static const AppColors light = AppColors(
    canvas: AppPalette.graphite50,
    surface: AppPalette.graphite0,
    surfaceMuted: AppPalette.graphite100,
    surfaceStrong: AppPalette.graphite150,
    hairline: AppPalette.graphite150,
    border: AppPalette.graphite200,
    outline: AppPalette.graphite400,
    textPrimary: AppPalette.graphite900,
    textSecondary: AppPalette.graphite600,
    textTertiary: AppPalette.graphite500,
    primary: AppPalette.petrol600,
    onPrimary: AppPalette.graphite0,
    primaryContainer: AppPalette.petrol50,
    onPrimaryContainer: AppPalette.petrol800,
    brandAccent: AppPalette.amber500,
    success: AppPalette.green600,
    successContainer: AppPalette.green50,
    onSuccessContainer: AppPalette.green800,
    warning: AppPalette.ochre600,
    warningContainer: AppPalette.ochre50,
    onWarningContainer: AppPalette.ochre800,
    danger: AppPalette.coral600,
    onDanger: AppPalette.graphite0,
    dangerContainer: AppPalette.coral50,
    onDangerContainer: AppPalette.coral800,
    rest: AppPalette.indigo600,
    restContainer: AppPalette.indigo50,
    onRestContainer: AppPalette.indigo800,
    inverseSurface: AppPalette.graphite900,
    onInverseSurface: AppPalette.graphite50,
    shadow: Color(0x140B0B0F),
    scrim: Color(0x66000000),
    chart: <Color>[
      AppPalette.chartPetrol,
      AppPalette.chartAmber,
      AppPalette.chartViolet,
      AppPalette.chartGreen,
      AppPalette.chartRose,
      AppPalette.chartSlate,
    ],
  );

  static const AppColors dark = AppColors(
    canvas: AppPalette.night1000,
    surface: AppPalette.night900,
    surfaceMuted: AppPalette.night850,
    surfaceStrong: AppPalette.night750,
    hairline: AppPalette.night800,
    border: AppPalette.night700,
    outline: AppPalette.night500,
    textPrimary: AppPalette.night100,
    textSecondary: AppPalette.night300,
    textTertiary: AppPalette.night400,
    primary: AppPalette.petrol300,
    onPrimary: AppPalette.petrol900,
    primaryContainer: AppPalette.petrol950,
    onPrimaryContainer: AppPalette.petrol100,
    brandAccent: AppPalette.amber300,
    success: AppPalette.green300,
    successContainer: AppPalette.green950,
    onSuccessContainer: AppPalette.green50,
    warning: AppPalette.ochre300,
    warningContainer: AppPalette.ochre950,
    onWarningContainer: AppPalette.ochre50,
    danger: AppPalette.coral300,
    onDanger: AppPalette.coral900,
    dangerContainer: AppPalette.coral950,
    onDangerContainer: AppPalette.coral50,
    rest: AppPalette.indigo300,
    restContainer: AppPalette.indigo950,
    onRestContainer: AppPalette.indigo50,
    inverseSurface: AppPalette.night100,
    onInverseSurface: AppPalette.night900,
    shadow: Color(0x66000000),
    scrim: Color(0x99000000),
    chart: <Color>[
      AppPalette.petrol300,
      AppPalette.amber300,
      AppPalette.indigo300,
      AppPalette.green300,
      Color(0xFFF08DB0),
      AppPalette.night300,
    ],
  );

  @override
  AppColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceStrong,
    Color? hairline,
    Color? border,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? brandAccent,
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? rest,
    Color? restContainer,
    Color? onRestContainer,
    Color? inverseSurface,
    Color? onInverseSurface,
    Color? shadow,
    Color? scrim,
    List<Color>? chart,
  }) {
    return AppColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      hairline: hairline ?? this.hairline,
      border: border ?? this.border,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      brandAccent: brandAccent ?? this.brandAccent,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      rest: rest ?? this.rest,
      restContainer: restContainer ?? this.restContainer,
      onRestContainer: onRestContainer ?? this.onRestContainer,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      onInverseSurface: onInverseSurface ?? this.onInverseSurface,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
      chart: chart ?? this.chart,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      surfaceStrong: mix(surfaceStrong, other.surfaceStrong),
      hairline: mix(hairline, other.hairline),
      border: mix(border, other.border),
      outline: mix(outline, other.outline),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primaryContainer: mix(primaryContainer, other.primaryContainer),
      onPrimaryContainer: mix(onPrimaryContainer, other.onPrimaryContainer),
      brandAccent: mix(brandAccent, other.brandAccent),
      success: mix(success, other.success),
      successContainer: mix(successContainer, other.successContainer),
      onSuccessContainer: mix(onSuccessContainer, other.onSuccessContainer),
      warning: mix(warning, other.warning),
      warningContainer: mix(warningContainer, other.warningContainer),
      onWarningContainer: mix(onWarningContainer, other.onWarningContainer),
      danger: mix(danger, other.danger),
      onDanger: mix(onDanger, other.onDanger),
      dangerContainer: mix(dangerContainer, other.dangerContainer),
      onDangerContainer: mix(onDangerContainer, other.onDangerContainer),
      rest: mix(rest, other.rest),
      restContainer: mix(restContainer, other.restContainer),
      onRestContainer: mix(onRestContainer, other.onRestContainer),
      inverseSurface: mix(inverseSurface, other.inverseSurface),
      onInverseSurface: mix(onInverseSurface, other.onInverseSurface),
      shadow: mix(shadow, other.shadow),
      scrim: mix(scrim, other.scrim),
      chart: <Color>[
        for (int i = 0; i < chart.length && i < other.chart.length; i++)
          mix(chart[i], other.chart[i]),
      ],
    );
  }
}
