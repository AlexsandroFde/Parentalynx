import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../domain/usecases/get_app_version.dart';

part 'more_event.dart';
part 'more_state.dart';

/// Dados da aba Mais que nao vem da sessao nem dos aparelhos: o servidor em uso (fixo no
/// codigo) e a versao instalada do app.
class MoreBloc extends Bloc<MoreEvent, MoreState> {
  MoreBloc({required String serverAddress, required this._getAppVersion})
    : super(MoreState(serverAddress: serverAddress)) {
    on<MoreStarted>(_onStarted, transformer: restartable());
  }

  final GetAppVersion _getAppVersion;

  Future<void> _onStarted(MoreStarted event, Emitter<MoreState> emit) async {
    final String? version = await _getAppVersion();
    if (version != null && !emit.isDone) {
      emit(state.copyWith(appVersion: version));
    }
  }
}
