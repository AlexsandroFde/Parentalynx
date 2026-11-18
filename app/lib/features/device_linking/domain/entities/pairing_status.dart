import 'package:equatable/equatable.dart';

/// Andamento de um pedido de vinculo feito por este aparelho.
sealed class PairingStatus extends Equatable {
  const PairingStatus();

  @override
  List<Object?> get props => const <Object?>[];
}

/// O responsavel ainda nao respondeu.
final class PairingPending extends PairingStatus {
  const PairingPending();
}

/// O responsavel recusou o aparelho.
final class PairingRejected extends PairingStatus {
  const PairingRejected();
}

/// O pedido venceu ou ja foi entregue a outro aparelho.
final class PairingExpired extends PairingStatus {
  const PairingExpired();
}

/// Vinculo aprovado. As credenciais sao entregues uma unica vez pelo servidor.
final class PairingApproved extends PairingStatus {
  const PairingApproved({
    required this.deviceId,
    required this.deviceToken,
    required this.offlineSecret,
    required this.childName,
    required this.guardianName,
    required this.policyVersion,
    required this.initialPolicy,
  });

  final String deviceId;
  final String deviceToken;
  final String offlineSecret;
  final String childName;
  final String guardianName;
  final int policyVersion;

  /// Politica inicial no formato do protocolo. E repassada ao agente nativo sem leitura: quem
  /// aplica as regras e o agente.
  final String initialPolicy;

  @override
  List<Object?> get props => <Object?>[
    deviceId,
    deviceToken,
    offlineSecret,
    childName,
    guardianName,
    policyVersion,
    initialPolicy,
  ];
}
