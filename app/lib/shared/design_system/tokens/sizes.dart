/// Dimensoes fixas do Design System.
abstract final class AppSizes {
  /// Menor area de toque aceita (diretriz de acessibilidade do Android).
  static const double minTapTarget = 48;

  /// Altura dos botoes e campos principais.
  static const double control = 48;

  /// Altura de botoes secundarios dentro de linhas e paineis. A area de toque continua com
  /// [minTapTarget].
  static const double controlCompact = 36;

  static const double iconXs = 14;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;

  /// Espaco do icone a esquerda das linhas de lista (o icone e desenhado sem fundo).
  static const double rowIcon = 24;

  /// Icone de app ou avatar a esquerda das linhas de lista.
  static const double iconTile = 36;

  /// Icone em destaque de cabecalhos, estados vazios e dialogos ([IconMedallion]).
  static const double medallion = 48;

  /// Icone em destaque dos estados vazios de tela inteira.
  static const double illustration = 56;

  static const double avatarSm = 32;
  static const double avatarMd = 36;
  static const double avatarLg = 48;

  /// Espessura das linhas finas.
  static const double hairline = 1;

  /// Espessura do contorno de foco.
  static const double focusRing = 1.5;

  /// Altura da barra de uso.
  static const double usageBar = 4;

  /// Marcador de estado (ponto colorido ao lado do texto).
  static const double statusDot = 6;
}
