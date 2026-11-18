part of 'more_bloc.dart';

final class MoreState extends Equatable {
  const MoreState({required this.serverAddress, this.appVersion});

  /// Endereco do servidor em uso. Vazio quando nao foi configurado.
  final String serverAddress;

  /// Versao instalada do app, quando o sistema informa.
  final String? appVersion;

  MoreState copyWith({String? serverAddress, String? appVersion}) {
    return MoreState(
      serverAddress: serverAddress ?? this.serverAddress,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  @override
  List<Object?> get props => <Object?>[serverAddress, appVersion];
}
