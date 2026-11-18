import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/bloc/action_status.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/core/utils/observable_value.dart';
import 'package:parentalynx/features/child_device/domain/entities/child_device.dart';
import 'package:parentalynx/features/child_device/domain/usecases/delete_child_device.dart';
import 'package:parentalynx/features/child_device/domain/usecases/delete_child_device_data.dart';
import 'package:parentalynx/features/child_device/domain/usecases/export_child_device_data.dart';
import 'package:parentalynx/features/child_device/domain/usecases/get_offline_access_secret.dart';
import 'package:parentalynx/features/child_device/domain/usecases/refresh_child_devices.dart';
import 'package:parentalynx/features/child_device/domain/usecases/rename_child_device.dart';
import 'package:parentalynx/features/child_device/domain/usecases/revoke_device_link.dart';
import 'package:parentalynx/features/child_device/domain/usecases/watch_child_devices.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/child_device/child_device_bloc.dart';

class _MockWatchChildDevices extends Mock implements WatchChildDevices {}

class _MockRefreshChildDevices extends Mock implements RefreshChildDevices {}

class _MockRenameChildDevice extends Mock implements RenameChildDevice {}

class _MockRevokeDeviceLink extends Mock implements RevokeDeviceLink {}

class _MockDeleteChildDevice extends Mock implements DeleteChildDevice {}

class _MockDeleteChildDeviceData extends Mock implements DeleteChildDeviceData {}

class _MockExportChildDeviceData extends Mock implements ExportChildDeviceData {}

class _MockGetOfflineAccessSecret extends Mock implements GetOfflineAccessSecret {}

ChildDevice _device({String childName = 'João'}) {
  return ChildDevice(
    id: 'd1',
    status: DeviceLinkStatus.active,
    childName: childName,
    deviceName: 'Moto G de João',
    model: 'moto g54',
    manufacturer: 'motorola',
    androidRelease: '14',
    sdkInt: 34,
    appVersion: '1.0.0',
    timezone: 'America/Fortaleza',
    relink: false,
    createdAt: 1,
    online: true,
    today: '2026-11-17',
    managementMode: DeviceManagementMode.standard,
    policyVersion: 3,
    appliedPolicyVersion: 3,
    pendingTimeRequests: 0,
  );
}

void main() {
  late _MockWatchChildDevices watchDevices;
  late _MockRefreshChildDevices refreshDevices;
  late _MockRenameChildDevice rename;
  late _MockRevokeDeviceLink revoke;
  late _MockDeleteChildDevice delete;
  late _MockDeleteChildDeviceData deleteData;
  late _MockExportChildDeviceData export;
  late _MockGetOfflineAccessSecret offlineSecret;
  late ObservableValue<ChildDevice?> device;
  final ChildDevice joao = _device();

  setUp(() {
    watchDevices = _MockWatchChildDevices();
    refreshDevices = _MockRefreshChildDevices();
    rename = _MockRenameChildDevice();
    revoke = _MockRevokeDeviceLink();
    delete = _MockDeleteChildDevice();
    deleteData = _MockDeleteChildDeviceData();
    export = _MockExportChildDeviceData();
    offlineSecret = _MockGetOfflineAccessSecret();
    device = ObservableValue<ChildDevice?>.seeded(joao);
    addTearDown(device.close);
    when(() => watchDevices.device(any())).thenAnswer((_) => device.stream);
    // A lista da conta ja foi carregada pelo painel.
    when(() => watchDevices.cached).thenReturn(<ChildDevice>[joao]);
  });

  ChildDeviceBloc build() {
    return ChildDeviceBloc(
      watchDevices: watchDevices,
      refreshDevices: refreshDevices,
      rename: rename,
      revoke: revoke,
      delete: delete,
      deleteData: deleteData,
      export: export,
      offlineSecret: offlineSecret,
    );
  }

  Future<void> start(ChildDeviceBloc bloc) async {
    bloc.add(const ChildDeviceStarted('d1'));
    await pumpEventQueue();
  }

  group('carga', () {
    blocTest<ChildDeviceBloc, ChildDeviceState>(
      'mostra o aparelho da lista da conta e acompanha as mudancas',
      build: build,
      act: (ChildDeviceBloc bloc) async {
        await start(bloc);
        device.add(_device(childName: 'Joãozinho'));
      },
      expect: () => <ChildDeviceState>[
        ChildDeviceLoaded(device: joao),
        ChildDeviceLoaded(device: _device(childName: 'Joãozinho')),
      ],
      verify: (_) => verifyNever(refreshDevices.call),
    );

    blocTest<ChildDeviceBloc, ChildDeviceState>(
      'aparelho que sai da lista aparece como nao encontrado',
      build: build,
      act: (ChildDeviceBloc bloc) async {
        await start(bloc);
        device.add(null);
      },
      expect: () => <ChildDeviceState>[
        ChildDeviceLoaded(device: joao),
        const ChildDeviceNotFound(),
      ],
    );

    blocTest<ChildDeviceBloc, ChildDeviceState>(
      'aberto direto, busca a lista da conta',
      setUp: () {
        when(() => watchDevices.cached).thenReturn(null);
        when(refreshDevices.call)
            .thenAnswer((_) async => Ok<List<ChildDevice>>(<ChildDevice>[joao]));
      },
      build: build,
      act: start,
      expect: () => <ChildDeviceState>[ChildDeviceLoaded(device: joao)],
      verify: (_) => verify(refreshDevices.call).called(1),
    );

    blocTest<ChildDeviceBloc, ChildDeviceState>(
      'aberto direto e sem conseguir a lista, mostra que nao encontrou',
      setUp: () {
        when(() => watchDevices.cached).thenReturn(null);
        when(() => watchDevices.device(any()))
            .thenAnswer((_) => const Stream<ChildDevice?>.empty());
        when(refreshDevices.call).thenAnswer((_) async {
          return const Err<List<ChildDevice>>(NetworkFailure());
        });
      },
      build: build,
      act: start,
      expect: () => const <ChildDeviceState>[ChildDeviceNotFound()],
    );
  });

  group('acoes', () {
    blocTest<ChildDeviceBloc, ChildDeviceState>(
      'renomear confirma com aviso',
      setUp: () {
        when(() => rename(any(), childName: any(named: 'childName'))).thenAnswer((_) async {
          return Ok<ChildDevice>(_device(childName: 'Joãozinho'));
        });
      },
      build: build,
      act: (ChildDeviceBloc bloc) async {
        await start(bloc);
        bloc.add(const ChildDeviceRenameRequested('Joãozinho'));
      },
      skip: 1,
      expect: () => <ChildDeviceState>[
        ChildDeviceLoaded(
          device: joao,
          action: const ActionRunning(),
          task: ChildDeviceTask.rename,
        ),
        ChildDeviceLoaded(
          device: joao,
          action: const ActionSucceeded(message: 'Nome alterado.'),
        ),
      ],
      verify: (_) => verify(() => rename('d1', childName: 'Joãozinho')).called(1),
    );

    blocTest<ChildDeviceBloc, ChildDeviceState>(
      'desistir do pedido de senha volta ao estado anterior sem aviso',
      setUp: () {
        when(() => revoke(any())).thenAnswer((_) async => const Err<void>(CancelledFailure()));
      },
      build: build,
      act: (ChildDeviceBloc bloc) async {
        await start(bloc);
        bloc.add(const ChildDeviceRevokeRequested());
      },
      skip: 1,
      expect: () => <ChildDeviceState>[
        ChildDeviceLoaded(
          device: joao,
          action: const ActionRunning(),
          task: ChildDeviceTask.revoke,
        ),
        ChildDeviceLoaded(device: joao),
      ],
    );

    blocTest<ChildDeviceBloc, ChildDeviceState>(
      'falha mostra o motivo',
      setUp: () {
        when(() => deleteData(any())).thenAnswer((_) async => const Err<void>(NetworkFailure()));
      },
      build: build,
      act: (ChildDeviceBloc bloc) async {
        await start(bloc);
        bloc.add(const ChildDeviceDataDeleteRequested());
      },
      skip: 1,
      expect: () => <ChildDeviceState>[
        ChildDeviceLoaded(
          device: joao,
          action: const ActionRunning(),
          task: ChildDeviceTask.deleteData,
        ),
        ChildDeviceLoaded(device: joao, action: const ActionFailed(NetworkFailure())),
      ],
    );

    blocTest<ChildDeviceBloc, ChildDeviceState>(
      'exportar entrega os dados para a tela compartilhar',
      setUp: () {
        when(() => export(any())).thenAnswer((_) async => const Ok<String>('{"device": {}}'));
      },
      build: build,
      act: (ChildDeviceBloc bloc) async {
        await start(bloc);
        bloc.add(const ChildDeviceExportRequested());
      },
      skip: 2,
      expect: () => <ChildDeviceState>[
        ChildDeviceLoaded(
          device: joao,
          action: const ActionSucceeded(),
          outcome: const ChildDeviceExportReady('{"device": {}}'),
        ),
      ],
    );

    blocTest<ChildDeviceBloc, ChildDeviceState>(
      'codigo offline entrega o segredo para a folha calcular o codigo',
      setUp: () {
        when(() => offlineSecret(any())).thenAnswer((_) async => const Ok<String>('SEGREDO'));
      },
      build: build,
      act: (ChildDeviceBloc bloc) async {
        await start(bloc);
        bloc.add(const ChildDeviceOfflineCodeRequested());
      },
      skip: 2,
      expect: () => <ChildDeviceState>[
        ChildDeviceLoaded(
          device: joao,
          action: const ActionSucceeded(),
          outcome: const ChildDeviceOfflineSecretReady('SEGREDO'),
        ),
      ],
    );

    blocTest<ChildDeviceBloc, ChildDeviceState>(
      'apagar o aparelho fecha a tela mesmo quando ele sai da lista',
      setUp: () {
        when(() => delete(any())).thenAnswer((_) async => const Ok<void>(null));
      },
      build: build,
      act: (ChildDeviceBloc bloc) async {
        await start(bloc);
        bloc.add(const ChildDeviceDeleteRequested());
        await pumpEventQueue();
        device.add(null);
      },
      skip: 2,
      expect: () => const <ChildDeviceState>[ChildDeviceRemoved()],
    );

    blocTest<ChildDeviceBloc, ChildDeviceState>(
      'acao em andamento ignora outro toque',
      setUp: () {
        when(() => export(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return const Ok<String>('{}');
        });
      },
      build: build,
      act: (ChildDeviceBloc bloc) async {
        await start(bloc);
        bloc
          ..add(const ChildDeviceExportRequested())
          ..add(const ChildDeviceOfflineCodeRequested());
        await Future<void>.delayed(const Duration(milliseconds: 30));
      },
      verify: (_) {
        verify(() => export('d1')).called(1);
        verifyNever(() => offlineSecret(any()));
      },
    );
  });
}
