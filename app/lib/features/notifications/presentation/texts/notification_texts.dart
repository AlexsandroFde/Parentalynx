import '../../../child_device/domain/entities/child_device.dart';

/// Texto unico sobre a entrega dos alertas, usado em mais de uma tela para nao prometer mais
/// do que o app entrega.
const String alertDeliveryNote =
    'Com o app aberto, os alertas chegam na hora. Com o app fechado, o aparelho busca novos '
    'alertas em segundo plano e eles podem levar até cerca de 15 minutos para aparecer.';

/// Pedidos de tempo aguardando resposta, somando os aparelhos ativos.
int pendingTimeRequestsOf(List<ChildDevice> activeDevices) {
  return activeDevices.fold<int>(
    0,
    (int total, ChildDevice device) => total + device.pendingTimeRequests,
  );
}
