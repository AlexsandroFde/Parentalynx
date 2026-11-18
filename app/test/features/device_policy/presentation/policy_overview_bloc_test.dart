import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/features/child_device/domain/usecases/refresh_child_devices.dart';
import 'package:parentalynx/features/device_policy/presentation/bloc/policy_overview/policy_overview_bloc.dart';

import '../../../support/fake_backend.dart';
import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_dependencies.dart';

/// Politica do aparelho na visao geral das regras.
void main() {
  const String detailPath = '/v1/guardian/devices/$deviceId';

  late TestDependencies deps;

  /// Versao da politica que o servidor falso informa na lista e no detalhe do aparelho.
  late int serverVersion;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_teste');
    installStandardRoutes(deps.backend);
    serverVersion = 12;
    deps.backend
      ..on('GET', '/v1/guardian/devices', (http.Request request) {
        return jsonResponse(<String, Object?>{
          'devices': <Object?>[deviceJson(policyVersion: serverVersion)],
        });
      })
      ..on('GET', detailPath, (http.Request request) {
        return jsonResponse(<String, Object?>{
          'device': deviceJson(policyVersion: serverVersion),
          'policyVersion': serverVersion,
          'policy': policyJson(minutes: serverVersion == 12 ? 150 : 90),
        });
      });
  });

  tearDown(() => deps.dispose());

  Future<void> start(PolicyOverviewBloc bloc) async {
    bloc.add(const PolicyOverviewStarted(deviceId));
    await bloc.stream.firstWhere((PolicyOverviewState state) => state is! PolicyOverviewLoading);
  }

  TypeMatcher<PolicyOverviewLoaded> loaded(int version, int minutes) {
    return isA<PolicyOverviewLoaded>()
        .having((PolicyOverviewLoaded s) => s.policy.version, 'versao', version)
        .having((PolicyOverviewLoaded s) => s.policy.policy.dailyLimit.minutes, 'minutos', minutes);
  }

  blocTest<PolicyOverviewBloc, PolicyOverviewState>(
    'carrega a politica do aparelho',
    build: () => deps.di<PolicyOverviewBloc>(),
    act: start,
    expect: () => <Matcher>[isA<PolicyOverviewLoading>(), loaded(12, 150)],
  );

  blocTest<PolicyOverviewBloc, PolicyOverviewState>(
    'versao nova no servidor recarrega em segundo plano',
    build: () => deps.di<PolicyOverviewBloc>(),
    act: (PolicyOverviewBloc bloc) async {
      await start(bloc);
      await deps.di<RefreshChildDevices>()();
      serverVersion = 13;
      await deps.di<RefreshChildDevices>()();
      await bloc.stream.firstWhere(
        (PolicyOverviewState state) => state is PolicyOverviewLoaded && state.policy.version == 13,
      );
    },
    skip: 1,
    expect: () => <Matcher>[loaded(12, 150), loaded(13, 90)],
  );

  blocTest<PolicyOverviewBloc, PolicyOverviewState>(
    'puxar para atualizar busca de novo e avisa quando termina',
    build: () => deps.di<PolicyOverviewBloc>(),
    act: (PolicyOverviewBloc bloc) async {
      await start(bloc);
      serverVersion = 13;
      final Completer<void> done = Completer<void>();
      bloc.add(PolicyOverviewRefreshRequested(completer: done));
      await done.future;
    },
    skip: 1,
    expect: () => <Matcher>[loaded(12, 150), loaded(13, 90)],
  );

  blocTest<PolicyOverviewBloc, PolicyOverviewState>(
    'falha ao atualizar mantem a politica na tela',
    build: () => deps.di<PolicyOverviewBloc>(),
    act: (PolicyOverviewBloc bloc) async {
      await start(bloc);
      deps.backend.onError('GET', detailPath, status: 500, code: 'internal');
      final Completer<void> done = Completer<void>();
      bloc.add(PolicyOverviewRefreshRequested(completer: done));
      await done.future;
    },
    skip: 1,
    expect: () => <Matcher>[loaded(12, 150)],
    verify: (PolicyOverviewBloc bloc) => expect(bloc.state, isA<PolicyOverviewLoaded>()),
  );

  blocTest<PolicyOverviewBloc, PolicyOverviewState>(
    'sem politica mostra o erro',
    setUp: () => deps.backend.onError('GET', detailPath, status: 500, code: 'internal'),
    build: () => deps.di<PolicyOverviewBloc>(),
    act: start,
    expect: () => <Matcher>[
      isA<PolicyOverviewLoading>(),
      isA<PolicyOverviewError>()
          .having((PolicyOverviewError s) => s.deviceId, 'aparelho', deviceId)
          .having((PolicyOverviewError s) => s.failure, 'falha', isA<ApiFailure>()),
    ],
  );
}
