import 'package:equatable/equatable.dart';

/// Resultado de uma tentativa de autenticacao do responsavel neste aparelho.
enum AdminAuthStatus {
  /// Autenticado. Operacoes administrativas liberadas por alguns minutos.
  ok,

  /// Senha ou codigo incorreto.
  invalid,

  /// Bloqueado por excesso de tentativas.
  locked,

  /// Sem conexao com o servidor (so para senha).
  offline,

  /// Outro erro.
  error,
}

final class AdminAuth extends Equatable {
  const AdminAuth({
    required this.status,
    this.retryAfterSec = 0,
    this.attemptsLeft = -1,
    this.message,
  });

  final AdminAuthStatus status;

  /// Segundos ate poder tentar de novo, quando bloqueado.
  final int retryAfterSec;

  /// Tentativas restantes antes do bloqueio. Negativo quando desconhecido.
  final int attemptsLeft;
  final String? message;

  bool get isGranted => status == AdminAuthStatus.ok;

  @override
  List<Object?> get props => <Object?>[status, retryAfterSec, attemptsLeft, message];
}
