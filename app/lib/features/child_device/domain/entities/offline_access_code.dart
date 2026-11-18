import 'package:equatable/equatable.dart';

/// Codigo de acesso offline valido agora e quanto tempo ele ainda vale.
final class OfflineAccessCode extends Equatable {
  const OfflineAccessCode({required this.code, required this.secondsRemaining});

  /// Oito digitos, ou vazio quando o segredo nao pode ser lido.
  final String code;
  final int secondsRemaining;

  bool get isValid => code.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[code, secondsRemaining];
}
