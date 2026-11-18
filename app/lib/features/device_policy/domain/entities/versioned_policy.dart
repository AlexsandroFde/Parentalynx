import 'package:equatable/equatable.dart';

import 'policy.dart';

/// Politica de um aparelho com a versao que o servidor guarda.
final class VersionedPolicy extends Equatable {
  const VersionedPolicy({required this.version, required this.policy});

  final int version;
  final Policy policy;

  @override
  List<Object?> get props => <Object?>[version, policy];
}
