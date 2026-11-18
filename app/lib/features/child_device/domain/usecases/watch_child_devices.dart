import '../entities/child_device.dart';
import '../repositories/i_child_device_repository.dart';

/// Lista de aparelhos da conta (pendentes, ativos e revogados) seguida das mudancas.
class WatchChildDevices {
  const WatchChildDevices(this._repository);

  final IChildDeviceRepository _repository;

  List<ChildDevice>? get cached => _repository.cachedDevices;

  Stream<List<ChildDevice>> call() => _repository.watchDevices();

  /// Um aparelho da lista, seguido das mudancas. Nulo quando sai da lista.
  Stream<ChildDevice?> device(String deviceId) {
    return _repository.watchDevices().map((List<ChildDevice> devices) {
      for (final ChildDevice device in devices) {
        if (device.id == deviceId) {
          return device;
        }
      }
      return null;
    }).distinct();
  }
}
