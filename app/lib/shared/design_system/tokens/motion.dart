import 'package:material_ui/material_ui.dart';

/// Movimento: duracoes e curvas.
///
/// Animacoes explicam o que mudou (um estado que chega, um painel que abre); nao decoram.
/// Use [resolve] para respeitar a preferencia do sistema de reduzir animacoes.
abstract final class AppMotion {
  /// Retorno de toque, troca de icone.
  static const Duration fast = Duration(milliseconds: 120);

  /// Troca de estado de um componente (carregando para conteudo, selecao).
  static const Duration base = Duration(milliseconds: 200);

  /// Entrada de paineis e folhas, mudanca de layout.
  static const Duration slow = Duration(milliseconds: 320);

  /// Valores que crescem (anel do tempo, barras de uso).
  static const Duration emphasis = Duration(milliseconds: 520);

  /// Curva padrao: comeca rapido e assenta suave.
  static const Curve standard = Curves.easeOutCubic;

  /// Entradas com mais presenca (folhas, valores de destaque).
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);

  /// Saidas: aceleram, para nao segurar a atencao no que esta indo embora.
  static const Curve exit = Curves.easeInCubic;

  /// Duracao efetiva: zero quando o sistema pede para reduzir animacoes.
  static Duration resolve(BuildContext context, Duration duration) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : duration;
  }
}
