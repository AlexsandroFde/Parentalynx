import 'package:equatable/equatable.dart';

/// Pagina aberta (ou bloqueada) no navegador gerenciado.
final class BrowsingEntry extends Equatable {
  const BrowsingEntry({
    required this.id,
    required this.ts,
    required this.url,
    required this.domain,
    required this.title,
    required this.blocked,
    this.reason,
  });

  final String id;
  final int ts;
  final String url;
  final String domain;
  final String title;
  final bool blocked;

  /// Motivo do bloqueio (`domain_blocked`, `category`, `safe_dns`, `not_in_allowlist`).
  final String? reason;

  /// Titulo para mostrar: o da pagina, ou o dominio quando a pagina nao tem titulo.
  String get displayTitle => title.isEmpty ? domain : title;

  @override
  List<Object?> get props => <Object?>[id, ts, url, domain, title, blocked, reason];
}
