import 'package:bloc/bloc.dart';

import '../logging/app_logger.dart';

/// Observa todos os BLoCs do app e registra erros e mudancas de estado de forma estruturada.
///
/// So o tipo do BLoC, do evento e do estado e registrado, nunca o conteudo, para nao levar
/// dados pessoais para o log.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver(this._logger, {this.logTransitions = false});

  final AppLogger _logger;

  /// Registra cada transicao em nivel de depuracao. Ligado so em build de depuracao.
  final bool logTransitions;

  @override
  void onTransition(Bloc<dynamic, dynamic> bloc, Transition<dynamic, dynamic> transition) {
    super.onTransition(bloc, transition);
    if (!logTransitions) {
      return;
    }
    _logger.debug('bloc_transition', <String, Object?>{
      'bloc': bloc.runtimeType.toString(),
      'event': transition.event.runtimeType.toString(),
      'from': transition.currentState.runtimeType.toString(),
      'to': transition.nextState.runtimeType.toString(),
    });
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _logger.error(
      'bloc_error',
      fields: <String, Object?>{'bloc': bloc.runtimeType.toString()},
      error: error,
      stackTrace: stackTrace,
    );
    super.onError(bloc, error, stackTrace);
  }
}
