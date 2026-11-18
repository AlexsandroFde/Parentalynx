part of 'browsing_history_bloc.dart';

/// Historico do navegador gerenciado no periodo.
final class BrowsingHistoryState extends Equatable {
  const BrowsingHistoryState({
    this.onlyBlocked = false,
    this.list = const PagedListLoading<BrowsingEntry>(),
  });

  /// Mostra so as paginas bloqueadas. O filtro e aplicado aos itens ja carregados.
  final bool onlyBlocked;
  final PagedListState<BrowsingEntry> list;

  /// Verdadeiro quando o item deve aparecer com o filtro atual.
  bool shows(BrowsingEntry entry) => !onlyBlocked || entry.blocked;

  BrowsingHistoryState copyWith({bool? onlyBlocked, PagedListState<BrowsingEntry>? list}) {
    return BrowsingHistoryState(
      onlyBlocked: onlyBlocked ?? this.onlyBlocked,
      list: list ?? this.list,
    );
  }

  @override
  List<Object?> get props => <Object?>[onlyBlocked, list];
}
