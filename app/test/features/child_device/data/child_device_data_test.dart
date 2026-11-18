import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/child_device/data/dto/child_device_dto.dart';
import 'package:parentalynx/features/child_device/data/mappers/child_device_mapper.dart';
import 'package:parentalynx/features/child_device/domain/entities/child_device.dart';
import 'package:parentalynx/features/child_device/domain/repositories/i_child_device_repository.dart';

import '../../../support/fake_backend.dart';
import '../../../support/test_dependencies.dart';
import '../support/device_fixtures.dart';

ChildDevice parse(Map<String, Object?> json) {
  return ChildDeviceMapper.device(ChildDeviceDto.fromJson(JsonMap(json)));
}

void main() {
  group('ChildDeviceMapper', () {
    test('le um aparelho ativo com estado', () {
      final ChildDevice device = parse(deviceJson(state: stateJson));

      expect(device.status, DeviceLinkStatus.active);
      expect(device.displayName, 'João');
      expect(device.hardwareLabel, 'motorola moto g54, Android 14');
      expect(device.managementMode, DeviceManagementMode.deviceOwner);
      expect(device.managementMode.isSystemEnforced, isTrue);
      expect(device.policyPending, isFalse);
      expect(device.policySync.appliedAt, 2500);
      expect(device.pendingTimeRequests, 1);

      final DeviceSnapshot snapshot = device.snapshot!;
      expect(snapshot.usedFraction, closeTo(0.6, 0.0001));
      expect(snapshot.lockState, DeviceLockState.schedule);
      expect(snapshot.lockState.isLocked, isTrue);
      expect(snapshot.lockReleaseAt, 9999);
      expect(snapshot.permissions.accessibility, isFalse);
      expect(snapshot.issues, <String>['accessibility_disabled']);
      expect(snapshot.isDegraded, isTrue);
    });

    test('aparelho pendente sem estado e sem nome de crianca', () {
      final ChildDevice device = parse(<String, Object?>{
        ...deviceJson(status: 'pending', childName: ''),
        'confirmCode': '4821',
        'relink': true,
        'managementMode': 'standard',
      });

      expect(device.status, DeviceLinkStatus.pending);
      expect(device.isPending, isTrue);
      expect(device.confirmCode, '4821');
      expect(device.relink, isTrue);
      expect(device.snapshot, isNull);
      expect(device.displayName, 'Moto G de João');
      expect(device.managementMode.isSystemEnforced, isFalse);
    });

    test('politica pendente quando a versao aplicada e menor', () {
      expect(parse(deviceJson(policyVersion: 5, appliedPolicyVersion: 4)).policyPending, isTrue);
    });

    test('sem limite a fracao usada e zero', () {
      final Map<String, Object?> withoutLimit = <String, Object?>{...stateJson}..['limitMs'] = null;
      expect(parse(deviceJson(state: withoutLimit)).snapshot!.usedFraction, 0);
    });

    test('valores desconhecidos caem no padrao', () {
      expect(ChildDeviceMapper.managementMode('outro'), DeviceManagementMode.standard);
      expect(ChildDeviceMapper.lockState(null), DeviceLockState.none);
      expect(ChildDeviceMapper.linkStatus('qualquer'), DeviceLinkStatus.active);
    });

    test('estado sem secao de execucao vale como ativo e sem problemas', () {
      final ChildDevice device = parse(deviceJson(state: const <String, Object?>{'reportedAt': 1}));
      expect(device.snapshot!.enforcementActive, isTrue);
      expect(device.snapshot!.issues, isEmpty);
      expect(device.snapshot!.permissions, DevicePermissions.unknown);
    });
  });

  group('ApiChildDeviceRepository', () {
    late FakeBackend backend;
    late IChildDeviceRepository repository;

    setUp(() {
      backend = FakeBackend();
      final TestDependencies deps = TestDependencies(backend: backend, sessionToken: 'gs_abc');
      addTearDown(deps.dispose);
      repository = deps.di<IChildDeviceRepository>();
    });

    test('lista os aparelhos e guarda a lista para quem observa', () async {
      backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{
        'devices': <Object?>[deviceJson(), deviceJson(id: 'd2', status: 'pending')],
      });
      expect(repository.cachedDevices, isNull);

      final List<ChildDevice> devices = (await repository.refresh()).valueOrNull!;

      expect(devices.map((ChildDevice d) => d.id), <String>['d1', 'd2']);
      expect(repository.cachedDevices, devices);
      expect(await repository.watchDevices().first, devices);
    });

    test('falha ao recarregar mantem a lista anterior', () async {
      backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{
        'devices': <Object?>[deviceJson()],
      });
      await repository.refresh();
      backend.onError('GET', '/v1/guardian/devices', status: 500, code: 'internal');

      final Result<List<ChildDevice>> result = await repository.refresh();

      expect(result.isErr, isTrue);
      expect(repository.cachedDevices!.single.id, 'd1');
    });

    test('upsert troca ou acrescenta um aparelho sem ir ao servidor', () async {
      backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{
        'devices': <Object?>[deviceJson()],
      });
      await repository.refresh();

      repository
        ..upsert(parse(deviceJson(childName: 'Pedro')))
        ..upsert(parse(deviceJson(id: 'd9', childName: 'Ana')));

      expect(repository.cachedDevices!.map((ChildDevice d) => d.childName), <String>[
        'Pedro',
        'Ana',
      ]);
      expect(backend.calls('GET', '/v1/guardian/devices'), hasLength(1));
    });

    test('nome, revogacao, historico, exclusao, codigo offline e exportacao', () async {
      backend
        ..onJson('PATCH', '/v1/guardian/devices/d1', <String, Object?>{
          'device': deviceJson(childName: 'Ana'),
        })
        ..onJson('POST', '/v1/guardian/devices/d1/revoke', <String, Object?>{})
        ..onJson('DELETE', '/v1/guardian/devices/d1/data', <String, Object?>{})
        ..onJson('DELETE', '/v1/guardian/devices/d1', <String, Object?>{})
        ..onJson('GET', '/v1/guardian/devices/d1/offline-secret', <String, Object?>{
          'secret': 'GEZDGNBVGY3TQOJQ',
        })
        ..onJson('GET', '/v1/guardian/devices/d1/export', <String, Object?>{'sessions': 1});

      expect((await repository.rename('d1', childName: 'Ana')).valueOrNull!.childName, 'Ana');
      expect((await repository.revoke('d1')).isOk, isTrue);
      expect((await repository.deleteData('d1')).isOk, isTrue);
      expect((await repository.delete('d1')).isOk, isTrue);
      expect((await repository.offlineSecret('d1')).valueOrNull, 'GEZDGNBVGY3TQOJQ');
      expect((await repository.exportData('d1')).valueOrNull, '{\n  "sessions": 1\n}');

      expect(backend.requests.map((r) => '${r.method} ${r.url.path}'), <String>[
        'PATCH /v1/guardian/devices/d1',
        'POST /v1/guardian/devices/d1/revoke',
        'DELETE /v1/guardian/devices/d1/data',
        'DELETE /v1/guardian/devices/d1',
        'GET /v1/guardian/devices/d1/offline-secret',
        'GET /v1/guardian/devices/d1/export',
      ]);
      expect(backend.lastBody('PATCH', '/v1/guardian/devices/d1'), <String, Object?>{
        'childName': 'Ana',
      });
    });
  });
}
