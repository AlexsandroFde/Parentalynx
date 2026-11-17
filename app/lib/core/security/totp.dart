import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Algoritmo de resumo do TOTP.
enum TotpAlgorithm { sha1, sha256 }

/// Codigo de acesso offline do responsavel (protocolo, secao 3.4): TOTP da RFC 6238.
///
/// O padrao do ParentaLynx e HMAC-SHA256, 8 digitos e passo de 60 segundos. Os parametros sao
/// configuraveis para permitir o teste com os vetores oficiais da RFC.
class Totp {
  const Totp({this.algorithm = TotpAlgorithm.sha256, this.digits = 8, this.stepSeconds = 60});

  final TotpAlgorithm algorithm;
  final int digits;
  final int stepSeconds;

  /// Codigo valido no instante [timeMs] para o segredo em Base32.
  String generate(String base32Secret, int timeMs) {
    return generateFromBytes(decodeBase32(base32Secret), timeMs);
  }

  String generateFromBytes(List<int> secret, int timeMs) {
    final int counter = timeMs ~/ 1000 ~/ stepSeconds;
    final ByteData message = ByteData(8)..setUint64(0, counter);
    final Hash hash = algorithm == TotpAlgorithm.sha1 ? sha1 : sha256;
    final List<int> mac = Hmac(hash, secret).convert(message.buffer.asUint8List()).bytes;
    final int offset = mac[mac.length - 1] & 0x0f;
    final int binary =
        ((mac[offset] & 0x7f) << 24) |
        ((mac[offset + 1] & 0xff) << 16) |
        ((mac[offset + 2] & 0xff) << 8) |
        (mac[offset + 3] & 0xff);
    int modulo = 1;
    for (int i = 0; i < digits; i++) {
      modulo *= 10;
    }
    return (binary % modulo).toString().padLeft(digits, '0');
  }

  /// Segundos que faltam para o codigo atual mudar.
  int secondsRemaining(int timeMs) => stepSeconds - (timeMs ~/ 1000) % stepSeconds;

  /// Decodifica Base32 (RFC 4648), com ou sem preenchimento, ignorando espacos e caixa.
  static Uint8List decodeBase32(String input) {
    const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final String clean = input.toUpperCase().replaceAll(RegExp(r'[\s=-]'), '');
    final BytesBuilder out = BytesBuilder();
    int buffer = 0;
    int bits = 0;
    for (int i = 0; i < clean.length; i++) {
      final int value = alphabet.indexOf(clean[i]);
      if (value < 0) {
        throw FormatException('Caractere invalido em Base32: ${clean[i]}');
      }
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.addByte((buffer >> bits) & 0xff);
      }
    }
    return out.toBytes();
  }
}
