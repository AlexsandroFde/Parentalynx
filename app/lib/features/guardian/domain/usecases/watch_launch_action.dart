import '../../../../core/navigation/launch_action.dart';

/// Acao pedida por quem abriu o app (notificacao de alerta), seguida das mudancas.
///
/// A acao fica pendente ate o painel trata-la e chamar [consume].
class WatchLaunchAction {
  const WatchLaunchAction(this._source);

  final LaunchActionSource _source;

  Stream<LaunchAction?> call() => _source.watchPending();

  void consume() => _source.consume();
}
