import 'package:equatable/equatable.dart';

/// Pagina aberta ou barrada, para o historico que o responsavel ve.
final class BrowserVisit extends Equatable {
  /// Pagina que abriu.
  const BrowserVisit.opened({required this.url, this.title}) : blocked = false, reason = null;

  /// Pagina que o filtro barrou, com o motivo.
  const BrowserVisit.blocked({required this.url, this.reason}) : blocked = true, title = null;

  final String url;
  final String? title;
  final bool blocked;
  final String? reason;

  @override
  List<Object?> get props => <Object?>[url, title, blocked, reason];
}
