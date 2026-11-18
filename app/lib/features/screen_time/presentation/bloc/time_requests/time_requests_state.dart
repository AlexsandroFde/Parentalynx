part of 'time_requests_bloc.dart';

/// Pedidos de tempo dos aparelhos ativos.
sealed class TimeRequestsState extends Equatable {
  const TimeRequestsState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Primeira carga em andamento.
final class TimeRequestsLoading extends TimeRequestsState {
  const TimeRequestsLoading();
}

/// A primeira carga falhou. A tela oferece tentar de novo.
final class TimeRequestsError extends TimeRequestsState {
  const TimeRequestsError(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}

/// Nenhum pedido feito ainda.
final class TimeRequestsEmpty extends TimeRequestsState {
  const TimeRequestsEmpty();
}

/// Pedidos carregados, do mais novo para o mais antigo.
final class TimeRequestsLoaded extends TimeRequestsState {
  const TimeRequestsLoaded({
    required this.requests,
    this.resolvingId,
    this.action = const ActionIdle(),
  });

  /// Quantos pedidos ja respondidos aparecem na tela.
  static const int resolvedShown = 30;

  final List<TimeRequest> requests;

  /// Pedido com resposta em andamento, para desabilitar os botoes dele.
  final String? resolvingId;

  /// Andamento da ultima resposta (aprovar ou negar).
  final ActionStatus action;

  List<TimeRequest> get pending {
    return requests.where((TimeRequest request) => request.isPending).toList();
  }

  List<TimeRequest> get resolved {
    return requests.where((TimeRequest request) => !request.isPending).take(resolvedShown).toList();
  }

  TimeRequestsLoaded copyWith({
    List<TimeRequest>? requests,
    String? resolvingId,
    bool clearResolving = false,
    ActionStatus? action,
  }) {
    return TimeRequestsLoaded(
      requests: requests ?? this.requests,
      resolvingId: clearResolving ? null : (resolvingId ?? this.resolvingId),
      action: action ?? this.action,
    );
  }

  @override
  List<Object?> get props => <Object?>[requests, resolvingId, action];
}
