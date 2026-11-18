import '../../../../core/navigation/launch_action.dart';

/// Acao pedida por quem abriu o app no modo crianca (tela de bloqueio nativa, notificacao do
/// controle), seguida das mudancas.
///
/// A acao fica pendente ate a area da crianca trata-la e chamar [consume].
class WatchChildLaunchAction {
  const WatchChildLaunchAction(this._source);

  final LaunchActionSource _source;

  Stream<LaunchAction?> call() => _source.watchPending();

  void consume() => _source.consume();
}
