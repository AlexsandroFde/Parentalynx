part of 'permissions_bloc.dart';

sealed class PermissionsState extends Equatable {
  const PermissionsState();
}

/// Verificando as permissoes.
final class PermissionsLoading extends PermissionsState {
  const PermissionsLoading();

  @override
  List<Object?> get props => const <Object?>[];
}

/// O aparelho nao informou as permissoes.
final class PermissionsLoadFailure extends PermissionsState {
  const PermissionsLoadFailure(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}

final class PermissionsLoaded extends PermissionsState {
  const PermissionsLoaded({required this.plan, this.opening, this.action = const ActionIdle()});

  final PermissionPlan plan;

  /// Passo cuja tela do sistema esta sendo aberta. Os outros botoes ficam desabilitados.
  final PermissionKind? opening;

  /// Resultado do ultimo botao tocado, para a tela avisar.
  final ActionStatus action;

  PermissionsLoaded copyWith({PermissionPlan? plan, ActionStatus? action}) {
    return PermissionsLoaded(
      plan: plan ?? this.plan,
      opening: opening,
      action: action ?? this.action,
    );
  }

  /// Comecou a abrir a tela do passo [kind].
  PermissionsLoaded startOpening(PermissionKind kind) {
    return PermissionsLoaded(plan: plan, opening: kind, action: const ActionRunning());
  }

  /// Terminou de abrir a tela do passo.
  PermissionsLoaded finished(ActionStatus action) {
    return PermissionsLoaded(plan: plan, action: action);
  }

  @override
  List<Object?> get props => <Object?>[plan, opening, action];
}
