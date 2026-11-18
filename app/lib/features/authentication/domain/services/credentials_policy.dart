import '../../../../core/security/password_policy.dart';
import '../entities/credential_errors.dart';

/// Regras de preenchimento dos formularios de conta. Funcoes puras, sem rede.
///
/// Dao retorno imediato antes de enviar ao servidor. O servidor confere de novo (senha forte,
/// e-mail ja usado) e a recusa dele chega como falha da API.
abstract final class CredentialsPolicy {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  /// Tamanho minimo da chave de recuperacao depois de normalizada.
  static const int recoveryKeyMinLength = 10;

  /// Mensagem de erro do e-mail, ou nulo quando parece valido.
  static String? emailError(String value) {
    final String email = value.trim();
    if (email.isEmpty) {
      return 'Informe o e-mail.';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Esse e-mail não parece válido.';
    }
    return null;
  }

  /// Senha administrativa digitada para entrar ou confirmar.
  static String? enteredPasswordError(String password) {
    return password.isEmpty ? 'Digite a senha administrativa.' : null;
  }

  /// Senha nova: precisa atender a politica de senha.
  static String? newPasswordError(String password, {String? email, String? displayName}) {
    final PasswordCheck check = PasswordPolicy.evaluate(
      password,
      email: email,
      displayName: displayName,
    );
    return check.isAcceptable ? null : check.issues.first.message;
  }

  static String? confirmationError(String password, String confirmation) {
    return confirmation == password ? null : 'As senhas não são iguais.';
  }

  /// Deixa a chave de recuperacao no formato que o servidor espera: maiusculas e sem
  /// espacos.
  static String normalizeRecoveryKey(String input) {
    return input.toUpperCase().replaceAll(RegExp(r'\s'), '');
  }

  static CredentialErrors validateLogin({required String email, required String password}) {
    return CredentialErrors(email: emailError(email), password: enteredPasswordError(password));
  }

  static CredentialErrors validateRegistration({
    required String displayName,
    required String email,
    required String password,
    required String confirmation,
  }) {
    return CredentialErrors(
      name: displayName.trim().isEmpty ? 'Informe o seu nome.' : null,
      email: emailError(email),
      password: newPasswordError(password, email: email, displayName: displayName),
      confirmation: confirmationError(password, confirmation),
    );
  }

  static CredentialErrors validateRecovery({
    required String email,
    required String recoveryKey,
    required String password,
    required String confirmation,
  }) {
    return CredentialErrors(
      email: emailError(email),
      recoveryKey: normalizeRecoveryKey(recoveryKey).length < recoveryKeyMinLength
          ? 'Digite a chave de recuperação.'
          : null,
      password: newPasswordError(password, email: email),
      confirmation: confirmationError(password, confirmation),
    );
  }
}
