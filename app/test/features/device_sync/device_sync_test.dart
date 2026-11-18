import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/core/platform/native_api.g.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/device_sync/data/mappers/realtime_update_mapper.dart';
import 'package:parentalynx/features/device_sync/domain/entities/device_sync_result.dart';
import 'package:parentalynx/features/device_sync/domain/entities/policy_sync_status.dart';
import 'package:parentalynx/features/device_sync/domain/entities/realtime_update.dart';
import 'package:parentalynx/features/device_sync/domain/usecases/manage_realtime_connection.dart';
import 'package:parentalynx/features/device_sync/domain/usecases/trigger_device_sync.dart';
import 'package:parentalynx/features/device_sync/presentation/bloc/device_sync_bloc.dart';

import '../../support/fakes.dart';
import '../../support/test_dependencies.dart';

void main() {
  group('RealtimeUpdateMapper', () {
    RealtimeUpdate? map(Map<String, Object?> json) => RealtimeUpdateMapper.fromJson(JsonMap(json));

    test('converte cada tipo do protocolo', () {
      expect(
        map(<String, Object?>{'type': 'device_updated', 'deviceId': 'd1'}),
        const DeviceStateChanged('d1'),
      );
      expect(
        map(<String, Object?>{'type': 'link_pending', 'deviceId': 'd1'}),
        const LinkRequested('d1'),
      );
      expect(
        map(<String, Object?>{'type': 'link_resolved', 'deviceId': 'd1', 'status': 'approved'}),
        const LinkResolved(deviceId: 'd1', status: 'approved'),
      );
      expect(
        map(<String, Object?>{'type': 'policy_applied', 'deviceId': 'd1', 'version': 4}),
        const PolicyApplied(deviceId: 'd1', version: 4),
      );
      expect(
        map(<String, Object?>{'type': 'time_request', 'deviceId': 'd1', 'requestId': 'r1'}),
        const TimeRequestReceived(deviceId: 'd1', requestId: 'r1'),
      );
    });

    test('alerta traz os campos mostrados e aplica os padroes', () {
      final RealtimeUpdate? update = map(<String, Object?>{
        'type': 'alert',
        'alert': <String, Object?>{'id': 9, 'type': 'low_time', 'title': 'Pouco tempo'},
      });
      expect(update, isA<AlertRaised>());
      final RealtimeAlert alert = (update! as AlertRaised).alert;
      expect(alert.id, 9);
      expect(alert.title, 'Pouco tempo');
      expect(alert.body, '');
      expect(alert.notify, isTrue);
      expect(update.affectsDevices, isFalse);
    });

    test('descarta tipo desconhecido, campo faltando e formato errado', () {
      expect(map(<String, Object?>{'type': 'hello', 'serverTime': 1}), isNull);
      expect(map(<String, Object?>{'type': 'device_updated'}), isNull);
      expect(
        map(<String, Object?>{
          'type': 'alert',
          'alert': <String, Object?>{'id': 'x'},
        }),
        isNull,
      );
    });

    test('so avisos de aparelho pedem recarga da lista', () {
      expect(const DeviceStateChanged('d1').affectsDevices, isTrue);
      expect(const LinkRequested('d1').affectsDevices, isTrue);
      expect(const PolicyApplied(deviceId: 'd1', version: 1).affectsDevices, isTrue);
    });
  });

  test('confirmacao da politica fica pendente ate o aparelho aplicar a versao', () {
    const PolicySyncStatus pending = PolicySyncStatus(
      serverVersion: 5,
      appliedVersion: 4,
      deviceOnline: true,
    );
    expect(pending.isPending, isTrue);
    expect(
      const PolicySyncStatus(serverVersion: 5, appliedVersion: 5, deviceOnline: false).isPending,
      isFalse,
    );
  });

  group('DeviceSyncBloc', () {
    late TestDependencies deps;

    setUp(() {
      deps = TestDependencies(sessionToken: 'gs_x');
      addTearDown(deps.dispose);
    });

    blocTest<DeviceSyncBloc, DeviceSyncState>(
      'abre o canal, acompanha a conexao e fecha ao ser descartado',
      build: () => DeviceSyncBloc(connection: deps.di<ManageRealtimeConnection>()),
      act: (DeviceSyncBloc bloc) async {
        bloc.add(const DeviceSyncStarted());
        await Future<void>.delayed(Duration.zero);
        deps.realtime.setConnected(connected: true);
        await Future<void>.delayed(Duration.zero);
        deps.realtime.setConnected(connected: false);
      },
      expect: () => const <DeviceSyncState>[
        DeviceSyncConnecting(),
        DeviceSyncOnline(),
        DeviceSyncOffline(),
      ],
      verify: (DeviceSyncBloc bloc) {
        expect(deps.realtime.connects, 1);
        expect(deps.realtime.disconnects, 1);
      },
    );
  });

  test('sincronizar agora pede ao agente nativo e converte o resultado', () async {
    final TestDependencies deps = TestDependencies();
    addTearDown(deps.dispose);
    when(deps.native.agent.syncNow)
        .thenAnswer((_) async => SyncOutcome(ok: false, atMs: 10, errorCode: 'network'));

    final Result<DeviceSyncResult> result = await deps.di<TriggerDeviceSync>()();

    expect(result.valueOrNull, const DeviceSyncResult(ok: false, atMs: 10, errorCode: 'network'));
  });

  test('canal falso registra conexoes', () {
    final FakeRealtimeRepository realtime = FakeRealtimeRepository()..connect();
    expect(realtime.connects, 1);
  });
}
