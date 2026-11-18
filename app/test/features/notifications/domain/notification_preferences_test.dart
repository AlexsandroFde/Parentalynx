import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/notifications/domain/entities/alert_type.dart';
import 'package:parentalynx/features/notifications/domain/entities/notification_preferences.dart';
import 'package:parentalynx/features/notifications/domain/usecases/update_notification_preference.dart';

import '../support/notification_fakes.dart';

void main() {
  setUpAll(() => registerFallbackValue(<String, bool>{}));

  group('NotificationPreferences', () {
    test('tipo ausente do mapa vale como ligado', () {
      const NotificationPreferences preferences = NotificationPreferences(<String, bool>{
        'low_time': false,
      });

      expect(preferences.notifies(AlertType.lowTime), isFalse);
      expect(preferences.notifies(AlertType.limitReached), isTrue);
    });

    test('trocar um tipo gera o mapa completo com todos os tipos', () {
      const NotificationPreferences preferences = NotificationPreferences(<String, bool>{
        'low_time': false,
      });

      final Map<String, bool> next = preferences
          .withType(AlertType.limitReached, enabled: false)
          .byType;

      expect(next.keys, unorderedEquals(AlertType.values.map((AlertType type) => type.code)));
      expect(next['limit_reached'], isFalse);
      expect(next['low_time'], isFalse);
      expect(next['time_request'], isTrue);
    });

    test('codigo do protocolo vira o tipo', () {
      expect(AlertType.fromCode('blocked_app_attempt'), AlertType.blockedAppAttempt);
      expect(AlertType.fromCode('desconhecido'), isNull);
    });
  });

  group('UpdateNotificationPreference', () {
    late MockAlertsRepository alerts;
    late FakeCurrentAccount account;
    late UpdateNotificationPreference update;
    const Map<String, bool> before = <String, bool>{'limit_reached': true, 'low_time': false};

    setUp(() {
      alerts = MockAlertsRepository();
      account = FakeCurrentAccount(accountWithPrefs(before));
      update = UpdateNotificationPreference(alerts: alerts, account: account);
    });

    test('mostra a mudanca na hora e adota o mapa devolvido pelo servidor', () async {
      final Completer<Result<Map<String, bool>>> server = Completer<Result<Map<String, bool>>>();
      when(() => alerts.updateNotificationPrefs(any())).thenAnswer((_) => server.future);

      final Future<Result<Map<String, bool>>> pending = update(AlertType.lowTime, enabled: true);
      await pumpEventQueue();

      // Antes da resposta a conta ja mostra a escolha nova.
      expect(account.currentAccount!.notificationPrefs['low_time'], isTrue);
      final Map<String, bool> sent =
          verify(() => alerts.updateNotificationPrefs(captureAny())).captured.single
              as Map<String, bool>;
      expect(sent.keys, unorderedEquals(AlertType.values.map((AlertType type) => type.code)));
      expect(sent['low_time'], isTrue);
      expect(sent['limit_reached'], isTrue);

      const Map<String, bool> accepted = <String, bool>{'low_time': true, 'limit_reached': true};
      server.complete(const Ok<Map<String, bool>>(accepted));

      expect((await pending).valueOrNull, accepted);
      expect(account.currentAccount!.notificationPrefs, accepted);
    });

    test('recusa do servidor desfaz a mudanca', () async {
      when(() => alerts.updateNotificationPrefs(any())).thenAnswer((_) async {
        return const Err<Map<String, bool>>(NetworkFailure());
      });

      final Result<Map<String, bool>> result = await update(AlertType.lowTime, enabled: true);

      expect(result.failureOrNull, const NetworkFailure());
      expect(account.currentAccount!.notificationPrefs, before);
    });

    test('sem o painel aberto nao envia nada', () async {
      account.signOut();

      final Result<Map<String, bool>> result = await update(AlertType.lowTime, enabled: true);

      expect(result.failureOrNull, isA<CancelledFailure>());
      verifyNever(() => alerts.updateNotificationPrefs(any()));
    });
  });
}
