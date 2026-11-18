import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/blocking/domain/entities/system_lock.dart';
import 'package:parentalynx/features/blocking/domain/services/web_policy_editing.dart';
import 'package:parentalynx/features/child_device/domain/entities/child_device.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';

String? _problem(Result<String> result) {
  return switch (result) {
    Ok<String>() => null,
    Err<String>(:final AppFailure failure) => failure.message,
  };
}

void main() {
  group('listas de sites', () {
    test('endereco digitado vira dominio limpo', () {
      final Result<String> result = WebPolicyEditing.validateNewDomain(
        const <String>[],
        'https://www.Exemplo.com.br/pagina',
      );
      expect(result.valueOrNull, 'exemplo.com.br');
    });

    test('endereco invalido, repetido ou lista cheia explicam o que corrigir', () {
      expect(
        _problem(WebPolicyEditing.validateNewDomain(const <String>[], 'nao e site')),
        'Digite um endereço válido, por exemplo exemplo.com.br',
      );
      expect(
        _problem(WebPolicyEditing.validateNewDomain(const <String>['jogos.com'], 'jogos.com')),
        'Esse site já está na lista.',
      );
      final List<String> full = <String>[
        for (int i = 0; i < WebPolicyEditing.maxDomains; i++) 'site$i.com',
      ];
      expect(
        _problem(WebPolicyEditing.validateNewDomain(full, 'novo.com')),
        'A lista chegou ao limite de 500 sites.',
      );
    });

    test('acrescentar e remover usam a lista escolhida, sem repetir', () {
      WebPolicy web = const WebPolicy();
      web = WebPolicyEditing.addDomain(web, WebDomainList.allowed, 'escola.com');
      web = WebPolicyEditing.addDomain(web, WebDomainList.allowed, 'escola.com');
      web = WebPolicyEditing.addDomain(web, WebDomainList.blocked, 'jogos.com');
      expect(web.allowedDomains, <String>['escola.com']);
      expect(web.blockedDomains, <String>['jogos.com']);

      web = WebPolicyEditing.removeDomain(web, WebDomainList.allowed, 'escola.com');
      expect(web.allowedDomains, isEmpty);
      expect(WebDomainList.blocked.read(web), <String>['jogos.com']);
    });

    test('categorias bloqueadas sem repeticao', () {
      final WebCategory category = WebCategory.values.first;
      WebPolicy web = const WebPolicy(blockedCategories: <String>[]);
      web = WebPolicyEditing.withCategory(web, category, blocked: true);
      web = WebPolicyEditing.withCategory(web, category, blocked: true);
      expect(web.blockedCategories, <String>[category.code]);
      web = WebPolicyEditing.withCategory(web, category, blocked: false);
      expect(web.blockedCategories, isEmpty);
    });
  });

  group('travas do sistema', () {
    test('so o modo dispositivo gerenciado aplica as travas', () {
      expect(SystemLock.availableIn(DeviceManagementMode.deviceOwner), isTrue);
      expect(SystemLock.availableIn(DeviceManagementMode.deviceAdmin), isFalse);
      expect(SystemLock.availableIn(DeviceManagementMode.standard), isFalse);
    });

    test('ligar e contar cada trava', () {
      ProtectionPolicy protection = const ProtectionPolicy();
      final int before = SystemLock.countEnabled(protection);
      for (final SystemLock lock in SystemLock.values) {
        protection = lock.apply(protection, true);
        expect(lock.valueIn(protection), isTrue);
      }
      expect(SystemLock.countEnabled(protection), SystemLock.values.length);
      protection = SystemLock.usbDebugging.apply(protection, false);
      expect(SystemLock.countEnabled(protection), SystemLock.values.length - 1);
      expect(before, lessThan(SystemLock.values.length));
    });
  });
}
