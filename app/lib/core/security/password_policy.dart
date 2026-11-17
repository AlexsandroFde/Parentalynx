/// Motivos de recusa de uma senha administrativa. Mesmos codigos do protocolo (secao 1.2).
enum PasswordIssue {
  tooShort('too_short', 'Use pelo menos 10 caracteres.'),
  tooLong('too_long', 'Use no máximo 128 caracteres.'),
  fewClasses(
    'few_classes',
    'Misture pelo menos três tipos: minúsculas, maiúsculas, números e símbolos.',
  ),
  containsIdentity('contains_identity', 'Não use seu nome nem seu e-mail na senha.'),
  common('common', 'Essa senha é muito comum. Escolha outra.');

  const PasswordIssue(this.code, this.message);

  final String code;
  final String message;

  static PasswordIssue? fromCode(String code) {
    for (final PasswordIssue issue in values) {
      if (issue.code == code) {
        return issue;
      }
    }
    return null;
  }
}

/// Resultado da avaliacao local de uma senha.
class PasswordCheck {
  const PasswordCheck({required this.issues, required this.strength});

  final List<PasswordIssue> issues;

  /// De 0 (muito fraca) a 4 (forte). So para o indicador visual.
  final int strength;

  bool get isAcceptable => issues.isEmpty;

  String get strengthLabel {
    return switch (strength) {
      0 => 'Muito fraca',
      1 => 'Fraca',
      2 => 'Razoável',
      3 => 'Boa',
      _ => 'Forte',
    };
  }
}

/// Validacao local da senha administrativa, espelhando a regra do servidor.
///
/// O servidor e a autoridade. Esta copia existe para dar retorno imediato enquanto a pessoa
/// digita.
abstract final class PasswordPolicy {
  static const int minLength = 10;
  static const int maxLength = 128;

  static PasswordCheck evaluate(String password, {String? email, String? displayName}) {
    final List<PasswordIssue> issues = <PasswordIssue>[];
    if (password.length < minLength) {
      issues.add(PasswordIssue.tooShort);
    }
    if (password.length > maxLength) {
      issues.add(PasswordIssue.tooLong);
    }
    final int classes = _classCount(password);
    if (classes < 3) {
      issues.add(PasswordIssue.fewClasses);
    }
    if (_containsIdentity(password, email: email, displayName: displayName)) {
      issues.add(PasswordIssue.containsIdentity);
    }
    if (_common.contains(password.toLowerCase())) {
      issues.add(PasswordIssue.common);
    }
    return PasswordCheck(issues: issues, strength: _strength(password, classes, issues));
  }

  static int _classCount(String password) {
    bool lower = false;
    bool upper = false;
    bool digit = false;
    bool symbol = false;
    for (final int rune in password.runes) {
      final String char = String.fromCharCode(rune);
      if (RegExp(r'[0-9]').hasMatch(char)) {
        digit = true;
      } else if (char.toLowerCase() != char.toUpperCase()) {
        if (char == char.toLowerCase()) {
          lower = true;
        } else {
          upper = true;
        }
      } else {
        symbol = true;
      }
    }
    return <bool>[lower, upper, digit, symbol].where((bool present) => present).length;
  }

  static bool _containsIdentity(String password, {String? email, String? displayName}) {
    final String lowered = password.toLowerCase();
    final List<String> parts = <String>[
      if (email != null) email.split('@').first,
      if (displayName != null) ...displayName.split(RegExp(r'\s+')),
    ];
    for (final String part in parts) {
      final String clean = part.trim().toLowerCase();
      if (clean.length >= 4 && lowered.contains(clean)) {
        return true;
      }
    }
    return false;
  }

  static int _strength(String password, int classes, List<PasswordIssue> issues) {
    if (password.isEmpty) {
      return 0;
    }
    if (issues.contains(PasswordIssue.common) || issues.contains(PasswordIssue.containsIdentity)) {
      return 1;
    }
    if (issues.isNotEmpty) {
      return password.length >= 8 && classes >= 2 ? 1 : 0;
    }
    final int unique = password.runes.toSet().length;
    int score = 2;
    if (password.length >= 14) {
      score += 1;
    }
    if (classes == 4 && unique >= 9) {
      score += 1;
    }
    return score.clamp(0, 4);
  }

  /// Senhas comuns que passariam nas outras regras. Comparadas em minusculas.
  static const Set<String> _common = <String>{
    'password123',
    'password1234',
    'password12345',
    'password@123',
    'password123!',
    'p@ssword123',
    'p@ssw0rd123',
    'passw0rd123',
    'senha12345',
    'senha123456',
    'senha@1234',
    'senha@12345',
    'senha123456!',
    'mudar@1234',
    'mudar12345',
    'brasil2024',
    'brasil2025',
    'brasil2026',
    'brasil@123',
    'brasil@2024',
    'brasil@2025',
    'brasil@2026',
    'qwerty12345',
    'qwerty123456',
    'qwerty@123',
    'qwertyuiop1',
    '1q2w3e4r5t',
    '1q2w3e4r5t6y',
    '1qaz2wsx3edc',
    'abc1234567',
    'abcd123456',
    'abcd@1234',
    'abc@123456',
    'admin12345',
    'admin@1234',
    'admin@12345',
    'welcome123',
    'welcome@123',
    'iloveyou123',
    'teamo12345',
    'flamengo123',
    'corinthians1',
    'palmeiras123',
    'familia123',
    'familia@123',
    'parentalynx1',
    'parentalynx@1',
    'controle123',
    'controle@123',
  };
}
