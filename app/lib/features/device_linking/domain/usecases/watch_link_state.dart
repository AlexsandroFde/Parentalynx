import '../entities/link_state.dart';
import '../repositories/i_link_state_repository.dart';

/// Situacao do vinculo seguida das mudancas, para quem escolhe a tela do modo crianca.
class WatchLinkState {
  const WatchLinkState(this._repository);

  final ILinkStateRepository _repository;

  LinkState get current => _repository.current;

  Stream<LinkState> call() => _repository.watch();
}
