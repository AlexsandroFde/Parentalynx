import 'package:equatable/equatable.dart';

/// Confirmacao de aplicacao das regras em um aparelho.
///
/// O servidor aceitar uma politica nova nao significa que ela vale no aparelho: so vale
/// quando o aparelho confirma a versao aplicada. Enquanto [appliedVersion] e menor que
/// [serverVersion], a politica esta pendente.
final class PolicySyncStatus extends Equatable {
  const PolicySyncStatus({
    required this.serverVersion,
    required this.appliedVersion,
    required this.deviceOnline,
    this.appliedAt,
  });

  /// Ultima versao aceita pelo servidor.
  final int serverVersion;

  /// Ultima versao que o aparelho confirmou ter aplicado.
  final int appliedVersion;

  /// O aparelho esta conectado agora.
  final bool deviceOnline;

  /// Instante da ultima confirmacao do aparelho.
  final int? appliedAt;

  /// Verdadeiro quando ha uma versao ainda nao confirmada pelo aparelho.
  bool get isPending => appliedVersion < serverVersion;

  @override
  List<Object?> get props => <Object?>[serverVersion, appliedVersion, deviceOnline, appliedAt];
}
