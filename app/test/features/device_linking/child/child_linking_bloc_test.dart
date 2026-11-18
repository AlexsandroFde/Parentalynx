import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/constants/storage_keys.dart';
import 'package:parentalynx/core/platform/native_api.g.dart' hide AgentStatus;
import 'package:parentalynx/features/device_linking/domain/entities/link_state.dart';
import 'package:parentalynx/features/device_linking/domain/repositories/i_link_state_repository.dart';
import 'package:parentalynx/features/device_linking/presentation/bloc/child_linking/child_linking_bloc.dart';
import 'package:parentalynx/features/user_role/domain/usecases/change_user_role.dart';

import '../../../support/fake_backend.dart';
import '../../../support/fakes.dart';
import '../../../support/test_dependencies.dart';
import '../../child_mode/support/child_fakes.dart';

const Map<String, Object?> _claimBody = <String, Object?>{
  'linkId': 'link-1',
  'pollToken': 'pp_token',
  'confirmCode': '4821',
  'guardianName': 'Maria',
  'expiresAt': 1790000000000,
};

const String _claimPath = '/v1/pairing/claim';
const String _statusPath = '/v1/pairing/status';

void main() {
  late FakeBackend backend;
  late InMemorySecureStore store;
  late TestDependencies deps;
  late ChildBridge bridge;

  setUpAll(registerChildFallbacks);

  setUp(() {
    backend = FakeBackend()..onJson('POST', _claimPath, _claimBody, status: 201);
    store = InMemorySecureStore();
    (:deps, :bridge) = childDependencies(backend: backend, secureStore: store);
    addTearDown(deps.dispose);
  });

  /// O temporizador da espera nao dispara nos testes: a consulta e pedida a mao.
  Future<ChildLinkingBloc> build() async {
    final ChildLinkingBloc bloc = ChildLinkingBloc(
      getDeviceIdentity: deps.di(),
      submitPairingCode: deps.di(),
      checkPairingStatus: deps.di(),
      activateLinkedDevice: deps.di(),
      restorePendingClaim: deps.di(),
      discardPendingClaim: deps.di(),
      changeUserRole: deps.di<ChangeUserRole>(),
      pollInterval: const Duration(hours: 1),
    )..add(const ChildLinkingStarted());
    addTearDown(bloc.close);
    await pumpEventQueue();
    return bloc;
  }

  Future<void> submit(ChildLinkingBloc bloc, {String code = 'AB2D9XYZ', String name = 'Celular'}) {
    bloc.add(ChildLinkingCodeSubmitted(code: code, deviceName: name));
    return pumpEventQueue();
  }

  Future<void> poll(ChildLinkingBloc bloc) {
    bloc.add(const ChildLinkingPollRequested());
    return pumpEventQueue();
  }

  LinkPhase phase() => deps.di<ILinkStateRepository>().current.phase;

  test('sugere o nome do aparelho informado pelo sistema', () async {
    final ChildLinkingBloc bloc = await build();

    expect(bloc.state, isA<ChildLinkingForm>());
    expect(bloc.state.suggestedDeviceName, 'Moto G de João');
  });

  test('codigo aceito passa a esperar a aprovacao e guarda o pedido', () async {
    final ChildLinkingBloc bloc = await build();

    await submit(bloc, code: 'ab2d-9xyz', name: ' Celular do João ');

    final ChildLinkingState state = bloc.state;
    expect(state, isA<ChildLinkingWaiting>());
    expect((state as ChildLinkingWaiting).claim.confirmCode, '4821');
    final http.Request claim = backend.calls('POST', _claimPath).single;
    expect(claim.headers.containsKey('Authorization'), isFalse);
    final Map<String, Object?> body = backend.lastBody('POST', _claimPath);
    expect(body['code'], 'AB2D9XYZ');
    final Map<String, Object?> device = body['device']! as Map<String, Object?>;
    expect(device['name'], 'Celular do João');
    expect(device['hardwareId'], 'abc123');
    expect(device['timezone'], 'America/Fortaleza');
    expect(await store.read(StorageKeys.childPendingClaim), contains('pp_token'));
  });

  test('aprovacao ativa o agente com as credenciais e a politica', () async {
    final ChildLinkingBloc bloc = await build();
    await submit(bloc);

    backend.on('GET', _statusPath, (http.Request request) {
      expect(request.headers['Authorization'], 'Bearer pp_token');
      return jsonResponse(<String, Object?>{
        'status': 'approved',
        'credentials': <String, Object?>{
          'deviceId': 'dev-1',
          'deviceToken': 'dv_secret',
          'offlineSecret': 'GEZDGNBV',
        },
        'childName': 'João',
        'guardianName': 'Maria',
        'policyVersion': 7,
        'policy': <String, Object?>{'schema': 1, 'timezone': 'America/Fortaleza'},
      });
    });
    await poll(bloc);

    final VerificationResult call = verify(
      () => bridge.agent.activate(captureAny(), captureAny(), captureAny()),
    )..called(1);
    final ChildCredentials credentials = call.captured[0] as ChildCredentials;
    expect(credentials.serverUrl, 'https://servidor.teste');
    expect(credentials.deviceId, 'dev-1');
    expect(credentials.deviceToken, 'dv_secret');
    expect(credentials.offlineSecret, 'GEZDGNBV');
    expect(credentials.childName, 'João');
    expect(call.captured[1], 7);
    expect(jsonDecode(call.captured[2] as String), <String, Object?>{
      'schema': 1,
      'timezone': 'America/Fortaleza',
    });
    expect(phase(), LinkPhase.onboarding);
    expect(await store.read(StorageKeys.childPendingClaim), isNull);
  });

  test('pedido pendente continua esperando', () async {
    final ChildLinkingBloc bloc = await build();
    await submit(bloc);

    backend.onJson('GET', _statusPath, <String, Object?>{'status': 'pending'});
    await poll(bloc);

    expect(bloc.state, isA<ChildLinkingWaiting>());
    verifyNever(() => bridge.agent.activate(any(), any(), any()));
  });

  test('rejeicao e vencimento voltam ao formulario com a explicacao', () async {
    for (final String status in <String>['rejected', 'expired']) {
      final ChildLinkingBloc bloc = await build();
      await submit(bloc);

      backend.onJson('GET', _statusPath, <String, Object?>{'status': status});
      await poll(bloc);

      final ChildLinkingState state = bloc.state;
      expect(state, isA<ChildLinkingForm>(), reason: status);
      expect(
        (state as ChildLinkingForm).error,
        contains(status == 'rejected' ? 'não aprovou' : 'venceu'),
      );
      expect(await store.read(StorageKeys.childPendingClaim), isNull);
    }
  });

  test('token de consulta recusado e tratado como pedido vencido', () async {
    final ChildLinkingBloc bloc = await build();
    await submit(bloc);

    backend.onError('GET', _statusPath, status: 401, code: 'unauthorized');
    await poll(bloc);

    expect((bloc.state as ChildLinkingForm).error, contains('venceu'));
  });

  test('erros do pedido viram mensagens claras', () async {
    final Map<http.Response, String> cases = <http.Response, String>{
      errorResponse(401, 'invalid_credentials'): 'Código incorreto',
      errorResponse(410, 'code_expired'): 'venceu ou já foi usado',
      errorResponse(429, 'rate_limited', details: <String, Object?>{'retryAfterSec': 300}):
          'Tente de novo em 5min',
    };
    for (final MapEntry<http.Response, String> entry in cases.entries) {
      backend.on('POST', _claimPath, (http.Request request) => entry.key);
      final ChildLinkingBloc bloc = await build();

      await submit(bloc);

      expect((bloc.state as ChildLinkingForm).error, contains(entry.value));
    }
  });

  test('codigo incompleto e nome vazio nem chegam ao servidor', () async {
    final ChildLinkingBloc bloc = await build();

    await submit(bloc, code: 'AB2D');
    expect((bloc.state as ChildLinkingForm).error, contains('completo'));
    await submit(bloc, name: '  ');
    expect((bloc.state as ChildLinkingForm).error, contains('nome'));

    expect(backend.calls('POST', _claimPath), isEmpty);
  });

  test('falta de rede durante a espera avisa e continua esperando', () async {
    final ChildLinkingBloc bloc = await build();
    await submit(bloc);

    backend.on('GET', _statusPath, (http.Request request) {
      throw const SocketException('sem rede');
    });
    await poll(bloc);
    expect((bloc.state as ChildLinkingWaiting).connectionTrouble, isTrue);

    backend.onJson('GET', _statusPath, <String, Object?>{'status': 'pending'});
    await poll(bloc);
    expect((bloc.state as ChildLinkingWaiting).connectionTrouble, isFalse);
  });

  test('pedido guardado e retomado ao reabrir a tela', () async {
    await store.write(StorageKeys.childPendingClaim, jsonEncode(_claimBody));
    backend.onJson('GET', _statusPath, <String, Object?>{'status': 'pending'});

    final ChildLinkingBloc bloc = await build();

    expect(bloc.state, isA<ChildLinkingWaiting>());
    expect(backend.calls('GET', _statusPath), hasLength(1));
  });

  test('desistir do pedido volta ao formulario e esquece o pedido guardado', () async {
    final ChildLinkingBloc bloc = await build();
    await submit(bloc);

    bloc.add(const ChildLinkingWaitCancelled());
    await pumpEventQueue();

    expect(bloc.state, isA<ChildLinkingForm>());
    expect(await store.read(StorageKeys.childPendingClaim), isNull);
  });

  test('falha ao ligar o agente volta ao formulario e pede novo codigo', () async {
    when(() => bridge.agent.activate(any(), any(), any()))
        .thenThrow(PlatformException(code: 'IllegalStateException', details: 'Cause: null'));
    final ChildLinkingBloc bloc = await build();
    await submit(bloc);

    backend.onJson('GET', _statusPath, <String, Object?>{
      'status': 'approved',
      'credentials': <String, Object?>{'deviceId': 'd', 'deviceToken': 't', 'offlineSecret': 's'},
      'policyVersion': 1,
      'policy': <String, Object?>{'timezone': 'UTC'},
    });
    await poll(bloc);

    expect((bloc.state as ChildLinkingForm).error, contains('Peça um novo código'));
    expect(phase(), LinkPhase.unknown);
  });

  test('voltar para a escolha de modo troca o perfil do app', () async {
    final ChildLinkingBloc bloc = await build();

    bloc.add(const ChildLinkingLeaveRequested());
    await pumpEventQueue();

    verify(() => bridge.mode.setMode(AppMode.unset)).called(1);
    expect((bloc.state as ChildLinkingForm).leaveFailure, isNull);
  });
}
