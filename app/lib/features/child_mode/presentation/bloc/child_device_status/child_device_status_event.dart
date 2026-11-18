part of 'child_device_status_bloc.dart';

sealed class ChildDeviceStatusEvent extends Equatable {
  const ChildDeviceStatusEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A area da crianca abriu: acompanha o vinculo e, com o aparelho vinculado, consulta o
/// agente periodicamente.
final class ChildDeviceStatusStarted extends ChildDeviceStatusEvent {
  const ChildDeviceStatusStarted();
}

/// Consultar o agente agora.
///
/// O temporizador pede sem [force], e a consulta e pulada com o app em segundo plano. Com
/// [force] (tentar de novo, depois de uma acao que muda o estado) a consulta acontece sempre.
final class ChildDeviceStatusRefreshRequested extends ChildDeviceStatusEvent {
  const ChildDeviceStatusRefreshRequested({this.force = false});

  final bool force;

  @override
  List<Object?> get props => <Object?>[force];
}

/// O app voltou ao primeiro plano: religa o servico do agente, se o aparelho esta vinculado.
final class ChildDeviceStatusAppResumed extends ChildDeviceStatusEvent {
  const ChildDeviceStatusAppResumed();
}
