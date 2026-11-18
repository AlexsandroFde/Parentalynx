import 'package:material_ui/material_ui.dart';

import '../tokens/colors.dart';
import 'app_icons.dart';

/// Significado visual de um aviso, etiqueta ou indicador.
///
/// - [neutral]: informacao sem juizo.
/// - [info]: informacao da marca (dicas, explicacoes).
/// - [success]: permitido, aplicado, online, concluido.
/// - [warning]: atencao, pendente de confirmacao, pouco tempo.
/// - [danger]: erro, acao destrutiva, tentativa bloqueada.
/// - [rest]: descanso combinado (hora de dormir, pausa, periodo bloqueado). Nao e erro: na
///   tela da crianca, restricoes usam este tom e nunca o vermelho.
///
/// A cor nunca e o unico sinal: todo componente com tom mostra tambem um icone e um texto.
enum Tone { neutral, info, success, warning, danger, rest }

extension ToneColors on Tone {
  /// Cor do icone e do texto curto sobre o fundo da pagina ou sobre [background].
  Color foreground(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return switch (this) {
      Tone.neutral => c.textSecondary,
      Tone.info => c.primary,
      Tone.success => c.success,
      Tone.warning => c.warning,
      Tone.danger => c.danger,
      Tone.rest => c.rest,
    };
  }

  /// Fundo suave do tom (faixas, etiquetas, quadrados de icone).
  Color background(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return switch (this) {
      Tone.neutral => c.surfaceMuted,
      Tone.info => c.primaryContainer,
      Tone.success => c.successContainer,
      Tone.warning => c.warningContainer,
      Tone.danger => c.dangerContainer,
      Tone.rest => c.restContainer,
    };
  }

  /// Texto longo sobre [background] (mais escuro que [foreground], para ler confortavelmente).
  Color onBackground(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return switch (this) {
      Tone.neutral => c.textPrimary,
      Tone.info => c.onPrimaryContainer,
      Tone.success => c.onSuccessContainer,
      Tone.warning => c.onWarningContainer,
      Tone.danger => c.onDangerContainer,
      Tone.rest => c.onRestContainer,
    };
  }

  /// Icone padrao do tom, usado quando o componente nao recebe um icone proprio.
  IconData get icon {
    return switch (this) {
      Tone.neutral || Tone.info => AppIcons.info,
      Tone.success => AppIcons.success,
      Tone.warning => AppIcons.warning,
      Tone.danger => AppIcons.error,
      Tone.rest => AppIcons.bedtime,
    };
  }
}
