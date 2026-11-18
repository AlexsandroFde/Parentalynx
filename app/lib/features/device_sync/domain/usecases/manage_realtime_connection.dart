import '../repositories/i_realtime_repository.dart';

/// Abre e fecha o canal em tempo real e informa o estado da conexao.
///
/// O canal fica aberto enquanto o painel do responsavel estiver aberto.
class ManageRealtimeConnection {
  const ManageRealtimeConnection(this._repository);

  final IRealtimeRepository _repository;

  void open() => _repository.connect();

  Future<void> close() => _repository.disconnect();

  Stream<bool> watchConnection() => _repository.watchConnection();
}
