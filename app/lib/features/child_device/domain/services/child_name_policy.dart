/// Regra do nome da crianca mostrado no painel.
abstract final class ChildNamePolicy {
  /// Tamanho maximo aceito.
  static const int maxLength = 40;

  /// Mensagem de erro, ou nulo quando o nome e aceito.
  static String? error(String name) {
    final String clean = name.trim();
    if (clean.isEmpty || clean.length > maxLength) {
      return 'Informe um nome com até $maxLength caracteres.';
    }
    return null;
  }
}
