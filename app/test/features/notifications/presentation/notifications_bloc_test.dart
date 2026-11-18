import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/features/device_sync/domain/entities/realtime_update.dart';
import 'package:parentalynx/features/notifications/domain/entities/guardian_alert.dart';
import 'package:parentalynx/features/notifications/notifications_module.dart';
import 'package:parentalynx/features/notifications/presentation/bloc/notifications/notifications_bloc.dart';

import '../../../support/fake_backend.dart';
import '../../../support/fakes.dart';
import '../../../support/guardian_fixtures.dart';
import '../../../support/test_dependencies.dart';

/// Central de alertas de ponta a ponta na apresentacao: BLoC, casos de uso e repositorio
/// reais, servidor falso e ponte nativa simulada.
void main() {
  const String alertsPath = '/v1/guardian/alerts';
  const String readPath = '/v1/guardian/alerts/read';

  late TestDependencies deps;

  setUp(() {
    deps = TestDependencies(sessionToken: 'gs_x', clock: FakeClock(DateTime.now()));
    registerNotificationsModule(deps.di);
  });

  tearDown(() => deps.dispose());

  NotificationsBloc build() {
    final NotificationsBloc bloc = deps.di<NotificationsBloc>();
    addTearDown(bloc.close);
    return bloc;
  }

  List<Object?> alerts(int from, int count) {
    return <Object?>[for (int i = 0; i < count; i++) alertJson(id: from - i)];
  }

  Future<NotificationsState> loadedFeed(NotificationsBloc bloc) async {
    bloc.add(const AlertsFeedRequested());
    return bloc.stream.firstWhere((NotificationsState state) => state.feed is AlertsFeedLoaded);
  }

  AlertsFeedLoaded feedOf(NotificationsBloc bloc) => bloc.state.feed as AlertsFeedLoaded;

  test('carrega a primeira pagina, o selo e avisa o lado nativo', () async {
    deps.backend.onJson('GET', alertsPath, <String, Object?>{
      'alerts': alerts(40, 30),
      'latestId': 40,
      'unread': 5,
    });
    final NotificationsBloc bloc = build();

    final NotificationsState state = await loadedFeed(bloc);

    final AlertsFeedLoaded feed = state.feed as AlertsFeedLoaded;
    expect(feed.alerts, hasLength(30));
    expect(feed.hasMore, isTrue);
    expect(state.unread, 5);
    expect(deps.backend.calls('GET', alertsPath).single.url.queryParameters['limit'], '30');
    verify(() => deps.native.guardian.setLastSeenAlertId(40)).called(1);
  });

  test('carrega mais antigos a partir do ultimo e para quando acaba', () async {
    deps.backend.on('GET', alertsPath, (http.Request request) {
      final String? before = request.url.queryParameters['before'];
      return jsonResponse(<String, Object?>{
        'alerts': before == null ? alerts(40, 30) : alerts(10, 4),
        'latestId': 40,
        'unread': 0,
      });
    });
    final NotificationsBloc bloc = build();
    await loadedFeed(bloc);

    bloc.add(const OlderAlertsRequested());
    await bloc.stream.firstWhere((NotificationsState state) {
      final AlertsFeed feed = state.feed;
      return feed is AlertsFeedLoaded && !feed.loadingMore;
    });

    expect(feedOf(bloc).alerts, hasLength(34));
    expect(feedOf(bloc).hasMore, isFalse);
    expect(deps.backend.calls('GET', alertsPath).last.url.queryParameters['before'], '11');
  });

  test('marcar como lido atualiza a lista e o selo', () async {
    deps.backend
      ..onJson('GET', alertsPath, <String, Object?>{
        'alerts': alerts(3, 3),
        'latestId': 3,
        'unread': 3,
      })
      ..onJson('POST', readPath, <String, Object?>{'unread': 2});
    final NotificationsBloc bloc = build();
    await loadedFeed(bloc);

    bloc.add(const AlertReadRequested(3));
    await bloc.stream.firstWhere((NotificationsState state) => state.unread == 2);

    expect(feedOf(bloc).alerts.first.isRead, isTrue);
    expect(feedOf(bloc).alerts.last.isRead, isFalse);
    expect(deps.backend.lastBody('POST', readPath)['ids'], <Object?>[3]);

    deps.backend.onJson('POST', readPath, <String, Object?>{'unread': 0});
    bloc.add(const AllAlertsReadRequested());
    await bloc.stream.firstWhere((NotificationsState state) => state.unread == 0);

    expect(deps.backend.lastBody('POST', readPath)['all'], isTrue);
    expect(feedOf(bloc).alerts.every((GuardianAlert alert) => alert.isRead), isTrue);
  });

  test('alerta em tempo real entra na lista, aumenta o selo e e marcado como visto', () async {
    deps.backend.onJson('GET', alertsPath, <String, Object?>{
      'alerts': alerts(40, 2),
      'latestId': 40,
      'unread': 1,
    });
    final NotificationsBloc bloc = build()..add(const NotificationsStarted());
    await loadedFeed(bloc);
    await pumpEventQueue();
    expect(bloc.state.unread, 1);

    deps.realtime.emit(
      AlertRaised(
        RealtimeAlert(
          id: 41,
          type: 'time_request',
          deviceId: 'd1',
          childName: 'João',
          createdAt: minutesAgo(0),
          notify: true,
          title: 'Pedido de tempo adicional',
          body: 'João pediu mais 30 minutos.',
        ),
      ),
    );
    await bloc.stream.firstWhere((NotificationsState state) => state.lastIncoming != null);
    await pumpEventQueue();

    expect(bloc.state.unread, 2);
    expect(bloc.state.lastIncoming!.id, 41);
    expect(feedOf(bloc).alerts.map((GuardianAlert alert) => alert.id), <int>[41, 40, 39]);
    expect(feedOf(bloc).latestId, 41);
    verify(() => deps.native.guardian.setLastSeenAlertId(41)).called(1);
  });

  test('falha da primeira pagina mostra o erro e atualizar traz a lista', () async {
    deps.backend.onError('GET', alertsPath, status: 500, code: 'internal');
    final NotificationsBloc bloc = build()..add(const AlertsFeedRequested());

    final NotificationsState failed = await bloc.stream.firstWhere(
      (NotificationsState state) => state.feed is AlertsFeedError,
    );
    expect((failed.feed as AlertsFeedError).failure, isA<ApiFailure>());

    deps.backend.onJson('GET', alertsPath, <String, Object?>{
      'alerts': alerts(2, 2),
      'latestId': 2,
      'unread': 0,
    });
    final Completer<void> done = Completer<void>();
    bloc.add(AlertsRefreshRequested(completer: done));
    await done.future;

    expect(feedOf(bloc).alerts, hasLength(2));
    expect(feedOf(bloc).hasMore, isFalse);
  });

  test('atualizar com falha mantem a lista que ja estava na tela', () async {
    deps.backend.onJson('GET', alertsPath, <String, Object?>{
      'alerts': alerts(2, 2),
      'latestId': 2,
      'unread': 0,
    });
    final NotificationsBloc bloc = build();
    await loadedFeed(bloc);

    deps.backend.onError('GET', alertsPath, status: 500, code: 'internal');
    final Completer<void> done = Completer<void>();
    bloc.add(AlertsRefreshRequested(completer: done));
    await done.future;

    expect(feedOf(bloc).alerts, hasLength(2));
  });
}
