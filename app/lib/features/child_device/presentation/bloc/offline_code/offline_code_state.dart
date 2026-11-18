part of 'offline_code_bloc.dart';

/// Codigo de acesso offline do momento.
final class OfflineCodeState extends Equatable {
  const OfflineCodeState(this.code);

  final OfflineAccessCode code;

  @override
  List<Object?> get props => <Object?>[code];
}
