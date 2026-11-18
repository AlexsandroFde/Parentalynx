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
/// O tom colore icones e textos curtos, nao fundos: avisos e etiquetas ficam sobre a
/// superficie neutra. A cor nunca e o unico sinal: todo componente com tom mostra tambem um
/// icone ou marcador e um texto.
enum Tone { neutral, info, success, warning, danger, rest }

extension ToneColors on Tone {
  /// Cor do icone e do texto curto do tom sobre o fundo da pagina ou sobre a superficie.
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

  /// Cor de um icone que acompanha um titulo (linhas de lista, marcadores). So os tons que
  /// pedem atencao ou confirmam algo ficam coloridos; os demais usam o cinza do texto de apoio,
  /// para a lista nao virar um arco-iris de icones.
  Color iconColor(BuildContext context) {
    return switch (this) {
      Tone.neutral || Tone.info || Tone.rest => AppColors.of(context).textSecondary,
      Tone.success || Tone.warning || Tone.danger => foreground(context),
    };
  }

  /// Fundo leve do tom, para o raro conteudo que precisa se destacar como um bloco (um painel
  /// de resumo de estado). Avisos, etiquetas e icones nao usam fundo.
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

  /// Texto longo sobre [background].
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

  /// Contorno de um bloco com o tom. Atencao e erro ganham um contorno da cor do tom; os demais
  /// usam a linha fina neutra.
  Color border(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return switch (this) {
      Tone.warning ||
      Tone.danger => Color.alphaBlend(foreground(context).withValues(alpha: 0.4), c.surface),
      _ => c.hairline,
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
