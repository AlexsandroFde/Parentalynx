import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/security/pairing_code.dart';
import 'package:parentalynx/core/security/password_policy.dart';
import 'package:parentalynx/core/security/totp.dart';

void main() {
  group('PasswordPolicy', () {
    test('aceita senha longa com tres classes', () {
      final PasswordCheck check = PasswordPolicy.evaluate('Girassol-azul-42');
      expect(check.isAcceptable, isTrue);
      expect(check.strength, greaterThanOrEqualTo(3));
    });

    test('recusa senha curta', () {
      final PasswordCheck check = PasswordPolicy.evaluate('Ab1!xyz');
      expect(check.issues, contains(PasswordIssue.tooShort));
    });

    test('recusa senha com menos de tres classes', () {
      final PasswordCheck check = PasswordPolicy.evaluate('somenteletrasminusculas');
      expect(check.issues, contains(PasswordIssue.fewClasses));
      expect(check.issues, isNot(contains(PasswordIssue.tooShort)));
    });

    test('recusa senha que contem o e-mail ou o nome', () {
      expect(
        PasswordPolicy.evaluate('Maria#Segura99', displayName: 'Maria Silva').issues,
        contains(PasswordIssue.containsIdentity),
      );
      expect(
        PasswordPolicy.evaluate('carlos.souza#2026X', email: 'carlos.souza@exemplo.com').issues,
        contains(PasswordIssue.containsIdentity),
      );
    });

    test('ignora trechos de identidade com menos de quatro caracteres', () {
      final PasswordCheck check = PasswordPolicy.evaluate('Ana#Segura9912', displayName: 'Ana');
      expect(check.issues, isNot(contains(PasswordIssue.containsIdentity)));
    });

    test('recusa senha comum sem distinguir caixa', () {
      expect(PasswordPolicy.evaluate('Senha@12345').issues, contains(PasswordIssue.common));
      expect(PasswordPolicy.evaluate('Password123!').issues, contains(PasswordIssue.common));
    });

    test('recusa senha acima do tamanho maximo', () {
      final String long = 'Aa1!${'x' * 130}';
      expect(PasswordPolicy.evaluate(long).issues, contains(PasswordIssue.tooLong));
    });

    test('converte os codigos do servidor', () {
      expect(PasswordIssue.fromCode('few_classes'), PasswordIssue.fewClasses);
      expect(PasswordIssue.fromCode('desconhecido'), isNull);
    });
  });

  group('Totp', () {
    // Vetores do apendice B da RFC 6238 (8 digitos, passo de 30 segundos).
    final List<int> seedSha1 = ascii.encode('12345678901234567890');
    final List<int> seedSha256 = ascii.encode('12345678901234567890123456789012');
    const Totp sha1 = Totp(algorithm: TotpAlgorithm.sha1, stepSeconds: 30);
    const Totp sha256 = Totp(stepSeconds: 30);

    const Map<int, List<String>> vectors = <int, List<String>>{
      59: <String>['94287082', '46119246'],
      1111111109: <String>['07081804', '68084774'],
      1111111111: <String>['14050471', '67062674'],
      1234567890: <String>['89005924', '91819424'],
      2000000000: <String>['69279037', '90698825'],
      20000000000: <String>['65353130', '77737706'],
    };

    for (final MapEntry<int, List<String>> vector in vectors.entries) {
      test('vetor da RFC no instante ${vector.key}', () {
        expect(sha1.generateFromBytes(seedSha1, vector.key * 1000), vector.value[0]);
        expect(sha256.generateFromBytes(seedSha256, vector.key * 1000), vector.value[1]);
      });
    }

    test('decodifica Base32 com e sem preenchimento', () {
      expect(utf8.decode(Totp.decodeBase32('MZXW6YTBOI======')), 'foobar');
      expect(utf8.decode(Totp.decodeBase32('mzxw 6ytb oi')), 'foobar');
    });

    test('recusa caractere fora do alfabeto Base32', () {
      expect(() => Totp.decodeBase32('MZXW1'), throwsFormatException);
    });

    test('o padrao do app usa passo de 60 segundos e 8 digitos', () {
      const Totp totp = Totp();
      const String secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
      final String first = totp.generate(secret, 120000);
      expect(first, hasLength(8));
      expect(totp.generate(secret, 179999), first);
      expect(totp.generate(secret, 180000), isNot(first));
      expect(totp.secondsRemaining(150000), 30);
    });
  });

  group('PairingCode', () {
    test('normaliza caixa, separadores e letras ambiguas', () {
      expect(PairingCode.normalize('ab2d-9xyz'), 'AB2D9XYZ');
      expect(PairingCode.normalize(' a b 2 d 9 x y z '), 'AB2D9XYZ');
      expect(PairingCode.normalize('O0I1L1AB'), '001111AB');
    });

    test('descarta caracteres fora do alfabeto e o excedente', () {
      expect(PairingCode.normalize('AB#2D9XYZU'), 'AB2D9XYZ');
      expect(PairingCode.normalize('AB2D9XYZ7777'), 'AB2D9XYZ');
    });

    test('formata com hifen e reconhece codigo completo', () {
      expect(PairingCode.format('ab2d9xyz'), 'AB2D-9XYZ');
      expect(PairingCode.format('ab2'), 'AB2');
      expect(PairingCode.isComplete('AB2D-9XYZ'), isTrue);
      expect(PairingCode.isComplete('AB2D-9XY'), isFalse);
    });
  });
}
