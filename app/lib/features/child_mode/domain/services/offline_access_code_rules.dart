/// Regras do codigo de acesso offline digitado na area do responsavel.
library;

/// Quantidade de digitos do codigo de acesso offline.
const int offlineCodeLength = 8;

/// Deixa so os digitos do codigo de acesso offline, que tem [offlineCodeLength].
String normalizeOfflineCode(String input) {
  final String digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length > offlineCodeLength ? digits.substring(0, offlineCodeLength) : digits;
}
