part of 'app_inventory_bloc.dart';

sealed class AppInventoryEvent extends Equatable {
  const AppInventoryEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela abriu para um aparelho, opcionalmente ja filtrada por uma categoria.
final class AppInventoryStarted extends AppInventoryEvent {
  const AppInventoryStarted({required this.deviceId, this.initialCategory});

  final String deviceId;
  final AppCategory? initialCategory;

  @override
  List<Object?> get props => <Object?>[deviceId, initialCategory];
}

/// A carga falhou e a pessoa pediu para tentar de novo.
final class AppInventoryRetryRequested extends AppInventoryEvent {
  const AppInventoryRetryRequested();
}

/// A pessoa digitou na busca.
final class AppListQueryChanged extends AppInventoryEvent {
  const AppListQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

/// A pessoa escolheu um filtro por estado.
final class AppListStateFilterChanged extends AppInventoryEvent {
  const AppListStateFilterChanged(this.filter);

  final AppStateFilter filter;

  @override
  List<Object?> get props => <Object?>[filter];
}

/// A pessoa escolheu uma categoria (nula para todas).
final class AppListCategoryChanged extends AppInventoryEvent {
  const AppListCategoryChanged(this.category);

  final AppCategory? category;

  @override
  List<Object?> get props => <Object?>[category];
}

/// O aparelho sincronizou de novo: os tempos de uso dos apps mudaram.
final class _AppInventoryDeviceSynced extends AppInventoryEvent {
  const _AppInventoryDeviceSynced();
}
