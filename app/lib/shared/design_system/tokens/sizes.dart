/// Dimensoes fixas do Design System.
abstract final class AppSizes {
  /// Menor area de toque aceita (diretriz de acessibilidade do Android).
  static const double minTapTarget = 48;

  /// Altura dos botoes e campos principais.
  static const double control = 52;

  /// Altura de botoes secundarios dentro de linhas e paineis. A area de toque continua com
  /// [minTapTarget].
  static const double controlCompact = 40;

  static const double iconXs = 14;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;

  /// Quadrado de icone a esquerda das linhas de lista.
  static const double iconTile = 40;

  /// Icone em destaque dos estados vazios e de erro.
  static const double illustration = 64;

  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 56;

  /// Espessura das linhas finas.
  static const double hairline = 1;

  /// Espessura do contorno de foco.
  static const double focusRing = 2;

  /// Altura da barra de uso.
  static const double usageBar = 6;
}
