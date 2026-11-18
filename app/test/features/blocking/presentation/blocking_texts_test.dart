import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/features/blocking/presentation/texts/blocking_texts.dart';
import 'package:parentalynx/features/child_device/domain/entities/child_device.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';

void main() {
  group('resumos', () {
    test('web e protecao', () {
      expect(webSummary(const WebPolicy(managedBrowser: false)), 'Navegador ParentaLynx desligado');
      expect(
        webSummary(const WebPolicy(mode: WebMode.allowlist, allowedDomains: <String>['a.com'])),
        'Só 1 site autorizado',
      );
      expect(webSummary(const WebPolicy()), 'Bloqueia: 2 categorias, filtro familiar');
      expect(
        protectionSummary(const ProtectionPolicy(), DeviceManagementMode.standard),
        'Só avisa se a proteção for desativada',
      );
      expect(
        protectionSummary(const ProtectionPolicy(), DeviceManagementMode.deviceOwner),
        contains('5 de 7 travas'),
      );
    });

    test('garantias de cada modo', () {
      for (final DeviceManagementMode mode in DeviceManagementMode.values) {
        final ({List<String> guaranteed, List<String> notGuaranteed}) texts = guaranteesOf(mode);
        expect(texts.guaranteed, isNotEmpty);
        expect(texts.notGuaranteed, isNotEmpty);
      }
      expect(
        guaranteesOf(DeviceManagementMode.deviceOwner).guaranteed,
        contains('A desinstalação e o modo de segurança podem ser impedidos.'),
      );
    });
  });
}
