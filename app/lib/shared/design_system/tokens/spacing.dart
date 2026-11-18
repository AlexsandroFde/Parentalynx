import 'package:material_ui/material_ui.dart';

/// Espacamentos. Escala de 4 em 4 pontos para manter o ritmo vertical em todas as telas.
///
/// Use os nomes da escala ([xs] a [xxxl]) entre elementos e os semanticos ([gutter],
/// [sectionGap], [page]) para a estrutura das paginas. Numeros soltos fora desta classe sao
/// recusados pelo teste do Design System.
abstract final class AppSpacing {
  static const double none = 0;
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Margem lateral das paginas.
  static const double gutter = 20;

  /// Distancia entre secoes de uma pagina. O espaco separa os assuntos, sem bordas.
  static const double sectionGap = 32;

  /// Distancia entre o titulo de uma secao e o seu conteudo.
  static const double sectionHeaderGap = 12;

  /// Margem padrao do conteudo de uma pagina (com folga no fim para a rolagem respirar).
  static const EdgeInsets page = EdgeInsets.fromLTRB(gutter, md, gutter, xxl);

  /// Margem interna de paineis e listas agrupadas.
  static const EdgeInsets panel = EdgeInsets.all(lg);

  /// Margem interna de uma linha de lista.
  static const EdgeInsets row = EdgeInsets.symmetric(horizontal: lg, vertical: md);

  /// Largura maxima do conteudo em telas largas (tablets e celulares deitados).
  static const double maxContentWidth = 640;

  /// Largura maxima de formularios: linhas de texto confortaveis para ler.
  static const double maxFormWidth = 480;
}
