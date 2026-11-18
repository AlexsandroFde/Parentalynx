part of 'browsing_history_bloc.dart';

/// Historico do navegador gerenciado no periodo.
final class BrowsingHistoryState extends Equatable {
  const BrowsingHistoryState({
    this.onlyBlocked = false,
    this.query = '',
    this.list = const PagedListLoading<BrowsingEntry>(),
    this.from = '',
    this.to = '',
  });

  /// Mostra so as paginas bloqueadas. O filtro e aplicado aos itens ja carregados.
  final bool onlyBlocked;

  /// Busca por titulo, site ou endereco, nos itens ja carregados.
  final String query;
  final PagedListState<BrowsingEntry> list;

  /// Periodo consultado (AAAA-MM-DD), vazio antes de a tela abrir.
  final String from;
  final String to;

  bool get isFiltered => onlyBlocked || query.trim().isNotEmpty;

  /// Verdadeiro quando o item deve aparecer com os filtros atuais.
  bool shows(BrowsingEntry entry) {
    if (onlyBlocked && !entry.blocked) {
      return false;
    }
    final String term = query.trim().toLowerCase();
    if (term.isEmpty) {
      return true;
    }
    return entry.title.toLowerCase().contains(term) ||
        entry.domain.toLowerCase().contains(term) ||
        entry.url.toLowerCase().contains(term);
  }

  BrowsingHistoryState copyWith({
    bool? onlyBlocked,
    String? query,
    PagedListState<BrowsingEntry>? list,
    String? from,
    String? to,
  }) {
    return BrowsingHistoryState(
      onlyBlocked: onlyBlocked ?? this.onlyBlocked,
      query: query ?? this.query,
      list: list ?? this.list,
      from: from ?? this.from,
      to: to ?? this.to,
    );
  }

  @override
  List<Object?> get props => <Object?>[onlyBlocked, query, list, from, to];
}
