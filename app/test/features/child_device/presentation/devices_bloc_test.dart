import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/features/child_device/data/dto/child_device_dto.dart';
import 'package:parentalynx/features/child_device/data/mappers/child_device_mapper.dart';
import 'package:parentalynx/features/child_device/domain/entities/child_device.dart';
import 'package:parentalynx/features/child_device/domain/repositories/i_child_device_repository.dart';
import 'package:parentalynx/features/child_device/domain/usecases/refresh_child_devices.dart';
import 'package:parentalynx/features/child_device/domain/usecases/watch_child_devices.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';
import 'package:parentalynx/features/device_sync/domain/entities/realtime_update.dart';
import 'package:parentalynx/features/device_sync/domain/usecases/watch_realtime_updates.dart';

import '../../../support/fake_backend.dart';
import '../../../support/fakes.dart';
import '../../../support/test_dependencies.dart';
import '../support/device_fixtures.dart';

void main() {
  late FakeBackend backend;
  late TestDependencies deps;

  void serve(List<Map<String, Object?>> devices) {
    backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{'devices': devices});
  }

  DevicesBloc build({Duration debounce = const Duration(milliseconds: 400)}) {
    return DevicesBloc(
      watchDevices: deps.di<WatchChildDevices>(),
      refreshDevices: deps.di<RefreshChildDevices>(),
      watchRealtimeUpdates: deps.di<WatchRealtimeUpdates>(),
      realtimeDebounce: debounce,
    );
  }

  setUp(() {
    backend = FakeBackend();
    deps = TestDependencies(backend: backend, sessionToken: 'gs_abc');
    addTearDown(deps.dispose);
  });

  test('separa ativos e pendentes e escolhe o primeiro ativo por padrao', () async {
    serve(<Map<String, Object?>>[
      deviceJson(id: 'p1', status: 'pending'),
      deviceJson(),
      deviceJson(id: 'd2', childName: 'Ana'),
      deviceJson(id: 'r1', status: 'revoked'),
    ]);
    final DevicesBloc bloc = build()..add(const DevicesStarted());
    addTearDown(bloc.close);

    final DevicesState loaded = await bloc.stream.firstWhere(
      (DevicesState s) => s is DevicesLoaded,
    );
    expect(loaded.active.map((ChildDevice d) => d.id), <String>['d1', 'd2']);
    expect(loaded.pending.map((ChildDevice d) => d.id), <String>['p1']);
    expect(loaded.selected?.id, 'd1');

    bloc.add(const DeviceSelected('d2'));
    expect((await bloc.stream.first).selected?.id, 'd2');

    // Escolher um aparelho que nao esta ativo volta ao primeiro ativo.
    bloc.add(const DeviceSelected('r1'));
    expect((await bloc.stream.first).selected?.id, 'd1');
  });

  test('sem aparelho ativo nao ha selecionado; conta vazia vira estado vazio', () async {
    serve(<Map<String, Object?>>[deviceJson(id: 'p1', status: 'pending')]);
    final DevicesBloc bloc = build()..add(const DevicesStarted());
    addTearDown(bloc.close);
    final DevicesState state = await bloc.stream.firstWhere((DevicesState s) => s is DevicesLoaded);
    expect(state.selected, isNull);

    serve(<Map<String, Object?>>[]);
    bloc.add(const DevicesRefreshRequested());
    await expectLater(bloc.stream, emitsThrough(isA<DevicesEmpty>()));
  });

  test('alteracao feita por outra funcionalidade chega pela lista observada', () async {
    serve(<Map<String, Object?>>[deviceJson()]);
    final DevicesBloc bloc = build()..add(const DevicesStarted());
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((DevicesState s) => s is DevicesLoaded);

    deps.di<IChildDeviceRepository>().upsert(
      ChildDeviceMapper.device(ChildDeviceDto.fromJson(JsonMap(deviceJson(childName: 'Pedro')))),
    );

    expect((await bloc.stream.first).selected?.childName, 'Pedro');
  });

  blocTest<DevicesBloc, DevicesState>(
    'primeira carga com falha mostra o erro e tentar de novo carrega',
    setUp: () => backend.onError('GET', '/v1/guardian/devices', status: 500, code: 'internal'),
    build: build,
    act: (DevicesBloc bloc) async {
      bloc.add(const DevicesStarted());
      await bloc.stream.firstWhere((DevicesState s) => s is DevicesError);
      serve(<Map<String, Object?>>[deviceJson()]);
      final Completer<void> done = Completer<void>();
      bloc.add(DevicesRefreshRequested(completer: done));
      await done.future;
    },
    expect: () => <Object>[
      const DevicesLoading(),
      isA<DevicesError>().having((DevicesError s) => s.failure, 'falha', isA<ApiFailure>()),
      const DevicesLoading(),
      isA<DevicesLoaded>(),
    ],
  );

  test('rajada de avisos em tempo real vira uma unica recarga', () async {
    serve(<Map<String, Object?>>[deviceJson()]);
    final FakeRealtimeRepository realtime = deps.realtime;
    final DevicesBloc bloc = build(debounce: const Duration(milliseconds: 20))
      ..add(const DevicesStarted());
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((DevicesState s) => s is DevicesLoaded);
    final int before = backend.calls('GET', '/v1/guardian/devices').length;

    realtime
      ..emit(const DeviceStateChanged('d1'))
      ..emit(const PolicyApplied(deviceId: 'd1', version: 4))
      ..emit(const TimeRequestReceived(deviceId: 'd1', requestId: 'r1'));
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(backend.calls('GET', '/v1/guardian/devices').length, before + 1);
  });

  test('aviso que nao mexe em aparelhos nao recarrega', () async {
    serve(<Map<String, Object?>>[deviceJson()]);
    final DevicesBloc bloc = build(debounce: const Duration(milliseconds: 20))
      ..add(const DevicesStarted());
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((DevicesState s) => s is DevicesLoaded);
    final int before = backend.calls('GET', '/v1/guardian/devices').length;

    deps.realtime.emit(
      const AlertRaised(
        RealtimeAlert(id: 1, type: 'low_time', createdAt: 1, notify: true, title: 't', body: 'b'),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(backend.calls('GET', '/v1/guardian/devices').length, before);
  });
}
