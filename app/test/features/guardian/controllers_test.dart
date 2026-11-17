import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/features/guardian/alerts/data/api_alerts_repository.dart';
import 'package:parentalynx/features/guardian/alerts/presentation/alerts_controller.dart';
import 'package:parentalynx/features/guardian/devices/presentation/devices_providers.dart';
import 'package:parentalynx/features/guardian/pairing/presentation/pairing_controller.dart';
import 'package:parentalynx/features/guardian/settings/data/api_account_repository.dart';
import 'package:parentalynx/features/guardian/settings/domain/account_repository.dart';
import 'package:parentalynx/features/guardian/time_requests/data/api_time_requests_repository.dart';
import 'package:parentalynx/features/guardian/time_requests/domain/time_request.dart';
import 'package:parentalynx/features/guardian/time_requests/presentation/time_requests_controller.dart';

import 'support/guardian_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBackend backend;
  late NativeDoubles native;

  ProviderContainer build() {
    final ProviderContainer container = ProviderContainer(
      overrides: guardianOverrides(backend: backend, native: native, sessionToken: 'gs_x'),
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    backend = FakeBackend();
    native = NativeDoubles();
    backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{
      'devices': <Object?>[deviceJson(pendingTimeRequests: 1)],
    });
  });

  group('PairingController', () {
    void activeIs({String? codeId, List<Object?> pending = const <Object?>[]}) {
      backend.onJson('GET', '/v1/guardian/pairing-codes/active', <String, Object?>{
        'code': codeId == null ? null : <String, Object?>{'id': codeId, 'expiresAt': 900000},
        'pending': pending,
      });
    }

    setUp(() {
      backend.onJson('POST', '/v1/guardian/pairing-codes', <String, Object?>{
        'id': 'c1',
        'code': 'AB2D9XYZ',
        'expiresAt': 900000,
      }, status: 201);
    });

    test('gera o codigo e o mantem enquanto o servidor o considera ativo', () async {
      activeIs(codeId: 'c1');
      final ProviderContainer container = build();
      final PairingController controller = container.read(pairingProvider.notifier);

      await controller.generate();
      await controller.poll();

      final PairingState state = container.read(pairingProvider);
      expect(state.code?.code, 'AB2D9XYZ');
      expect(state.loaded, isTrue);
      expect(state.pending, isEmpty);
    });

    test('codigo usado sai da tela e o pedido pendente aparece', () async {
      final ProviderContainer container = build();
      final PairingController controller = container.read(pairingProvider.notifier);
      await controller.generate();
      activeIs(
        pending: <Object?>[deviceJson(id: 'p1', status: 'pending', confirmCode: '4821')],
      );

      await controller.poll();

      final PairingState state = container.read(pairingProvider);
      expect(state.code, isNull);
      expect(state.pending.single.confirmCode, '4821');
    });

    test('codigo ativo gerado em outra sessao e sinalizado, sem texto', () async {
      activeIs(codeId: 'outro');
      final ProviderContainer container = build();

      await container.read(pairingProvider.notifier).poll();

      final PairingState state = container.read(pairingProvider);
      expect(state.code, isNull);
      expect(state.otherCodeExpiresAt, 900000);
    });

    test('consulta iniciada antes de gerar nao apaga o codigo novo', () async {
      final Completer<http.Response> slow = Completer<http.Response>();
      backend.on('GET', '/v1/guardian/pairing-codes/active', (_) => slow.future);
      final ProviderContainer container = build();
      final PairingController controller = container.read(pairingProvider.notifier);

      final Future<void> poll = controller.poll();
      await controller.generate();
      slow.complete(jsonResponse(<String, Object?>{'code': null, 'pending': <Object?>[]}));
      await poll;

      expect(container.read(pairingProvider).code?.id, 'c1');
    });

    test('aprovar envia o nome da crianca e guarda o aparelho aprovado', () async {
      activeIs(
        pending: <Object?>[deviceJson(id: 'p1', status: 'pending', confirmCode: '4821')],
      );
      backend.onJson('POST', '/v1/guardian/devices/p1/approve', <String, Object?>{
        'device': deviceJson(id: 'p1', childName: 'Ana'),
      });
      final ProviderContainer container = build();
      final PairingController controller = container.read(pairingProvider.notifier);
      await controller.poll();

      await controller.approve('p1', childName: 'Ana');

      final PairingState state = container.read(pairingProvider);
      expect(backend.lastBody('POST', '/v1/guardian/devices/p1/approve')['childName'], 'Ana');
      expect(state.pending, isEmpty);
      expect(state.approved?.childName, 'Ana');
      controller.dismissApproved();
      expect(container.read(pairingProvider).approved, isNull);
    });

    test('elevacao exigida chega a quem chamou, para pedir a senha', () async {
      backend.onError(
        'POST',
        '/v1/guardian/pairing-codes',
        status: 403,
        code: 'elevation_required',
      );
      final ProviderContainer container = build();

      await expectLater(
        container.read(pairingProvider.notifier).generate(),
        throwsA(
          isA<ApiFailure>().having((ApiFailure f) => f.isElevationRequired, 'elevacao', isTrue),
        ),
      );
    });
  });

  group('AlertsController', () {
    List<Object?> alerts(int from, int count) {
      return <Object?>[for (int i = 0; i < count; i++) alertJson(id: from - i)];
    }

    test('carrega a primeira pagina, o selo e avisa o lado nativo', () async {
      backend.onJson('GET', '/v1/guardian/alerts', <String, Object?>{
        'alerts': alerts(40, 30),
        'latestId': 40,
        'unread': 5,
      });
      final ProviderContainer container = build();

      final AlertsState state = await container.read(alertsProvider.future);

      expect(state.alerts, hasLength(30));
      expect(state.hasMore, isTrue);
      expect(container.read(unreadAlertsProvider), 5);
      verify(() => native.guardian.setLastSeenAlertId(40)).called(1);
    });

    test('carrega mais antigos a partir do ultimo e para quando acaba', () async {
      backend.on('GET', '/v1/guardian/alerts', (http.Request request) {
        final String? before = request.url.queryParameters['before'];
        return jsonResponse(<String, Object?>{
          'alerts': before == null ? alerts(40, 30) : alerts(10, 4),
          'latestId': 40,
          'unread': 0,
        });
      });
      final ProviderContainer container = build();
      await container.read(alertsProvider.future);

      await container.read(alertsProvider.notifier).loadMore();

      final AlertsState state = container.read(alertsProvider).requireValue;
      expect(state.alerts, hasLength(34));
      expect(state.hasMore, isFalse);
      expect(backend.calls('GET', '/v1/guardian/alerts').last.url.queryParameters['before'], '11');
    });

    test('marcar como lido atualiza a lista e o selo', () async {
      backend.onJson('GET', '/v1/guardian/alerts', <String, Object?>{
        'alerts': alerts(3, 3),
        'latestId': 3,
        'unread': 3,
      });
      backend.onJson('POST', '/v1/guardian/alerts/read', <String, Object?>{'unread': 2});
      final ProviderContainer container = build();
      await container.read(alertsProvider.future);

      await container.read(alertsProvider.notifier).markRead(3);

      final AlertsState state = container.read(alertsProvider).requireValue;
      expect(state.alerts.first.isRead, isTrue);
      expect(state.alerts.last.isRead, isFalse);
      expect(container.read(unreadAlertsProvider), 2);
      expect(backend.lastBody('POST', '/v1/guardian/alerts/read')['ids'], <Object?>[3]);

      backend.onJson('POST', '/v1/guardian/alerts/read', <String, Object?>{'unread': 0});
      await container.read(alertsProvider.notifier).markAllRead();
      expect(backend.lastBody('POST', '/v1/guardian/alerts/read')['all'], isTrue);
      expect(container.read(alertsProvider).requireValue.alerts.every((a) => a.isRead), isTrue);
      expect(container.read(unreadAlertsProvider), 0);
    });
  });

  group('pedidos de tempo e conta', () {
    test('lista os pedidos dos aparelhos ativos e resolve com os minutos', () async {
      backend.onJson('GET', '/v1/guardian/devices/d1/time-requests', <String, Object?>{
        'requests': <Object?>[
          <String, Object?>{
            'id': 'r1',
            'deviceId': 'd1',
            'childName': 'João',
            'createdAt': 10,
            'minutes': 30,
            'message': 'Falta pouco para acabar o filme',
            'status': 'pending',
          },
        ],
      });
      backend.onJson('POST', '/v1/guardian/time-requests/r1/resolve', <String, Object?>{
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
      final ProviderContainer container = build();
      await container.read(devicesProvider.future);

      final List<TimeRequest> requests = await container.read(timeRequestsProvider.future);
      expect(requests.single.isPending, isTrue);
      expect(container.read(pendingTimeRequestsCountProvider), 1);

      final TimeRequest resolved = await container
          .read(timeRequestsProvider.notifier)
          .resolve('r1', approve: true, minutes: 45);

      expect(resolved.status, TimeRequestStatus.approved);
      expect(backend.lastBody('POST', '/v1/guardian/time-requests/r1/resolve'), <String, Object?>{
        'action': 'approve',
        'minutes': 45,
      });
      expect(container.read(timeRequestsProvider).requireValue.single.grantedMinutes, 45);
    });

    test('negar nao envia minutos', () async {
      backend.onJson('POST', '/v1/guardian/time-requests/r1/resolve', <String, Object?>{
        'request': <String, Object?>{'id': 'r1', 'status': 'denied'},
      });
      final ProviderContainer container = build();

      await container.read(timeRequestsRepositoryProvider).resolve('r1', approve: false);

      expect(backend.lastBody('POST', '/v1/guardian/time-requests/r1/resolve'), <String, Object?>{
        'action': 'deny',
      });
    });

    test('preferencias de notificacao e ajustes da conta usam as rotas do protocolo', () async {
      backend.on('PUT', '/v1/guardian/notification-prefs', (http.Request request) {
        return jsonResponse(<String, Object?>{
          'notificationPrefs': <String, Object?>{'low_time': true, 'limit_reached': false},
        });
      });
      backend.onJson('PATCH', '/v1/guardian/me', <String, Object?>{
        'guardian': guardianJson(displayName: 'Maria S.'),
      });
      backend.onJson('GET', '/v1/guardian/audit', <String, Object?>{
        'entries': <Object?>[
          <String, Object?>{'id': 5, 'at': 1, 'action': 'policy.update', 'summary': 'Limite 2h'},
        ],
        'nextBefore': 5,
      });
      backend.on('DELETE', '/v1/guardian/account', (_) => http.Response('', 204));
      final ProviderContainer container = build();

      final Map<String, bool> prefs = await container
          .read(alertsRepositoryProvider)
          .updateNotificationPrefs(<String, bool>{'low_time': true});
      expect(prefs, <String, bool>{'low_time': true, 'limit_reached': false});

      final AccountRepository account = container.read(accountRepositoryProvider);
      expect((await account.updateProfile(displayName: 'Maria S.')).displayName, 'Maria S.');
      expect(backend.lastBody('PATCH', '/v1/guardian/me'), <String, Object?>{
        'displayName': 'Maria S.',
      });

      final AuditPage page = await account.audit();
      expect(page.entries.single.summary, 'Limite 2h');
      expect(page.nextBefore, 5);

      await account.deleteAccount('Girassol-azul-42');
      expect(backend.lastBody('DELETE', '/v1/guardian/account')['password'], 'Girassol-azul-42');
    });
  });
}
