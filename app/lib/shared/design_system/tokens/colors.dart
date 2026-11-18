import 'package:material_ui/material_ui.dart';

/// Paleta base (primitivas) da identidade "Lince".
///
/// So os temas leem estas cores. Telas e componentes usam os papeis de [AppColors] (o que a
/// cor significa), nunca a primitiva (qual cor e). Assim trocar um tom muda o app inteiro e o
/// significado de cada cor continua o mesmo em todas as telas.
abstract final class AppPalette {
  // Petroleo: a cor da marca. Azul-esverdeado profundo, transmite calma e confianca sem o
  // azul generico dos templates.
  static const Color petrol50 = Color(0xFFE8F4F5);
  static const Color petrol100 = Color(0xFFCDE9EC);
  static const Color petrol200 = Color(0xFF9FD3D9);
  static const Color petrol300 = Color(0xFF6DBAC3);
  static const Color petrol400 = Color(0xFF3F9CA8);
  static const Color petrol500 = Color(0xFF22808C);
  static const Color petrol600 = Color(0xFF136874);
  static const Color petrol700 = Color(0xFF0F5661);
  static const Color petrol800 = Color(0xFF0C444D);
  static const Color petrol900 = Color(0xFF082F36);

  // Ambar: os olhos do lince. Exclusivo da marca (logotipo); nunca indica estado.
  static const Color amber300 = Color(0xFFF6C46A);
  static const Color amber500 = Color(0xFFE59B32);

  // Areia: neutros quentes do tema claro.
  static const Color sand0 = Color(0xFFFFFFFF);
  static const Color sand25 = Color(0xFFFBFAF7);
  static const Color sand50 = Color(0xFFF6F4EF);
  static const Color sand100 = Color(0xFFEEEBE4);
  static const Color sand200 = Color(0xFFE3DFD6);
  static const Color sand300 = Color(0xFFCFC9BD);
  static const Color sand400 = Color(0xFFA9A398);
  static const Color sand500 = Color(0xFF85817A);
  static const Color sand600 = Color(0xFF66635D);
  static const Color sand700 = Color(0xFF4B4945);
  static const Color sand800 = Color(0xFF2F2E2C);
  static const Color sand900 = Color(0xFF1C1C1B);

  // Noite: neutros do tema escuro, levemente frios para nao parecer marrom.
  static const Color night950 = Color(0xFF0F1112);
  static const Color night900 = Color(0xFF15181A);
  static const Color night850 = Color(0xFF1B1F21);
  static const Color night800 = Color(0xFF22272A);
  static const Color night700 = Color(0xFF2D3337);
  static const Color night600 = Color(0xFF3B4247);
  static const Color night500 = Color(0xFF59636A);
  static const Color night400 = Color(0xFF7B858B);
  static const Color night300 = Color(0xFFA7B0B4);
  static const Color night100 = Color(0xFFE9ECEC);

  // Verde: permitido, aplicado, online.
  static const Color green100 = Color(0xFFDCF2E5);
  static const Color green300 = Color(0xFF7FD3A6);
  static const Color green600 = Color(0xFF1A6E44);
  static const Color green800 = Color(0xFF0E4A2C);
  static const Color green900 = Color(0xFF133D29);

  // Ocre: atencao, pendente, pouco tempo.
  static const Color ochre100 = Color(0xFFFBEACB);
  static const Color ochre300 = Color(0xFFF2BF6C);
  static const Color ochre600 = Color(0xFF8A5100);
  static const Color ochre800 = Color(0xFF5C3600);
  static const Color ochre900 = Color(0xFF432F0E);

  // Coral: erro, acao destrutiva, tentativa bloqueada.
  static const Color coral100 = Color(0xFFFADFDB);
  static const Color coral300 = Color(0xFFFF9F93);
  static const Color coral600 = Color(0xFFB4372F);
  static const Color coral800 = Color(0xFF7A221C);
  static const Color coral900 = Color(0xFF4E1B16);

  // Anil: descanso (hora de dormir, pausa, periodo bloqueado). Um estado combinado, nao um
  // erro: por isso nao usa o vermelho.
  static const Color indigo100 = Color(0xFFE7E4F8);
  static const Color indigo300 = Color(0xFFB7AFF3);
  static const Color indigo600 = Color(0xFF5248A8);
  static const Color indigo800 = Color(0xFF362F78);
  static const Color indigo900 = Color(0xFF2A255A);

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
/// - [surface]: conteudo em destaque sobre o fundo (paineis, listas, folhas, campos).
/// - [surfaceMuted]: areas de apoio (trilhos, chips, campos de leitura).
/// - [success]: permitido, aplicado, online.
/// - [warning]: atencao, pendente de confirmacao, pouco tempo.
/// - [danger]: erro, acao destrutiva, tentativa bloqueada.
/// - [rest]: descanso combinado (hora de dormir, pausa).
/// - [primary]: a marca e tudo o que e interativo (botoes, links, selecao, foco).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceStrong,
    required this.hairline,
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
  final Color surfaceStrong;

  /// Linhas finas de separacao (divisores dentro de listas).
  final Color hairline;

  /// Contornos que precisam ser percebidos (campos, botao contornado): 3:1 sobre o fundo.
  final Color outline;

  final Color textPrimary;

  /// Texto de apoio. Contraste de pelo menos 4,5:1 sobre [canvas] e [surface].
  final Color textSecondary;

  /// Texto desabilitado e marcadores de lugar. Nunca para informacao essencial.
  final Color textTertiary;

  final Color primary;
  final Color onPrimary;
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
    canvas: AppPalette.sand50,
    surface: AppPalette.sand0,
    surfaceMuted: AppPalette.sand100,
    surfaceStrong: AppPalette.sand200,
    hairline: AppPalette.sand200,
    outline: AppPalette.sand500,
    textPrimary: AppPalette.sand900,
    textSecondary: AppPalette.sand600,
    textTertiary: AppPalette.sand500,
    primary: AppPalette.petrol600,
    onPrimary: AppPalette.sand0,
    primaryContainer: AppPalette.petrol100,
    onPrimaryContainer: AppPalette.petrol900,
    brandAccent: AppPalette.amber500,
    success: AppPalette.green600,
    successContainer: AppPalette.green100,
    onSuccessContainer: AppPalette.green800,
    warning: AppPalette.ochre600,
    warningContainer: AppPalette.ochre100,
    onWarningContainer: AppPalette.ochre800,
    danger: AppPalette.coral600,
    onDanger: AppPalette.sand0,
    dangerContainer: AppPalette.coral100,
    onDangerContainer: AppPalette.coral800,
    rest: AppPalette.indigo600,
    restContainer: AppPalette.indigo100,
    onRestContainer: AppPalette.indigo800,
    inverseSurface: AppPalette.sand900,
    onInverseSurface: AppPalette.sand50,
    shadow: Color(0x1F2B241A),
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
    canvas: AppPalette.night950,
    surface: AppPalette.night850,
    surfaceMuted: AppPalette.night800,
    surfaceStrong: AppPalette.night700,
    hairline: AppPalette.night700,
    outline: AppPalette.night500,
    textPrimary: AppPalette.night100,
    textSecondary: AppPalette.night300,
    textTertiary: AppPalette.night400,
    primary: AppPalette.petrol200,
    onPrimary: AppPalette.petrol900,
    primaryContainer: AppPalette.petrol800,
    onPrimaryContainer: AppPalette.petrol100,
    brandAccent: AppPalette.amber300,
    success: AppPalette.green300,
    successContainer: AppPalette.green900,
    onSuccessContainer: AppPalette.green100,
    warning: AppPalette.ochre300,
    warningContainer: AppPalette.ochre900,
    onWarningContainer: AppPalette.ochre100,
    danger: AppPalette.coral300,
    onDanger: AppPalette.coral900,
    dangerContainer: AppPalette.coral900,
    onDangerContainer: AppPalette.coral100,
    rest: AppPalette.indigo300,
    restContainer: AppPalette.indigo900,
    onRestContainer: AppPalette.indigo100,
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
