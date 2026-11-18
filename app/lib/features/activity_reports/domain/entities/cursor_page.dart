import 'package:equatable/equatable.dart';

/// Pagina de uma lista paginada pelo cursor `before` (eventos e navegacao).
final class CursorPage<T> extends Equatable {
  const CursorPage({required this.items, this.nextBefore});

  final List<T> items;

  /// Cursor da proxima pagina, ou nulo quando nao ha mais itens. E opaco para o app.
  final String? nextBefore;

  bool get hasMore => nextBefore != null;

  @override
  List<Object?> get props => <Object?>[items, nextBefore];
}
