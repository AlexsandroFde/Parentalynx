import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../server_config/domain/usecases/watch_server_address.dart';
import '../../../domain/usecases/get_app_version.dart';

part 'more_event.dart';
part 'more_state.dart';

/// Dados da aba Mais que nao vem da sessao nem dos aparelhos: o servidor em uso e a versao
/// instalada do app.
class MoreBloc extends Bloc<MoreEvent, MoreState> {
  MoreBloc({required this._watchServerAddress, required this._getAppVersion})
    : super(MoreState(serverAddress: _watchServerAddress.current)) {
    on<MoreStarted>(_onStarted, transformer: restartable());
  }

  final WatchServerAddress _watchServerAddress;
  final GetAppVersion _getAppVersion;

  Future<void> _onStarted(MoreStarted event, Emitter<MoreState> emit) async {
    await Future.wait(<Future<void>>[
      _loadVersion(emit),
      emit.forEach<String>(
        _watchServerAddress(),
        onData: (String address) => state.copyWith(serverAddress: address),
      ),
    ]);
  }

  Future<void> _loadVersion(Emitter<MoreState> emit) async {
    final String? version = await _getAppVersion();
    if (version != null && !emit.isDone) {
      emit(state.copyWith(appVersion: version));
    }
  }
}
