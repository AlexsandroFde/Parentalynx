import 'guardian_account.dart';

/// Autenticacao e sessao do responsavel (protocolo, secoes 2.4 e 2.5).
///
/// Todas as operacoes lancam `AppFailure` em caso de erro.
abstract interface class AuthRepository {
  Future<AuthResult> register({
    required String email,
    required String displayName,
    required String password,
    required String deviceName,
  });

  Future<AuthResult> login({
    required String email,
    required String password,
    required String deviceName,
  });

  /// Troca a senha usando a chave de recuperacao. Devolve uma sessao nova e uma chave nova.
  Future<AuthResult> recover({
    required String email,
    required String recoveryKey,
    required String newPassword,
    required String deviceName,
  });

  /// Encerra a sessao atual no servidor.
  Future<void> logout();

  /// Conta e sessao atuais.
  Future<GuardianProfile> me();

  /// Confirma a senha administrativa. Devolve o instante ate o qual a sessao fica elevada.
  Future<int> elevate(String password);
}
