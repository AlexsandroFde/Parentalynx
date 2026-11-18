import '../../../../core/result/result.dart';
import '../entities/guardian_session.dart';

/// Operacoes de conta no servidor (protocolo, secoes 2.4 e 2.5).
abstract interface class IAuthRepository {
  Future<Result<AuthenticatedSession>> register({
    required String email,
    required String displayName,
    required String password,
    required String deviceName,
  });

  Future<Result<AuthenticatedSession>> login({
    required String email,
    required String password,
    required String deviceName,
  });

  /// Troca a senha usando a chave de recuperacao. Devolve uma sessao nova e uma chave nova.
  Future<Result<AuthenticatedSession>> recover({
    required String email,
    required String recoveryKey,
    required String newPassword,
    required String deviceName,
  });

  /// Encerra a sessao atual no servidor.
  Future<Result<void>> logout();

  /// Conta e sessao atuais.
  Future<Result<GuardianProfile>> fetchProfile();

  /// Confirma a senha administrativa. Devolve o instante ate o qual a sessao fica elevada.
  ///
  /// Senha errada falha com `ApiFailure` de codigo `invalid_credentials`; excesso de
  /// tentativas, com `account_locked`.
  Future<Result<int>> elevate(String password);
}
