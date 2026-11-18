part of 'time_requests_bloc.dart';

sealed class TimeRequestsEvent extends Equatable {
  const TimeRequestsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela abriu (ou a pessoa pediu para tentar de novo): carrega os pedidos dos aparelhos
/// ativos e acompanha a lista de aparelhos e os avisos de pedido novo.
final class TimeRequestsStarted extends TimeRequestsEvent {
  const TimeRequestsStarted();
}

/// Puxar para atualizar. [completer] e concluido quando a recarga termina e nao entra na
/// comparacao do evento.
final class TimeRequestsRefreshRequested extends TimeRequestsEvent {
  const TimeRequestsRefreshRequested({this.completer});

  final Completer<void>? completer;
}

/// O responsavel aprovou um pedido concedendo [minutes].
final class TimeRequestApproved extends TimeRequestsEvent {
  const TimeRequestApproved({required this.request, required this.minutes});

  final TimeRequest request;
  final int minutes;

  @override
  List<Object?> get props => <Object?>[request, minutes];
}

/// O responsavel negou um pedido.
final class TimeRequestDenied extends TimeRequestsEvent {
  const TimeRequestDenied(this.request);

  final TimeRequest request;

  @override
  List<Object?> get props => <Object?>[request];
}

/// Os aparelhos ativos mudaram (aparelho novo, revogado).
final class _TimeRequestsDevicesChanged extends TimeRequestsEvent {
  const _TimeRequestsDevicesChanged(this.deviceIds);

  final List<String> deviceIds;

  @override
  List<Object?> get props => <Object?>[deviceIds];
}
