import 'package:equatable/equatable.dart';

/// O que o agente nativo recebe para passar a controlar este aparelho, depois que o
/// responsavel aprova o vinculo.
final class DeviceActivation extends Equatable {
  const DeviceActivation({
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

  /// Segredo do codigo de acesso offline do responsavel.
  final String offlineSecret;
  final String childName;
  final String guardianName;
  final int policyVersion;

  /// Politica inicial no formato do protocolo.
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
