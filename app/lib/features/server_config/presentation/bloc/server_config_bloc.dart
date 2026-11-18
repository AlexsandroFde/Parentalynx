import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/event_transformers.dart';
import '../../../../core/bloc/form_status.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/usecases/update_server_address.dart';
import '../../domain/usecases/watch_server_address.dart';

part 'server_config_event.dart';
part 'server_config_state.dart';

/// Endereco do servidor: mostra o atual e grava um novo depois de conferir que ha um
/// servidor ParentaLynx respondendo nele.
class ServerConfigBloc extends Bloc<ServerConfigEvent, ServerConfigState> {
  ServerConfigBloc({required this._watchServerAddress, required this._updateServerAddress})
    : super(
        ServerConfigState(
          address: _watchServerAddress.current,
          isConfigured: _watchServerAddress.isConfigured,
        ),
      ) {
    on<ServerConfigSubscriptionRequested>(_onSubscriptionRequested, transformer: restartable());
    on<ServerAddressSubmitted>(_onSubmitted, transformer: droppable());
  }

  final WatchServerAddress _watchServerAddress;
  final UpdateServerAddress _updateServerAddress;

  Future<void> _onSubscriptionRequested(
    ServerConfigSubscriptionRequested event,
    Emitter<ServerConfigState> emit,
  ) {
    return emit.forEach<String>(
      _watchServerAddress(),
      onData: (String address) =>
          state.copyWith(address: address, isConfigured: _watchServerAddress.isConfigured),
    );
  }

  Future<void> _onSubmitted(ServerAddressSubmitted event, Emitter<ServerConfigState> emit) async {
    emit(state.copyWith(status: FormStatus.submitting, clearError: true));
    final Result<void> result = await _updateServerAddress(event.url);
    switch (result) {
      case Ok<void>():
        emit(
          state.copyWith(
            status: FormStatus.succeeded,
            address: _watchServerAddress.current,
            isConfigured: _watchServerAddress.isConfigured,
          ),
        );
      case Err<void>(:final AppFailure failure):
        emit(state.copyWith(status: FormStatus.editing, error: _messageFor(failure)));
    }
  }

  static String _messageFor(AppFailure failure) {
    if (failure is ValidationFailure) {
      return failure.message;
    }
    return 'Não foi possível falar com o servidor nesse endereço. ${failure.message}';
  }
}
