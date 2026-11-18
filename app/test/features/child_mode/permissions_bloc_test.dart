import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/bloc/action_status.dart';
import 'package:parentalynx/features/child_mode/domain/entities/permission_step.dart';
import 'package:parentalynx/features/child_mode/presentation/bloc/permissions/permissions_bloc.dart';
import 'package:parentalynx/features/device_linking/domain/entities/link_state.dart';
import 'package:parentalynx/features/device_linking/domain/repositories/i_link_state_repository.dart';

import '../../support/test_dependencies.dart';
import 'support/child_fakes.dart';

void main() {
  late TestDependencies deps;
  late ChildBridge bridge;

  setUpAll(registerChildFallbacks);

  setUp(() {
    (:deps, :bridge) = childDependencies();
    addTearDown(deps.dispose);
    when(bridge.device.openAccessibilitySettings).thenAnswer((_) async {});
    when(bridge.device.openNotificationSettings).thenAnswer((_) async {});
    when(bridge.device.openAppDetailsSettings).thenAnswer((_) async {});
  });

  PermissionsBloc build() => deps.di<PermissionsBloc>()..add(const PermissionsLoadRequested());

  PermissionsLoaded loaded(PermissionsBloc bloc) => bloc.state as PermissionsLoaded;

  blocTest<PermissionsBloc, PermissionsState>(
    'monta os passos com o fabricante do aparelho',
    setUp: () {
      bridge.permissions = fakePermissions(accessibility: false);
      when(bridge.device.getDeviceInfo)
          .thenAnswer((_) async => fakeDeviceInfo(manufacturer: 'Xiaomi'));
    },
    build: build,
    verify: (PermissionsBloc bloc) {
      expect(loaded(bloc).plan.manufacturer, 'Xiaomi');
      expect(loaded(bloc).plan.steps.last.kind, PermissionKind.autostart);
      expect(loaded(bloc).plan.next!.kind, PermissionKind.accessibility);
    },
  );

  blocTest<PermissionsBloc, PermissionsState>(
    'sem o fabricante so o passo de inicio automatico deixa de aparecer',
    setUp: () {
      when(bridge.device.getDeviceInfo).thenThrow(PlatformException(code: 'channel-error'));
    },
    build: build,
    verify: (PermissionsBloc bloc) {
      expect(loaded(bloc).plan.manufacturer, '');
      expect(
        loaded(bloc).plan.steps.any((PermissionStep s) => s.kind == PermissionKind.autostart),
        isFalse,
      );
    },
  );

  blocTest<PermissionsBloc, PermissionsState>(
    'falha ao ler as permissoes mostra o erro',
    setUp: () {
      when(bridge.device.getPermissions).thenThrow(PlatformException(code: 'channel-error'));
    },
    build: build,
    expect: () => <Matcher>[isA<PermissionsLoadFailure>()],
  );

  blocTest<PermissionsBloc, PermissionsState>(
    'abrir um passo marca o botao em andamento e abre a tela do sistema',
    build: build,
    act: (PermissionsBloc bloc) async {
      await pumpEventQueue();
      bloc.add(const PermissionsStepOpened(PermissionKind.accessibility));
    },
    skip: 1,
    expect: () => <Matcher>[
      isA<PermissionsLoaded>()
          .having((PermissionsLoaded s) => s.opening, 'opening', PermissionKind.accessibility)
          .having((PermissionsLoaded s) => s.action, 'action', isA<ActionRunning>()),
      isA<PermissionsLoaded>()
          .having((PermissionsLoaded s) => s.opening, 'opening', isNull)
          .having((PermissionsLoaded s) => s.action, 'action', const ActionSucceeded()),
    ],
    verify: (_) => verify(bridge.device.openAccessibilitySettings).called(1),
  );

  blocTest<PermissionsBloc, PermissionsState>(
    'notificacoes concedidas na hora relem as permissoes',
    setUp: () {
      bridge.permissions = fakePermissions(notifications: false);
      when(bridge.device.requestNotificationPermission).thenAnswer((_) async {
        bridge.permissions = fakePermissions();
        return true;
      });
    },
    build: build,
    act: (PermissionsBloc bloc) async {
      await pumpEventQueue();
      bloc.add(const PermissionsStepOpened(PermissionKind.notifications));
    },
    verify: (PermissionsBloc bloc) {
      expect(loaded(bloc).plan.isComplete, isTrue);
      verifyNever(bridge.device.openNotificationSettings);
    },
  );

  blocTest<PermissionsBloc, PermissionsState>(
    'notificacoes recusadas antes abrem as configuracoes',
    setUp: () {
      bridge.permissions = fakePermissions(notifications: false);
      when(bridge.device.requestNotificationPermission).thenAnswer((_) async => false);
    },
    build: build,
    act: (PermissionsBloc bloc) async {
      await pumpEventQueue();
      bloc.add(const PermissionsStepOpened(PermissionKind.notifications));
    },
    verify: (_) => verify(bridge.device.openNotificationSettings).called(1),
  );

  blocTest<PermissionsBloc, PermissionsState>(
    'fabricante sem tela de inicio automatico conhecida abre as informacoes do app',
    setUp: () {
      when(bridge.device.openManufacturerAutostartSettings).thenAnswer((_) async => false);
    },
    build: build,
    act: (PermissionsBloc bloc) async {
      await pumpEventQueue();
      bloc.add(const PermissionsStepOpened(PermissionKind.autostart));
    },
    verify: (PermissionsBloc bloc) {
      verify(bridge.device.openAppDetailsSettings).called(1);
      expect(
        (loaded(bloc).action as ActionSucceeded).message,
        contains('Não achamos a tela de início automático'),
      );
    },
  );

  blocTest<PermissionsBloc, PermissionsState>(
    'voltar das configuracoes rele as permissoes',
    setUp: () => bridge.permissions = fakePermissions(accessibility: false),
    build: build,
    act: (PermissionsBloc bloc) async {
      await pumpEventQueue();
      bridge.permissions = fakePermissions();
      bloc.add(const PermissionsRefreshRequested());
    },
    verify: (PermissionsBloc bloc) {
      expect(loaded(bloc).plan.isComplete, isTrue);
      // O fabricante ja conhecido nao e consultado de novo.
      verify(bridge.device.getDeviceInfo).called(1);
    },
  );

  test('concluir a configuracao inicial deixa o aparelho pronto', () async {
    deps.di<ILinkStateRepository>().update(const LinkState(LinkPhase.onboarding));
    final PermissionsBloc bloc = build();
    addTearDown(bloc.close);

    bloc.add(const PermissionsSetupFinished());
    await pumpEventQueue();

    expect(deps.di<ILinkStateRepository>().current.phase, LinkPhase.ready);
  });
}
