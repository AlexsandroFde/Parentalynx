/// Opacidades dos estados de interacao, iguais em todos os componentes.
abstract final class AppOpacity {
  /// Elemento desabilitado.
  static const double disabled = 0.38;

  /// Conteudo secundario sobre uma cor (por exemplo, legenda sobre o botao primario).
  static const double muted = 0.72;

  /// Camada sobre o elemento ao passar o ponteiro.
  static const double hover = 0.08;

  /// Camada sobre o elemento com foco do teclado.
  static const double focus = 0.12;

  /// Camada sobre o elemento pressionado.
  static const double pressed = 0.12;

  /// Fundo atras de folhas e dialogos.
  static const double scrim = 0.40;
}
