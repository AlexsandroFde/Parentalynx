import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/features/notifications/domain/usecases/check_notification_permission.dart';
import 'package:parentalynx/features/notifications/domain/usecases/open_notification_settings.dart';
import 'package:parentalynx/features/notifications/domain/usecases/request_notification_permission.dart';
import 'package:parentalynx/features/notifications/domain/usecases/should_prompt_for_notifications.dart';
import 'package:parentalynx/features/notifications/presentation/bloc/notification_permission/notification_permission_bloc.dart';

import '../support/notification_fakes.dart';

void main() {
  late MockNotificationPermissionService permission;
  late MockNotificationPromptRepository prompts;

  setUp(() {
    permission = MockNotificationPermissionService();
    prompts = MockNotificationPromptRepository();
    when(permission.isAllowed).thenAnswer((_) async => false);
    when(permission.request).thenAnswer((_) async => true);
    when(permission.openSettings).thenAnswer((_) async {});
    when(prompts.wasPrompted).thenAnswer((_) async => false);
    when(prompts.markPrompted).thenAnswer((_) async {});
  });

  NotificationPermissionBloc build() {
    return NotificationPermissionBloc(
      check: CheckNotificationPermission(permission),
      request: RequestNotificationPermission(permission),
      openSettings: OpenNotificationSettings(permission),
      shouldPrompt: ShouldPromptForNotifications(prompts: prompts, permission: permission),
    );
  }

  blocTest<NotificationPermissionBloc, NotificationPermissionState>(
    'confere a permissao do sistema ao abrir',
    build: build,
    act: (NotificationPermissionBloc bloc) => bloc.add(const NotificationPermissionStarted()),
    expect: () => const <NotificationPermissionState>[
      NotificationPermissionState(status: NotificationPermissionStatus.denied),
    ],
    verify: (NotificationPermissionBloc bloc) => expect(bloc.state.isDenied, isTrue),
  );

  blocTest<NotificationPermissionBloc, NotificationPermissionState>(
    'na primeira vez sem permissao pede a explicacao uma unica vez',
    build: build,
    act: (NotificationPermissionBloc bloc) async {
      bloc.add(const NotificationFirstRunCheckRequested());
      await pumpEventQueue();
      bloc.add(const NotificationFirstRunPromptShown());
    },
    expect: () => const <NotificationPermissionState>[
      NotificationPermissionState(firstRunPrompt: true),
      NotificationPermissionState(),
    ],
    verify: (_) => verify(prompts.markPrompted).called(1),
  );

  blocTest<NotificationPermissionBloc, NotificationPermissionState>(
    'na primeira vez com a permissao ja dada so registra que perguntou',
    setUp: () => when(permission.isAllowed).thenAnswer((_) async => true),
    build: build,
    act: (NotificationPermissionBloc bloc) => bloc.add(const NotificationFirstRunCheckRequested()),
    expect: () => const <NotificationPermissionState>[],
    verify: (_) => verify(prompts.markPrompted).called(1),
  );

  blocTest<NotificationPermissionBloc, NotificationPermissionState>(
    'depois da primeira vez nao pergunta de novo',
    setUp: () => when(prompts.wasPrompted).thenAnswer((_) async => true),
    build: build,
    act: (NotificationPermissionBloc bloc) => bloc.add(const NotificationFirstRunCheckRequested()),
    expect: () => const <NotificationPermissionState>[],
    verify: (_) {
      verifyNever(permission.isAllowed);
      verifyNever(prompts.markPrompted);
    },
  );

  test('pedir a permissao confere de novo no sistema e responde a quem pediu', () async {
    final NotificationPermissionBloc bloc = build();
    addTearDown(bloc.close);
    when(permission.isAllowed).thenAnswer((_) async => true);

    final Completer<bool> granted = Completer<bool>();
    bloc.add(NotificationPermissionRequested(completer: granted));

    expect(await granted.future, isTrue);
    await pumpEventQueue();
    expect(bloc.state.status, NotificationPermissionStatus.allowed);
    verify(permission.request).called(1);
  });

  blocTest<NotificationPermissionBloc, NotificationPermissionState>(
    'abre as configuracoes de notificacao do app',
    build: build,
    act: (NotificationPermissionBloc bloc) => bloc.add(const NotificationSettingsOpened()),
    expect: () => const <NotificationPermissionState>[],
    verify: (_) => verify(permission.openSettings).called(1),
  );
}
