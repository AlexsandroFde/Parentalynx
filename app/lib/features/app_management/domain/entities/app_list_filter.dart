import 'package:equatable/equatable.dart';

import 'app_entry.dart';
import 'effective_app_state.dart';

/// Filtro por estado da lista de apps.
enum AppStateFilter {
  all('Todos'),
  allowed('Permitidos'),
  blocked('Bloqueados'),
  exception('Exceções'),
  pending('Aguardando');

  const AppStateFilter(this.label);

  final String label;

  bool matches(EffectiveAppState state) {
    return switch (this) {
      AppStateFilter.all => true,
      AppStateFilter.allowed => state == EffectiveAppState.allowed,
      AppStateFilter.blocked => state == EffectiveAppState.blocked,
      AppStateFilter.exception => state == EffectiveAppState.exception,
      AppStateFilter.pending => state == EffectiveAppState.pendingApproval,
    };
  }
}

/// O que a pessoa escolheu para ver na lista de apps: busca, estado e categoria.
final class AppListFilter extends Equatable {
  const AppListFilter({this.query = '', this.state = AppStateFilter.all, this.category});

  final String query;
  final AppStateFilter state;

  /// Categoria escolhida, ou nulo para todas.
  final AppCategory? category;

  /// Verdadeiro quando a lista mostra so parte dos apps.
  bool get isNarrowed {
    return state != AppStateFilter.all || category != null || query.trim().isNotEmpty;
  }

  AppListFilter copyWith({
    String? query,
    AppStateFilter? state,
    AppCategory? category,
    bool allCategories = false,
  }) {
    return AppListFilter(
      query: query ?? this.query,
      state: state ?? this.state,
      category: allCategories ? null : (category ?? this.category),
    );
  }

  @override
  List<Object?> get props => <Object?>[query, state, category];
}
