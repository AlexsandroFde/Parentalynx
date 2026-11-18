import 'package:equatable/equatable.dart';

/// Andamento de um pedido de tempo feito pela crianca.
enum ChildTimeRequestStatus { pending, approved, denied, expired }

/// Pedido de tempo adicional feito neste aparelho (modo crianca).
///
/// O pedido fica na fila do agente nativo ate chegar ao servidor: funciona sem internet e e
/// enviado depois.
final class ChildTimeRequest extends Equatable {
  const ChildTimeRequest({
    required this.id,
    required this.createdAtMs,
    required this.status,
    required this.delivered,
    this.minutes,
    this.message,
    this.grantedMinutes,
  });

  final String id;
  final int createdAtMs;
  final int? minutes;
  final String? message;
  final ChildTimeRequestStatus status;
  final int? grantedMinutes;

  /// Verdadeiro quando o pedido ja chegou ao servidor.
  final bool delivered;

  @override
  List<Object?> get props => <Object?>[
    id,
    createdAtMs,
    minutes,
    message,
    status,
    grantedMinutes,
    delivered,
  ];
}
