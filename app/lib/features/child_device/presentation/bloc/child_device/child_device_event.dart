part of 'child_device_bloc.dart';

sealed class ChildDeviceEvent extends Equatable {
  const ChildDeviceEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela de detalhe abriu: acompanha o aparelho na lista da conta.
final class ChildDeviceStarted extends ChildDeviceEvent {
  const ChildDeviceStarted(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => <Object?>[deviceId];
}

/// Trocar o nome da crianca.
final class ChildDeviceRenameRequested extends ChildDeviceEvent {
  const ChildDeviceRenameRequested(this.childName);

  final String childName;

  @override
  List<Object?> get props => <Object?>[childName];
}

/// Desvincular o aparelho (ja confirmado pela pessoa).
final class ChildDeviceRevokeRequested extends ChildDeviceEvent {
  const ChildDeviceRevokeRequested();
}

/// Apagar so o historico do aparelho (ja confirmado pela pessoa).
final class ChildDeviceDataDeleteRequested extends ChildDeviceEvent {
  const ChildDeviceDataDeleteRequested();
}

/// Apagar o aparelho e todo o historico (ja confirmado pela pessoa).
final class ChildDeviceDeleteRequested extends ChildDeviceEvent {
  const ChildDeviceDeleteRequested();
}

/// Exportar os dados guardados do aparelho.
final class ChildDeviceExportRequested extends ChildDeviceEvent {
  const ChildDeviceExportRequested();
}

/// Mostrar o codigo de acesso offline do aparelho.
final class ChildDeviceOfflineCodeRequested extends ChildDeviceEvent {
  const ChildDeviceOfflineCodeRequested();
}
