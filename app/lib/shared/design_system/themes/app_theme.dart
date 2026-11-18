import 'package:material_ui/material_ui.dart';

import '../tokens/colors.dart';
import '../tokens/motion.dart';
import '../tokens/radius.dart';
import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'app_experience.dart';

/// Temas do ParentaLynx, montados so a partir dos tokens.
///
/// Os componentes do Material ficam com a cara do Design System pelo tema: paineis sem
/// borda sobre o fundo de areia, botoes com a forma do perfil, campos com contorno visivel
/// (3:1), navegacao com indicador em pilula. Assim ate uma tela ainda nao migrada segue a
/// identidade.
abstract final class AppTheme {
  static ThemeData light({AppExperience experience = AppExperience.guardian}) {
    return build(Brightness.light, experience);
  }

  static ThemeData dark({AppExperience experience = AppExperience.guardian}) {
    return build(Brightness.dark, experience);
  }

  static ThemeData build(Brightness brightness, AppExperience experience) {
    final bool isLight = brightness == Brightness.light;
    final AppColors c = isLight ? AppColors.light : AppColors.dark;
    final bool isChild = experience == AppExperience.child;
    final AppShapes shapes = isChild ? AppShapes.child : AppShapes.guardian;
    final double scale = isChild ? 1.08 : 1;
    final TextTheme text = AppTypography.textTheme(
      primary: c.textPrimary,
      secondary: c.textSecondary,
      scale: scale,
    );
    final TextTheme onPrimaryText = AppTypography.textTheme(
      primary: c.onPrimary,
      secondary: c.onPrimary,
      scale: scale,
    );

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      secondaryContainer: c.primaryContainer,
      onSecondaryContainer: c.onPrimaryContainer,
      tertiary: c.rest,
      onTertiary: c.onPrimary,
      tertiaryContainer: c.restContainer,
      onTertiaryContainer: c.onRestContainer,
      error: c.danger,
      onError: c.onDanger,
      errorContainer: c.dangerContainer,
      onErrorContainer: c.onDangerContainer,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceDim: c.surfaceMuted,
      surfaceBright: c.surface,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surfaceMuted,
      surfaceContainerHigh: c.surfaceMuted,
      surfaceContainerHighest: c.surfaceStrong,
      outline: c.outline,
      outlineVariant: c.hairline,
      shadow: c.shadow,
      scrim: c.scrim,
      inverseSurface: c.inverseSurface,
      onInverseSurface: c.onInverseSurface,
      inversePrimary: isLight ? AppPalette.petrol200 : AppPalette.petrol600,
      surfaceTint: Colors.transparent,
    );

    final OutlinedBorder controlShape = RoundedRectangleBorder(borderRadius: shapes.controlRadius);
    const Size controlSize = Size(AppSizes.minTapTarget, AppSizes.control);
    const EdgeInsets controlPadding = EdgeInsets.symmetric(horizontal: AppSpacing.xl);
    final TextStyle? buttonText = text.labelLarge;

    OutlineInputBorder inputBorder(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: shapes.controlRadius,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.family,
      textTheme: text,
      primaryTextTheme: onPrimaryText,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkRipple.splashFactory,
      extensions: <ThemeExtension<dynamic>>[
        c,
        shapes,
        AppTextStyles.build(primary: c.textPrimary, secondary: c.textSecondary, scale: scale),
      ],
      appBarTheme: AppBarThemeData(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.canvas,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        toolbarHeight: 60,
        iconTheme: IconThemeData(color: c.textPrimary, size: AppSizes.iconLg),
        actionsIconTheme: IconThemeData(color: c.textSecondary, size: AppSizes.iconLg),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: shapes.containerRadius),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: controlSize,
          padding: controlPadding,
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: controlSize,
          padding: controlPadding,
          shape: controlShape,
          textStyle: buttonText,
          foregroundColor: c.primary,
          side: BorderSide(color: c.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: controlShape,
          textStyle: buttonText,
          foregroundColor: c.primary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: controlSize,
          padding: controlPadding,
          shape: controlShape,
          textStyle: buttonText,
          elevation: 0,
          backgroundColor: c.surface,
          foregroundColor: c.primary,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
          foregroundColor: c.textSecondary,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.container)),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: c.textTertiary),
        labelStyle: text.bodyLarge?.copyWith(color: c.textSecondary),
        // O rotulo fica sempre visivel; a cor acompanha o estado do campo.
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
          final Color color = states.contains(WidgetState.error)
              ? c.danger
              : states.contains(WidgetState.focused)
              ? c.primary
              : c.textSecondary;
          return (text.bodyMedium ?? const TextStyle()).copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          );
        }),
        helperStyle: text.bodySmall?.copyWith(color: c.textSecondary),
        errorStyle: text.bodySmall?.copyWith(color: c.danger),
        helperMaxLines: 3,
        errorMaxLines: 3,
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
        border: inputBorder(c.outline, 1),
        enabledBorder: inputBorder(c.outline, 1),
        disabledBorder: inputBorder(c.hairline, 1),
        focusedBorder: inputBorder(c.primary, AppSizes.focusRing),
        errorBorder: inputBorder(c.danger, 1),
        focusedErrorBorder: inputBorder(c.danger, AppSizes.focusRing),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return text.labelMedium?.copyWith(
            color: selected ? c.textPrimary : c.textSecondary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: AppSizes.iconLg,
            color: selected ? c.onPrimaryContainer : c.textSecondary,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceMuted,
        selectedColor: c.primaryContainer,
        disabledColor: c.surfaceMuted,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        labelStyle: text.labelLarge?.copyWith(color: c.textPrimary),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: c.onPrimaryContainer),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        checkmarkColor: c.onPrimaryContainer,
        iconTheme: IconThemeData(color: c.textSecondary, size: AppSizes.iconSm),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return c.surfaceStrong;
          }
          return states.contains(WidgetState.selected) ? c.onPrimary : c.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return c.surfaceMuted;
          }
          return states.contains(WidgetState.selected) ? c.primary : c.surfaceStrong;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected) ? Colors.transparent : c.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
        side: BorderSide(color: c.outline, width: 1.5),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: c.primaryContainer,
          selectedForegroundColor: c.onPrimaryContainer,
          foregroundColor: c.textSecondary,
          backgroundColor: c.surface,
          side: BorderSide(color: c.outline),
          textStyle: text.labelLarge,
          minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
          shape: controlShape,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minVerticalPadding: AppSpacing.md,
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        subtitleTextStyle: text.bodyMedium?.copyWith(color: c.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: shapes.controlRadius),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: c.textSecondary,
        collapsedIconColor: c.textSecondary,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      dividerTheme: DividerThemeData(color: c.hairline, space: 1, thickness: AppSizes.hairline),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.onInverseSurface),
        actionTextColor: isLight ? AppPalette.petrol200 : AppPalette.petrol700,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(borderRadius: shapes.controlRadius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.sheet)),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyLarge?.copyWith(color: c.textSecondary),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.surfaceStrong,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(shapes.sheet)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: c.shadow,
        textStyle: text.bodyLarge,
        shape: RoundedRectangleBorder(borderRadius: shapes.controlRadius),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: text.bodySmall?.copyWith(color: c.onInverseSurface),
        waitDuration: AppMotion.slow,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceMuted,
        circularTrackColor: Colors.transparent,
        linearMinHeight: AppSizes.usageBar,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primaryContainer,
        selectionHandleColor: c.primary,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: c.danger,
        textColor: c.onDanger,
        textStyle: text.labelSmall,
      ),
    );
  }
}
