/// Codigo de vinculacao (protocolo, secao 3.3): 8 caracteres de um alfabeto sem letras
/// ambiguas, exibido como `XXXX-XXXX`.
abstract final class PairingCode {
  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const int length = 8;

  /// Normaliza o que a pessoa digitou: maiusculas, sem espacos e hifens, `O` vira `0`, `I` e
  /// `L` viram `1`. Caracteres fora do alfabeto sao descartados.
  static String normalize(String input) {
    final StringBuffer out = StringBuffer();
    for (final int rune in input.toUpperCase().runes) {
      String char = String.fromCharCode(rune);
      if (char == 'O') {
        char = '0';
      } else if (char == 'I' || char == 'L') {
        char = '1';
      }
      if (alphabet.contains(char)) {
        out.write(char);
      }
    }
    final String clean = out.toString();
    return clean.length > length ? clean.substring(0, length) : clean;
  }

  static bool isComplete(String input) => normalize(input).length == length;

  /// Formata para exibicao: `ABCD-2345`. Entrada parcial e formatada ate onde foi digitada.
  static String format(String input) {
    final String clean = normalize(input);
    if (clean.length <= 4) {
      return clean;
    }
    return '${clean.substring(0, 4)}-${clean.substring(4)}';
  }
}
