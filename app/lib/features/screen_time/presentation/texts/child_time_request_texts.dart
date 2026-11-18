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

/// Titulo do pedido na tela inicial: `Pedido de 30min`.
String childTimeRequestTitle(ChildTimeRequest request) {
  final int? minutes = request.minutes;
  return minutes == null ? 'Pedido de mais tempo' : 'Pedido de ${formatMinutes(minutes)}';
}

/// Quando o pedido foi feito, ou que ele ainda espera a internet para sair do aparelho.
///
/// [now] e a hora do agente, para o tempo relativo nao depender do relogio do aparelho.
String childTimeRequestDetail(ChildTimeRequest request, {required DateTime now}) {
  if (request.status == ChildTimeRequestStatus.pending && !request.delivered) {
    return 'Guardado no aparelho. Ele vai assim que houver internet.';
  }
  return 'Enviado ${formatRelativeMs(request.createdAtMs, now: now)}.';
}

/// Aviso na folha de pedido quando ja ha um pedido sem resposta.
String pendingRequestNotice(ChildTimeRequest request, {required String guardian, DateTime? now}) {
  final int? minutes = request.minutes;
  final String amount = minutes == null ? 'mais tempo' : formatMinutes(minutes);
  final String when = formatRelativeMs(request.createdAtMs, now: now);
  return 'Você já pediu $amount $when e a resposta ainda não chegou. Se mandar outro pedido, '
      '$guardian recebe os dois.';
}
