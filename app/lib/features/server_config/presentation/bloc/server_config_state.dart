part of 'server_config_bloc.dart';

final class ServerConfigState extends Equatable {
  const ServerConfigState({
    required this.address,
    required this.isConfigured,
    this.status = FormStatus.editing,
    this.error,
  });

  /// Endereco em uso.
  final String address;

  /// O endereco atual atende a regra do build (HTTPS em producao).
  final bool isConfigured;
  final FormStatus status;

  /// Motivo da recusa do ultimo endereco informado.
  final String? error;

  ServerConfigState copyWith({
    String? address,
    bool? isConfigured,
    FormStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return ServerConfigState(
      address: address ?? this.address,
      isConfigured: isConfigured ?? this.isConfigured,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => <Object?>[address, isConfigured, status, error];
}
