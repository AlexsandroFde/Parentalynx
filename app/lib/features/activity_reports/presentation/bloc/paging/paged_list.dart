import 'package:equatable/equatable.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../domain/entities/cursor_page.dart';

/// Busca uma pagina a partir do cursor (nulo para a primeira).
typedef PageLoader<T> = Future<Result<CursorPage<T>>> Function(String? before);

/// Estado de uma lista paginada pelo cursor `before` (eventos, navegacao).
sealed class PagedListState<T> extends Equatable {
  const PagedListState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Carregando a primeira pagina.
final class PagedListLoading<T> extends PagedListState<T> {
  const PagedListLoading();
}

/// A primeira pagina falhou. A tela oferece tentar de novo.
final class PagedListError<T> extends PagedListState<T> {
  const PagedListError(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}

/// Nada no periodo.
final class PagedListEmpty<T> extends PagedListState<T> {
  const PagedListEmpty();
}

/// Itens carregados. [loadingMore] e [moreFailure] dizem respeito a pagina seguinte.
final class PagedListLoaded<T> extends PagedListState<T> {
  const PagedListLoaded({
    required this.items,
    this.nextBefore,
    this.loadingMore = false,
    this.moreFailure,
  });

  final List<T> items;

  /// Cursor da pagina seguinte, ou nulo quando nao ha mais itens.
  final String? nextBefore;
  final bool loadingMore;

  /// Falha ao buscar a pagina seguinte. Os itens ja carregados continuam na tela.
  final AppFailure? moreFailure;

  bool get hasMore => nextBefore != null;

  @override
  List<Object?> get props => <Object?>[items, nextBefore, loadingMore, moreFailure];
}

/// Regras de paginacao comuns as listas de relatorio. Os BLoCs usam por composicao.
abstract final class PagedList {
  /// Busca a primeira pagina.
  static Future<PagedListState<T>> first<T>(PageLoader<T> load) async {
    final Result<CursorPage<T>> result = await load(null);
    return switch (result) {
      Ok<CursorPage<T>>(:final CursorPage<T> value) =>
        value.items.isEmpty
            ? PagedListEmpty<T>()
            : PagedListLoaded<T>(items: value.items, nextBefore: value.nextBefore),
      Err<CursorPage<T>>(:final AppFailure failure) => PagedListError<T>(failure),
    };
  }

  /// Estado de "buscando a pagina seguinte", ou nulo quando nao ha o que buscar.
  static PagedListLoaded<T>? startMore<T>(PagedListState<T> state) {
    if (state is! PagedListLoaded<T> || state.loadingMore || !state.hasMore) {
      return null;
    }
    return PagedListLoaded<T>(items: state.items, nextBefore: state.nextBefore, loadingMore: true);
  }

  /// Busca a pagina seguinte e junta aos itens. Recebe o estado devolvido por [startMore].
  static Future<PagedListLoaded<T>> more<T>(PagedListLoaded<T> loading, PageLoader<T> load) async {
    final Result<CursorPage<T>> result = await load(loading.nextBefore);
    return switch (result) {
      Ok<CursorPage<T>>(:final CursorPage<T> value) => PagedListLoaded<T>(
        items: <T>[...loading.items, ...value.items],
        nextBefore: value.nextBefore,
      ),
      Err<CursorPage<T>>(:final AppFailure failure) => PagedListLoaded<T>(
        items: loading.items,
        nextBefore: loading.nextBefore,
        moreFailure: failure,
      ),
    };
  }
}
