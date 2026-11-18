import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/bloc/action_status.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/notifications/domain/entities/alert_type.dart';
import 'package:parentalynx/features/notifications/domain/entities/notification_preferences.dart';
import 'package:parentalynx/features/notifications/domain/usecases/update_notification_preference.dart';
import 'package:parentalynx/features/notifications/domain/usecases/watch_notification_preferences.dart';
import 'package:parentalynx/features/notifications/presentation/bloc/notification_prefs/notification_prefs_bloc.dart';

import '../support/notification_fakes.dart';

void main() {
  const Map<String, bool> initial = <String, bool>{'limit_reached': true, 'low_time': false};

  late MockAlertsRepository alerts;
  late FakeCurrentAccount account;

  setUpAll(() => registerFallbackValue(<String, bool>{}));

  setUp(() {
    alerts = MockAlertsRepository();
    account = FakeCurrentAccount(accountWithPrefs(initial));
  });

  NotificationPrefsBloc build() {
    return NotificationPrefsBloc(
      watchPreferences: WatchNotificationPreferences(account),
      updatePreference: UpdateNotificationPreference(alerts: alerts, account: account),
    );
  }

  blocTest<NotificationPrefsBloc, NotificationPrefsState>(
    'mostra as preferencias da conta',
    build: build,
    act: (NotificationPrefsBloc bloc) => bloc.add(const NotificationPrefsStarted()),
    expect: () => const <NotificationPrefsState>[
      NotificationPrefsState(preferences: NotificationPreferences(initial)),
    ],
  );

  blocTest<NotificationPrefsBloc, NotificationPrefsState>(
    'sem o painel aberto nao ha preferencias para mostrar',
    setUp: () => account.signOut(),
    build: build,
    act: (NotificationPrefsBloc bloc) => bloc.add(const NotificationPrefsStarted()),
    expect: () => const <NotificationPrefsState>[NotificationPrefsState()],
  );

  test('alternar mostra a mudanca na hora e trava o interruptor ate a resposta', () async {
    final Completer<Result<Map<String, bool>>> server = Completer<Result<Map<String, bool>>>();
    when(() => alerts.updateNotificationPrefs(any())).thenAnswer((_) => server.future);
    final NotificationPrefsBloc bloc = build()..add(const NotificationPrefsStarted());
    addTearDown(bloc.close);
    await pumpEventQueue();

    bloc
      ..add(const NotificationPreferenceToggled(AlertType.lowTime, enabled: true))
      // Um segundo toque no mesmo interruptor durante a gravacao e ignorado.
      ..add(const NotificationPreferenceToggled(AlertType.lowTime, enabled: true));
    await pumpEventQueue();

    expect(bloc.state.saving, <AlertType>{AlertType.lowTime});
    expect(bloc.state.preferences!.notifies(AlertType.lowTime), isTrue);
    expect(bloc.state.action, const ActionRunning());

    server.complete(
      const Ok<Map<String, bool>>(<String, bool>{'limit_reached': true, 'low_time': true}),
    );
    await pumpEventQueue();

    expect(bloc.state.saving, isEmpty);
    expect(bloc.state.action, const ActionIdle());
    expect(bloc.state.preferences!.notifies(AlertType.lowTime), isTrue);
    verify(() => alerts.updateNotificationPrefs(any())).called(1);
  });

  blocTest<NotificationPrefsBloc, NotificationPrefsState>(
    'recusa do servidor desfaz a mudanca e avisa',
    setUp: () {
      when(() => alerts.updateNotificationPrefs(any())).thenAnswer((_) async {
        return const Err<Map<String, bool>>(NetworkFailure());
      });
    },
    build: build,
    act: (NotificationPrefsBloc bloc) async {
      bloc.add(const NotificationPrefsStarted());
      await pumpEventQueue();
      bloc.add(const NotificationPreferenceToggled(AlertType.limitReached, enabled: false));
    },
    verify: (NotificationPrefsBloc bloc) {
      expect(bloc.state.preferences, const NotificationPreferences(initial));
      expect(bloc.state.saving, isEmpty);
      expect(bloc.state.action, const ActionFailed(NetworkFailure()));
    },
  );
}
