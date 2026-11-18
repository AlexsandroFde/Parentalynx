import '../../../child_device/domain/entities/child_device.dart';

/// Quantidade de pedidos de tempo aguardando resposta, somando os aparelhos ativos.
///
/// Usada nos selos do painel (aba Alertas, aba Mais).
int countPendingTimeRequests(Iterable<ChildDevice> devices) {
  return devices
      .where((ChildDevice device) => device.isActive)
      .fold<int>(0, (int total, ChildDevice device) => total + device.pendingTimeRequests);
}
