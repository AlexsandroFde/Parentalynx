import '../entities/realtime_update.dart';
import '../repositories/i_realtime_repository.dart';

/// Avisos em tempo real, para quem precisa recarregar dados quando algo muda no servidor
/// (lista de aparelhos, alertas, pedidos de tempo, vinculacao).
class WatchRealtimeUpdates {
  const WatchRealtimeUpdates(this._repository);

  final IRealtimeRepository _repository;

  Stream<RealtimeUpdate> call() => _repository.updates;

  /// So os avisos que mudam a lista ou o estado dos aparelhos.
  Stream<RealtimeUpdate> affectingDevices() {
    return _repository.updates.where((RealtimeUpdate update) => update.affectsDevices);
  }
}
