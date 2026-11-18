import 'package:equatable/equatable.dart';

/// Configuracao do navegador gerenciado, vinda da politica aplicada no aparelho.
final class BrowserSettings extends Equatable {
  const BrowserSettings({
    required this.enabled,
    required this.logHistory,
    required this.safeSearch,
    required this.allowlistMode,
  });

  /// Falso quando o responsavel desligou o navegador ou o aparelho nao esta vinculado.
  final bool enabled;

  /// Verdadeiro quando os sites abertos vao para o historico que o responsavel ve.
  final bool logHistory;
  final bool safeSearch;

  /// Verdadeiro quando so os sites autorizados pelo responsavel abrem.
  final bool allowlistMode;

  @override
  List<Object?> get props => <Object?>[enabled, logHistory, safeSearch, allowlistMode];
}
