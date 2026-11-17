import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/platform/native_api.g.dart';
import 'package:parentalynx/core/storage/secure_store.dart';
import 'package:parentalynx/features/child/agent/presentation/child_session.dart';
import 'package:parentalynx/features/child/linking/data/pairing_repository.dart';
import 'package:parentalynx/features/child/linking/presentation/linking_controller.dart';

import 'support/child_fakes.dart';

const Map<String, Object?> _claimBody = <String, Object?>{
  'linkId': 'link-1',
  'pollToken': 'pp_token',
  'confirmCode': '4821',
  'guardianName': 'Maria',
  'expiresAt': 1790000000000,
};

void main() {
  late ChildBridge bridge;
  late InMemorySecureStore store;
  late List<http.Request> requests;
  late http.Response Function(http.Request request) respond;

  setUpAll(registerChildFallbacks);

  setUp(() {
    bridge = ChildBridge();
    store = InMemorySecureStore();
    requests = <http.Request>[];
    respond = (http.Request request) => jsonResponse(_claimBody, 201);
    when(() => bridge.agent.activate(any(), any(), any())).thenAnswer((_) async {});
  });

  ProviderContainer build() {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        ...bridge.overrides(
          secureStore: store,
          httpClient: MockClient((http.Request request) async {
            requests.add(request);
            return respond(request);
          }),
        ),
        // O temporizador nao dispara nos testes: a consulta e chamada a mao.
        pairingPollIntervalProvider.overrideWithValue(const Duration(hours: 1)),
      ],
    );
    addTearDown(container.dispose);
    container.listen<LinkingState>(linkingControllerProvider, (_, _) {});
    return container;
  }

  Future<LinkingController> ready(ProviderContainer container) async {
    final LinkingController controller = container.read(linkingControllerProvider.notifier);
    await pumpEventQueue();
    return controller;
  }

  test('codigo aceito passa a esperar a aprovacao e guarda o pedido', () async {
    final ProviderContainer container = build();
    final LinkingController controller = await ready(container);

    await controller.submit(code: 'ab2d-9xyz', deviceName: ' Celular do João ');

    final LinkingState state = container.read(linkingControllerProvider);
    expect(state, isA<LinkingWaiting>());
    expect((state as LinkingWaiting).claim.confirmCode, '4821');
    final http.Request claim = requests.single;
    expect(claim.url.path, '/v1/pairing/claim');
    expect(claim.headers.containsKey('Authorization'), isFalse);
    final Map<String, Object?> body = jsonDecode(claim.body) as Map<String, Object?>;
    expect(body['code'], 'AB2D9XYZ');
    final Map<String, Object?> device = body['device']! as Map<String, Object?>;
    expect(device['name'], 'Celular do João');
    expect(device['hardwareId'], 'abc123');
    expect(device['timezone'], 'America/Fortaleza');
    expect(await store.read(SecurePendingClaimStore.key), contains('pp_token'));
  });

  test('aprovacao ativa o agente com as credenciais e a politica', () async {
    final ProviderContainer container = build();
    final LinkingController controller = await ready(container);
    await controller.submit(code: 'AB2D9XYZ', deviceName: 'Celular');

    respond = (http.Request request) {
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
    };
    await controller.pollNow();

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
    expect(container.read(childLinkProvider), ChildLinkPhase.onboarding);
    expect(await store.read(SecurePendingClaimStore.key), isNull);
  });

  test('pedido pendente continua esperando', () async {
    final ProviderContainer container = build();
    final LinkingController controller = await ready(container);
    await controller.submit(code: 'AB2D9XYZ', deviceName: 'Celular');

    respond = (http.Request request) => jsonResponse(<String, Object?>{'status': 'pending'});
    await controller.pollNow();

    expect(container.read(linkingControllerProvider), isA<LinkingWaiting>());
    verifyNever(() => bridge.agent.activate(any(), any(), any()));
  });

  test('rejeicao e vencimento voltam ao formulario com a explicacao', () async {
    for (final String status in <String>['rejected', 'expired']) {
      final ProviderContainer container = build();
      final LinkingController controller = await ready(container);
      respond = (http.Request request) => jsonResponse(_claimBody, 201);
      await controller.submit(code: 'AB2D9XYZ', deviceName: 'Celular');

      respond = (http.Request request) => jsonResponse(<String, Object?>{'status': status});
      await controller.pollNow();

      final LinkingState state = container.read(linkingControllerProvider);
      expect(state, isA<LinkingForm>(), reason: status);
      expect(
        (state as LinkingForm).error,
        contains(status == 'rejected' ? 'não aprovou' : 'venceu'),
      );
      expect(await store.read(SecurePendingClaimStore.key), isNull);
    }
  });

  test('token de consulta recusado e tratado como pedido vencido', () async {
    final ProviderContainer container = build();
    final LinkingController controller = await ready(container);
    await controller.submit(code: 'AB2D9XYZ', deviceName: 'Celular');

    respond = (http.Request request) => errorResponse(401, 'unauthorized');
    await controller.pollNow();

    final LinkingState state = container.read(linkingControllerProvider);
    expect((state as LinkingForm).error, contains('venceu'));
  });

  test('erros do pedido viram mensagens claras', () async {
    final Map<http.Response, String> cases = <http.Response, String>{
      errorResponse(401, 'invalid_credentials'): 'Código incorreto',
      errorResponse(410, 'code_expired'): 'venceu ou já foi usado',
      errorResponse(429, 'rate_limited', details: <String, Object?>{'retryAfterSec': 300}):
          'Tente de novo em 5min',
    };
    for (final MapEntry<http.Response, String> entry in cases.entries) {
      final ProviderContainer container = build();
      final LinkingController controller = await ready(container);
      respond = (http.Request request) => entry.key;

      await controller.submit(code: 'AB2D9XYZ', deviceName: 'Celular');

      final LinkingState state = container.read(linkingControllerProvider);
      expect((state as LinkingForm).error, contains(entry.value));
    }
  });

  test('codigo incompleto e nome vazio nem chegam ao servidor', () async {
    final ProviderContainer container = build();
    final LinkingController controller = await ready(container);

    await controller.submit(code: 'AB2D', deviceName: 'Celular');
    expect((container.read(linkingControllerProvider) as LinkingForm).error, contains('completo'));
    await controller.submit(code: 'AB2D9XYZ', deviceName: '  ');
    expect((container.read(linkingControllerProvider) as LinkingForm).error, contains('nome'));

    expect(requests, isEmpty);
  });

  test('falta de rede durante a espera avisa e continua esperando', () async {
    final ProviderContainer container = build();
    final LinkingController controller = await ready(container);
    await controller.submit(code: 'AB2D9XYZ', deviceName: 'Celular');

    respond = (http.Request request) => throw const SocketException('sem rede');
    await controller.pollNow();
    expect((container.read(linkingControllerProvider) as LinkingWaiting).connectionTrouble, isTrue);

    respond = (http.Request request) => jsonResponse(<String, Object?>{'status': 'pending'});
    await controller.pollNow();
    expect(
      (container.read(linkingControllerProvider) as LinkingWaiting).connectionTrouble,
      isFalse,
    );
  });

  test('pedido guardado e retomado ao reabrir a tela', () async {
    await store.write(SecurePendingClaimStore.key, jsonEncode(_claimBody));
    respond = (http.Request request) => jsonResponse(<String, Object?>{'status': 'pending'});

    final ProviderContainer container = build();
    await ready(container);

    final LinkingState state = container.read(linkingControllerProvider);
    expect(state, isA<LinkingWaiting>());
    expect(requests.single.url.path, '/v1/pairing/status');
  });

  test('falha ao ligar o agente volta ao formulario e pede novo codigo', () async {
    when(() => bridge.agent.activate(any(), any(), any()))
        .thenThrow(PlatformException(code: 'IllegalStateException', details: 'Cause: null'));
    final ProviderContainer container = build();
    final LinkingController controller = await ready(container);
    await controller.submit(code: 'AB2D9XYZ', deviceName: 'Celular');

    respond = (http.Request request) => jsonResponse(<String, Object?>{
      'status': 'approved',
      'credentials': <String, Object?>{'deviceId': 'd', 'deviceToken': 't', 'offlineSecret': 's'},
      'policyVersion': 1,
      'policy': <String, Object?>{'timezone': 'UTC'},
    });
    await controller.pollNow();

    final LinkingState state = container.read(linkingControllerProvider);
    expect((state as LinkingForm).error, contains('Peça um novo código'));
    expect(container.read(childLinkProvider), ChildLinkPhase.unknown);
  });
}
