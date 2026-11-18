part of 'app_inventory_bloc.dart';

/// Apps instalados no aparelho e o filtro escolhido para a lista.
sealed class AppInventoryState extends Equatable {
  const AppInventoryState({required this.filter});

  final AppListFilter filter;

  /// Apps carregados, ou lista vazia enquanto nao ha.
  List<AppEntry> get appsOrEmpty => const <AppEntry>[];

  AppInventoryState withFilter(AppListFilter filter);

  @override
  List<Object?> get props => <Object?>[filter];
}

/// Carregando o inventario.
final class AppInventoryLoading extends AppInventoryState {
  const AppInventoryLoading({required super.filter});

  @override
  AppInventoryLoading withFilter(AppListFilter filter) => AppInventoryLoading(filter: filter);
}

/// O inventario nao pode ser carregado. A tela oferece tentar de novo.
final class AppInventoryError extends AppInventoryState {
  const AppInventoryError({required this.failure, required super.filter});

  final AppFailure failure;

  @override
  AppInventoryError withFilter(AppListFilter filter) {
    return AppInventoryError(failure: failure, filter: filter);
  }

  @override
  List<Object?> get props => <Object?>[failure, filter];
}

/// Inventario carregado. Atualizacoes em segundo plano mantem a lista na tela.
final class AppInventoryLoaded extends AppInventoryState {
  const AppInventoryLoaded({required this.inventory, required super.filter});

  final DeviceApps inventory;

  @override
  List<AppEntry> get appsOrEmpty => inventory.apps;

  @override
  AppInventoryLoaded withFilter(AppListFilter filter) {
    return AppInventoryLoaded(inventory: inventory, filter: filter);
  }

  @override
  List<Object?> get props => <Object?>[inventory, filter];
}
