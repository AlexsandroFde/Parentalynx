import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/core/network/api_client.dart';
import 'package:parentalynx/core/network/network_providers.dart';
import 'package:parentalynx/features/guardian/devices/data/devices_repository.dart';
import 'package:parentalynx/features/guardian/devices/domain/device.dart';
import 'package:parentalynx/features/guardian/devices/presentation/devices_providers.dart';
import 'package:parentalynx/shared/domain/policy.dart';

import '../support/test_app.dart';

Map<String, Object?> deviceJson({
  String id = 'd1',
  String status = 'active',
  String childName = 'João',
  int policyVersion = 3,
  int appliedPolicyVersion = 3,
  Map<String, Object?>? state,
}) {
  return <String, Object?>{
    'id': id,
    'status': status,
    'childName': childName,
    'deviceName': 'Moto G de João',
    'model': 'moto g54',
    'manufacturer': 'motorola',
    'androidRelease': '14',
    'sdkInt': 34,
    'appVersion': '1.0.0',
    'timezone': 'America/Fortaleza',
    'createdAt': 1000,
    'approvedAt': 2000,
    'revokedAt': null,
    'lastSyncAt': 3000,
    'online': true,
    'today': '2026-11-17',
    'managementMode': 'device_owner',
    'policyVersion': policyVersion,
    'appliedPolicyVersion': appliedPolicyVersion,
    'policyAppliedAt': 2500,
    'pendingTimeRequests': 1,
    'state': state,
  };
}

const Map<String, Object?> stateJson = <String, Object?>{
  'reportedAt': 3000,
  'day': '2026-11-17',
  'quotaUsedMs': 5400000,
  'totalUsedMs': 6000000,
  'limitMs': 9000000,
  'extraMs': 0,
  'remainingMs': 3600000,
  'limitReachedAt': null,
  'managementMode': 'device_owner',
  'permissions': <String, Object?>{
    'usageAccess': true,
    'accessibility': false,
    'overlay': false,
    'notifications': true,
    'batteryOptimizationIgnored': true,
    'deviceAdmin': true,
    'exactAlarms': true,
  },
  'enforcement': <String, Object?>{
    'active': true,
    'issues': <String>['accessibility_disabled'],
  },
  'lock': <String, Object?>{'state': 'schedule', 'releaseAt': 9999},
  'foregroundApp': 'com.whatsapp',
  'screenOn': true,
  'batteryPercent': 80,
  'clockTrusted': true,
};

void main() {
  group('Device', () {
    test('le um aparelho ativo com estado', () {
      final Device device = Device.fromJson(JsonMap(deviceJson(state: stateJson)));

      expect(device.status, DeviceStatus.active);
      expect(device.displayName, 'João');
      expect(device.hardwareLabel, 'motorola moto g54, Android 14');
      expect(device.managementMode, DeviceManagementMode.deviceOwner);
      expect(device.managementMode.isSystemEnforced, isTrue);
      expect(device.policyPending, isFalse);
      expect(device.pendingTimeRequests, 1);

      final DeviceState state = device.state!;
      expect(state.usedFraction, closeTo(0.6, 0.0001));
      expect(state.lockState, DeviceLockState.schedule);
      expect(state.lockState.isLocked, isTrue);
      expect(state.lockReleaseAt, 9999);
      expect(state.permissions.accessibility, isFalse);
      expect(state.issues, <String>['accessibility_disabled']);
      expect(state.isDegraded, isTrue);
    });

    test('aparelho pendente sem estado e sem nome de crianca', () {
      final Device device = Device.fromJson(
        JsonMap(<String, Object?>{
          ...deviceJson(status: 'pending', childName: ''),
          'confirmCode': '4821',
          'relink': true,
          'managementMode': 'standard',
        }),
      );

      expect(device.status, DeviceStatus.pending);
      expect(device.confirmCode, '4821');
      expect(device.relink, isTrue);
      expect(device.state, isNull);
      expect(device.displayName, 'Moto G de João');
      expect(device.managementMode.isSystemEnforced, isFalse);
    });

    test('politica pendente quando a versao aplicada e menor', () {
      final Device device = Device.fromJson(
        JsonMap(deviceJson(policyVersion: 5, appliedPolicyVersion: 4)),
      );
      expect(device.policyPending, isTrue);
    });

    test('sem limite a fracao usada e zero', () {
      final Map<String, Object?> withoutLimit = <String, Object?>{...stateJson}..['limitMs'] = null;
      final DeviceState state = DeviceState.fromJson(JsonMap(withoutLimit));
      expect(state.usedFraction, 0);
    });

    test('valores desconhecidos caem no padrao', () {
      expect(DeviceManagementMode.parse('outro'), DeviceManagementMode.standard);
      expect(DeviceLockState.parse(null), DeviceLockState.none);
      expect(DeviceStatus.parse('qualquer'), DeviceStatus.active);
    });
  });

  group('DevicesRepository', () {
    late List<http.Request> requests;

    DevicesRepository repositoryWith(Object? Function(http.Request request) respond) {
      requests = <http.Request>[];
      final ApiClient api = ApiClient(
        httpClient: MockClient((http.Request request) async {
          requests.add(request);
          final Object? body = respond(request);
          if (body == null) {
            return http.Response('', 204);
          }
          if (body is http.Response) {
            return body;
          }
          return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
        }),
        baseUrl: () => 'https://servidor.teste',
        sessionToken: () => 'gs_abc',
      );
      return DevicesRepository(api);
    }

    const Map<String, Object?> policyEnvelope = <String, Object?>{
      'policyVersion': 7,
      'policy': <String, Object?>{'timezone': 'America/Fortaleza'},
    };

    test('lista os aparelhos', () async {
      final DevicesRepository repository = repositoryWith(
        (http.Request request) => <String, Object?>{
          'devices': <Object?>[deviceJson(), deviceJson(id: 'd2', status: 'pending')],
        },
      );

      final List<Device> devices = await repository.listDevices();

      expect(devices.map((Device d) => d.id), <String>['d1', 'd2']);
      expect(requests.single.url.path, '/v1/guardian/devices');
    });

    test('busca o aparelho com a politica', () async {
      final DevicesRepository repository = repositoryWith(
        (http.Request request) => <String, Object?>{'device': deviceJson(), ...policyEnvelope},
      );

      final DeviceDetail detail = await repository.getDevice('d1');

      expect(detail.device.id, 'd1');
      expect(detail.policy.version, 7);
      expect(detail.policy.policy.timezone, 'America/Fortaleza');
    });

    test('grava a politica sem os overrides e com a versao base', () async {
      final DevicesRepository repository = repositoryWith((http.Request request) => policyEnvelope);
      const Policy policy = Policy(
        timezone: 'America/Fortaleza',
        dailyLimit: DailyLimit(enabled: true, minutes: 150),
      );

      final DevicePolicy saved = await repository.updatePolicy(
        'd1',
        baseVersion: 6,
        policy: policy,
      );

      expect(saved.version, 7);
      final http.Request request = requests.single;
      expect(request.method, 'PUT');
      expect(request.url.path, '/v1/guardian/devices/d1/policy');
      final Map<String, Object?> body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['baseVersion'], 6);
      final Map<String, Object?> sent = body['policy']! as Map<String, Object?>;
      expect(sent.containsKey('overrides'), isFalse);
      expect((sent['dailyLimit']! as Map<String, Object?>)['minutes'], 150);
    });

    test('comandos usam a rota e o corpo do protocolo', () async {
      final DevicesRepository repository = repositoryWith((http.Request request) => policyEnvelope);

      await repository.grantExtraTime('d1', minutes: 30);
      await repository.lock('d1');
      await repository.lock('d1', until: 5000);
      await repository.unlock('d1');
      await repository.suspend(
        'd1',
        minutes: 60,
        scopes: <SuspensionScope>[SuspensionScope.dailyLimit, SuspensionScope.schedules],
      );
      await repository.clearSuspension('d1');

      expect(requests.map((http.Request r) => '${r.method} ${r.url.path}'), <String>[
        'POST /v1/guardian/devices/d1/extra-time',
        'POST /v1/guardian/devices/d1/lock',
        'POST /v1/guardian/devices/d1/lock',
        'POST /v1/guardian/devices/d1/unlock',
        'POST /v1/guardian/devices/d1/suspension',
        'DELETE /v1/guardian/devices/d1/suspension',
      ]);
      expect(jsonDecode(requests[0].body), <String, Object?>{'minutes': 30});
      expect(jsonDecode(requests[1].body), <String, Object?>{'until': null});
      expect(jsonDecode(requests[2].body), <String, Object?>{'until': 5000});
      expect(jsonDecode(requests[4].body), <String, Object?>{
        'minutes': 60,
        'scopes': <String>['dailyLimit', 'schedules'],
      });
    });

    test('vinculo, nome, revogacao e exclusao', () async {
      final DevicesRepository repository = repositoryWith((http.Request request) {
        if (request.method == 'GET') {
          return <String, Object?>{'secret': 'GEZDGNBVGY3TQOJQ'};
        }
        if (request.url.path.endsWith('/approve') || request.method == 'PATCH') {
          return <String, Object?>{'device': deviceJson(childName: 'Ana')};
        }
        return null;
      });

      expect((await repository.approve('d1', childName: 'Ana')).childName, 'Ana');
      expect((await repository.rename('d1', childName: 'Ana')).childName, 'Ana');
      await repository.reject('d2');
      await repository.revoke('d1');
      await repository.deleteData('d1');
      await repository.deleteDevice('d1');
      expect(await repository.offlineSecret('d1'), 'GEZDGNBVGY3TQOJQ');

      expect(requests.map((http.Request r) => '${r.method} ${r.url.path}'), <String>[
        'POST /v1/guardian/devices/d1/approve',
        'PATCH /v1/guardian/devices/d1',
        'POST /v1/guardian/devices/d2/reject',
        'POST /v1/guardian/devices/d1/revoke',
        'DELETE /v1/guardian/devices/d1/data',
        'DELETE /v1/guardian/devices/d1',
        'GET /v1/guardian/devices/d1/offline-secret',
      ]);
    });

    test('conflito de versao chega como ApiFailure identificavel', () async {
      final DevicesRepository repository = repositoryWith((http.Request request) {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(<String, Object?>{
              'error': <String, Object?>{
                'code': 'version_conflict',
                'message': 'A política foi alterada em outro aparelho.',
                'details': <String, Object?>{'currentVersion': 9},
              },
            }),
          ),
          409,
        );
      });

      await expectLater(
        repository.updatePolicy('d1', baseVersion: 6, policy: const Policy(timezone: 'UTC')),
        throwsA(
          isA<ApiFailure>().having((ApiFailure f) => f.isVersionConflict, 'conflito', isTrue),
        ),
      );
    });
  });

  group('provedores de aparelhos', () {
    ProviderContainer containerWith(List<Map<String, Object?>> devices) {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          ...baseOverrides(),
          httpClientProvider.overrideWithValue(
            MockClient((http.Request request) async {
              return http.Response.bytes(
                utf8.encode(jsonEncode(<String, Object?>{'devices': devices})),
                200,
              );
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('separa ativos e pendentes e escolhe o primeiro ativo por padrao', () async {
      final ProviderContainer container = containerWith(<Map<String, Object?>>[
        deviceJson(id: 'p1', status: 'pending'),
        deviceJson(),
        deviceJson(id: 'd2', childName: 'Ana'),
        deviceJson(id: 'r1', status: 'revoked'),
      ]);

      await container.read(devicesProvider.future);

      expect(container.read(activeDevicesProvider).map((Device d) => d.id), <String>['d1', 'd2']);
      expect(container.read(pendingDevicesProvider).map((Device d) => d.id), <String>['p1']);
      expect(container.read(selectedDeviceProvider)?.id, 'd1');

      container.read(selectedDeviceIdProvider.notifier).select('d2');
      expect(container.read(selectedDeviceProvider)?.id, 'd2');

      // Selecionar um aparelho que nao esta ativo volta ao primeiro ativo.
      container.read(selectedDeviceIdProvider.notifier).select('r1');
      expect(container.read(selectedDeviceProvider)?.id, 'd1');
    });

    test('sem aparelho ativo nao ha selecionado', () async {
      final ProviderContainer container = containerWith(<Map<String, Object?>>[
        deviceJson(id: 'p1', status: 'pending'),
      ]);

      await container.read(devicesProvider.future);

      expect(container.read(selectedDeviceProvider), isNull);
    });

    test('replace troca um aparelho sem ir ao servidor', () async {
      final ProviderContainer container = containerWith(<Map<String, Object?>>[deviceJson()]);
      await container.read(devicesProvider.future);

      container
          .read(devicesProvider.notifier)
          .replace(Device.fromJson(JsonMap(deviceJson(childName: 'Pedro'))));

      expect(container.read(selectedDeviceProvider)?.childName, 'Pedro');
    });
  });
}
