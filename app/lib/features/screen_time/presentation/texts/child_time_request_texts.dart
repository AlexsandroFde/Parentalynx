import '../../../../core/time/formatters.dart';
import '../../domain/entities/child_time_request.dart';

/// Textos dos pedidos de tempo mostrados a crianca.

/// Estado de um pedido, em linguagem simples.
String childTimeRequestStatusText(ChildTimeRequest request) {
  switch (request.status) {
    case ChildTimeRequestStatus.pending:
      return request.delivered ? 'Esperando a resposta' : 'Esperando conexão para enviar';
    case ChildTimeRequestStatus.approved:
      final int? granted = request.grantedMinutes;
      return granted == null ? 'Aprovado' : 'Aprovado: mais ${formatMinutes(granted)}';
    case ChildTimeRequestStatus.denied:
      return 'Não aprovado desta vez';
    case ChildTimeRequestStatus.expired:
      return 'Ficou sem resposta';
  }
}

/// O que foi pedido: `Mais 30min` ou "Mais tempo".
String childTimeRequestAmount(ChildTimeRequest request) {
  final int? minutes = request.minutes;
  return minutes == null ? 'Mais tempo' : 'Mais ${formatMinutes(minutes)}';
}
