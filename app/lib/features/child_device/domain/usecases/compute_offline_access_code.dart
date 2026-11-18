import '../../../../core/security/totp.dart';
import '../entities/offline_access_code.dart';

/// Calcula o codigo de acesso offline (TOTP da RFC 6238, HMAC-SHA256, 8 digitos, 60 s).
class ComputeOfflineAccessCode {
  const ComputeOfflineAccessCode([this._totp = const Totp()]);

  final Totp _totp;

  OfflineAccessCode call(String secret, int nowMs) {
    String code;
    try {
      code = _totp.generate(secret, nowMs);
    } on FormatException {
      code = '';
    }
    return OfflineAccessCode(code: code, secondsRemaining: _totp.secondsRemaining(nowMs));
  }
}
