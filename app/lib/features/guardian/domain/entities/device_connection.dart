import '../../../child_device/domain/entities/child_device.dart';

/// Situacao da conexao de um aparelho, como o painel destaca.
enum DeviceConnection {
  /// Conectado agora.
  online,

  /// Nunca sincronizou desde o vinculo.
  neverSynced,

  /// Desconectado, mas sincronizou ha pouco.
  recent,

  /// Desconectado ha mais de [staleAfter]: merece atencao.
  stale;

  /// Tempo sem sincronizar a partir do qual a conexao merece atencao.
  static const Duration staleAfter = Duration(hours: 3);

  static DeviceConnection of(ChildDevice device, {required int nowMs}) {
    if (device.online) {
      return DeviceConnection.online;
    }
    final int? lastSync = device.lastSyncAt;
    if (lastSync == null) {
      return DeviceConnection.neverSynced;
    }
    return nowMs - lastSync > staleAfter.inMilliseconds
        ? DeviceConnection.stale
        : DeviceConnection.recent;
  }
}
