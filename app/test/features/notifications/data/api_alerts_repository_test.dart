import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/notifications/domain/entities/guardian_alert.dart';
import 'package:parentalynx/features/notifications/domain/repositories/i_alerts_repository.dart';
import 'package:parentalynx/features/notifications/notifications_module.dart';

import '../../../support/fake_backend.dart';
import '../../../support/guardian_fixtures.dart';
import '../../../support/test_dependencies.dart';

/// Rotas de alertas e de preferencias de notificacao do protocolo, pelo repositorio real.
void main() {
  const String alertsPath = '/v1/guardian/alerts';
  const String readPath = '/v1/guardian/alerts/read';
  const String prefsPath = '/v1/guardian/notification-prefs';

  late TestDependencies deps;
  late IAlertsRepository repository;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_x');
    registerNotificationsModule(deps.di);
    repository = deps.di<IAlertsRepository>();
  });

  tearDown(() => deps.dispose());

  test('lista os alertas com os filtros do protocolo', () async {
    deps.backend.onJson('GET', alertsPath, <String, Object?>{
      'alerts': <Object?>[alertJson(id: 8, read: true, createdAt: 1000)],
      'latestId': 9,
      'unread': 1,
    });

    final AlertsPage page = (await repository.list(
      after: 5,
      before: 9,
      limit: 10,
      notifyOnly: true,
    )).valueOrNull!;

    expect(deps.backend.calls('GET', alertsPath).single.url.queryParameters, <String, String>{
      'after': '5',
      'before': '9',
      'limit': '10',
      'notifyOnly': '1',
    });
    expect(page.latestId, 9);
    expect(page.unread, 1);
    expect(
      page.alerts.single,
      const GuardianAlert(
        id: 8,
        type: 'limit_reached',
        deviceId: 'd1',
        childName: 'João',
        createdAt: 1000,
        readAt: 10,
        notify: true,
        title: 'Limite diário atingido',
        body: 'João usou as 2h30 de hoje.',
      ),
    );
  });

  test('marcar como lidos envia os ids ou todos e devolve os nao lidos', () async {
    deps.backend.onJson('POST', readPath, <String, Object?>{'unread': 4});

    expect((await repository.markRead(ids: <int>[1, 2])).valueOrNull, 4);
    expect(deps.backend.lastBody('POST', readPath), <String, Object?>{
      'ids': <Object?>[1, 2],
    });

    expect((await repository.markRead(all: true)).valueOrNull, 4);
    expect(deps.backend.lastBody('POST', readPath), <String, Object?>{'all': true});
  });

  test('preferencias de notificacao usam a rota do protocolo', () async {
    deps.backend.on('PUT', prefsPath, (http.Request request) {
      return jsonResponse(<String, Object?>{
        'notificationPrefs': <String, Object?>{'low_time': true, 'limit_reached': false},
      });
    });

    final Result<Map<String, bool>> prefs = await repository.updateNotificationPrefs(<String, bool>{
      'low_time': true,
    });

    expect(prefs.valueOrNull, <String, bool>{'low_time': true, 'limit_reached': false});
    expect(deps.backend.lastBody('PUT', prefsPath), <String, Object?>{'low_time': true});
  });

  test('sem o mapa na resposta, vale o que foi enviado', () async {
    deps.backend.onJson('PUT', prefsPath, <String, Object?>{});

    final Result<Map<String, bool>> prefs = await repository.updateNotificationPrefs(<String, bool>{
      'low_time': false,
    });

    expect(prefs.valueOrNull, <String, bool>{'low_time': false});
  });

  test('erro do servidor vira falha, sem excecao', () async {
    deps.backend.onError('GET', alertsPath, status: 500, code: 'internal');

    final Result<AlertsPage> result = await repository.list();

    expect(result.failureOrNull, isA<ApiFailure>());
  });
}
