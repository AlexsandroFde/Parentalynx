part of 'child_device_status_bloc.dart';

sealed class ChildDeviceStatusState extends Equatable {
  const ChildDeviceStatusState();

  /// Ultimo retrato do agente, quando ha um.
  AgentStatus? get statusOrNull => null;

  @override
  List<Object?> get props => const <Object?>[];
}

/// O aparelho nao esta vinculado: nao ha agente para consultar.
final class ChildDeviceStatusInitial extends ChildDeviceStatusState {
  const ChildDeviceStatusInitial();
}

/// Primeira consulta ao agente em andamento.
final class ChildDeviceStatusLoading extends ChildDeviceStatusState {
  const ChildDeviceStatusLoading();
}

final class ChildDeviceStatusLoaded extends ChildDeviceStatusState {
  const ChildDeviceStatusLoaded(this.status);

  final AgentStatus status;

  @override
  AgentStatus get statusOrNull => status;

  @override
  List<Object?> get props => <Object?>[status];
}

/// O agente nao respondeu e ainda nao ha retrato para mostrar.
final class ChildDeviceStatusFailure extends ChildDeviceStatusState {
  const ChildDeviceStatusFailure(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}
