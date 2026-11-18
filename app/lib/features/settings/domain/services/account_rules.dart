import '../../../authentication/domain/services/credentials_policy.dart';
import '../entities/password_change_errors.dart';

/// Regras de preenchimento das telas de conta. Funcoes puras.
abstract final class AccountRules {
  /// Tamanho maximo do nome de exibicao.
  static const int maxDisplayNameLength = 60;

  /// Palavra que a pessoa digita para confirmar a exclusao da conta.
  static const String deletionWord = 'EXCLUIR';

  /// Mensagem de erro do nome de exibicao, ou nulo quando e aceito.
  static String? displayNameError(String name) {
    final String clean = name.trim();
    if (clean.isEmpty || clean.length > maxDisplayNameLength) {
      return 'Informe um nome com até $maxDisplayNameLength caracteres.';
    }
    return null;
  }

  /// Senha atual digitada para trocar a senha.
  static String? currentPasswordError(String password) {
    return password.isEmpty ? 'Digite a senha atual.' : null;
  }

  /// Confere o formulario de troca de senha antes de enviar ao servidor. A senha nova
  /// precisa atender a politica de senha, considerando o e-mail e o nome da conta.
  static PasswordChangeErrors validatePasswordChange({
    required String current,
    required String next,
    required String confirmation,
    String? email,
    String? displayName,
  }) {
    return PasswordChangeErrors(
      current: currentPasswordError(current),
      next: CredentialsPolicy.newPasswordError(next, email: email, displayName: displayName),
      confirmation: CredentialsPolicy.confirmationError(next, confirmation),
    );
  }

  /// A exclusao so pode ser pedida com a senha e a palavra de confirmacao digitadas.
  static bool canConfirmDeletion({required String password, required String word}) {
    return password.isNotEmpty && word.trim().toUpperCase() == deletionWord;
  }
}
