import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/bloc/action_status.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/child_device/domain/entities/child_device.dart';
import 'package:parentalynx/features/child_device/domain/usecases/refresh_child_devices.dart';
import 'package:parentalynx/features/device_sync/domain/entities/realtime_update.dart';
import 'package:parentalynx/features/screen_time/domain/entities/time_request.dart';
import 'package:parentalynx/features/screen_time/domain/services/time_request_counts.dart';
import 'package:parentalynx/features/screen_time/domain/usecases/approve_time_request.dart';
import 'package:parentalynx/features/screen_time/domain/usecases/deny_time_request.dart';
import 'package:parentalynx/features/screen_time/presentation/bloc/time_requests/time_requests_bloc.dart';
import 'package:parentalynx/features/screen_time/screen_time_module.dart';

import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_dependencies.dart';

void main() {
  const String listPath = '/v1/guardian/devices/d1/time-requests';
  const String resolvePath = '/v1/guardian/time-requests/r1/resolve';

  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_x');
    registerScreenTimeModule(deps.di);
    deps.backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{
      'devices': <Object?>[deviceJson(id: 'd1', pendingTimeRequests: 1)],
    });
  });

  tearDown(() => deps.dispose());

  Map<String, Object?> pendingRequest() {
    return <String, Object?>{
      'id': 'r1',
      'deviceId': 'd1',
      'childName': 'João',
      'createdAt': 10,
      'minutes': 30,
      'message': 'Falta pouco para acabar o filme',
      'status': 'pending',
    };
  }

  group('pedidos de tempo e conta', () {
    blocTest<TimeRequestsBloc, TimeRequestsState>(
      'lista os pedidos dos aparelhos ativos e resolve com os minutos',
      setUp: () {
        deps.backend
          ..onJson('GET', listPath, <String, Object?>{
            'requests': <Object?>[pendingRequest()],
          })
          ..onJson('POST', resolvePath, <String, Object?>{
            'request': <String, Object?>{
              'id': 'r1',
              'deviceId': 'd1',
              'childName': 'João',
              'createdAt': 10,
              'minutes': 30,
              'status': 'approved',
              'grantedMinutes': 45,
              'resolvedAt': 20,
            },
            'policyVersion': 4,
          });
      },
      build: () => deps.di<TimeRequestsBloc>(),
      act: (TimeRequestsBloc bloc) async {
        bloc.add(const TimeRequestsStarted());
        final TimeRequestsLoaded loaded = await bloc.stream.firstWhere(
          (TimeRequestsState state) => state is TimeRequestsLoaded,
        ) as TimeRequestsLoaded;
        final Result<List<ChildDevice>> devices = await deps.di<RefreshChildDevices>()();
        expect(countPendingTimeRequests(devices.valueOrNull!), 1);

        bloc.add(TimeRequestApproved(request: loaded.requests.single, minutes: 45));
        await bloc.stream.firstWhere(
          (TimeRequestsState state) =>
              state is TimeRequestsLoaded && state.action is ActionSucceeded,
        );
      },
      expect: () => <Matcher>[
        isA<TimeRequestsLoading>(),
        isA<TimeRequestsLoaded>()
            .having((TimeRequestsLoaded s) => s.pending.single.id, 'pendente', 'r1')
            .having((TimeRequestsLoaded s) => s.pending.single.isPending, 'aguardando', isTrue),
        isA<TimeRequestsLoaded>()
            .having((TimeRequestsLoaded s) => s.resolvingId, 'respondendo', 'r1')
            .having((TimeRequestsLoaded s) => s.action, 'andamento', isA<ActionRunning>()),
        isA<TimeRequestsLoaded>()
            .having(
              (TimeRequestsLoaded s) => s.requests.single.status,
              'status',
              TimeRequestStatus.approved,
            )
            .having((TimeRequestsLoaded s) => s.requests.single.grantedMinutes, 'concedido', 45)
            .having((TimeRequestsLoaded s) => s.resolvingId, 'respondendo', isNull)
            .having(
              (TimeRequestsLoaded s) => s.action,
              'andamento',
              const ActionSucceeded(
                message: '45min a mais para João hoje. O aparelho recebe em instantes.',
              ),
            ),
      ],
      verify: (_) {
        expect(deps.backend.lastBody('POST', resolvePath), <String, Object?>{
          'action': 'approve',
          'minutes': 45,
        });
      },
    );

    test('negar nao envia minutos', () async {
      deps.backend.onJson('POST', resolvePath, <String, Object?>{
        'request': <String, Object?>{'id': 'r1', 'status': 'denied'},
      });

      final Result<TimeRequest> result = await deps.di<DenyTimeRequest>()('r1');

      expect(result.valueOrNull?.status, TimeRequestStatus.denied);
      expect(deps.backend.lastBody('POST', resolvePath), <String, Object?>{'action': 'deny'});
    });
  });

  test('aprovar fora do intervalo permitido nem chega ao servidor', () async {
    final Result<TimeRequest> result = await deps.di<ApproveTimeRequest>()(
      'r1',
      minutes: TimeRequest.maxGrantMinutes + 1,
    );

    expect(result, isA<Err<TimeRequest>>());
    expect((result as Err<TimeRequest>).failure, isA<ValidationFailure>());
    expect(deps.backend.calls('POST', resolvePath), isEmpty);
  });

  blocTest<TimeRequestsBloc, TimeRequestsState>(
    'sem pedidos mostra o vazio e um pedido novo recarrega a lista',
    setUp: () {
      deps.backend.onJson('GET', listPath, <String, Object?>{'requests': <Object?>[]});
    },
    build: () => deps.di<TimeRequestsBloc>(),
    act: (TimeRequestsBloc bloc) async {
      bloc.add(const TimeRequestsStarted());
      await bloc.stream.firstWhere((TimeRequestsState state) => state is TimeRequestsEmpty);
      deps.backend.onJson('GET', listPath, <String, Object?>{
        'requests': <Object?>[pendingRequest()],
      });
      deps.realtime.emit(const TimeRequestReceived(deviceId: 'd1', requestId: 'r1'));
      await bloc.stream.firstWhere((TimeRequestsState state) => state is TimeRequestsLoaded);
    },
    expect: () => <Matcher>[
      isA<TimeRequestsLoading>(),
      isA<TimeRequestsEmpty>(),
      isA<TimeRequestsLoaded>().having(
        (TimeRequestsLoaded s) => s.pending,
        'pendentes',
        hasLength(1),
      ),
    ],
  );

  blocTest<TimeRequestsBloc, TimeRequestsState>(
    'falha ao listar os aparelhos vira erro',
    setUp: () {
      deps.backend.onError('GET', '/v1/guardian/devices', status: 500, code: 'internal');
    },
    build: () => deps.di<TimeRequestsBloc>(),
    act: (TimeRequestsBloc bloc) async {
      bloc.add(const TimeRequestsStarted());
      await bloc.stream.firstWhere((TimeRequestsState state) => state is TimeRequestsError);
    },
    expect: () => <Matcher>[
      isA<TimeRequestsLoading>(),
      isA<TimeRequestsError>().having(
        (TimeRequestsError s) => s.failure,
        'falha',
        isA<ApiFailure>(),
      ),
    ],
  );
}
