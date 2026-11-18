import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/features/child_mode/presentation/bloc/child_device_status/child_device_status_bloc.dart';
import 'package:parentalynx/features/child_mode/presentation/services/foreground_tracker.dart';
import 'package:parentalynx/features/device_linking/domain/entities/link_state.dart';
import 'package:parentalynx/features/device_linking/domain/repositories/i_link_state_repository.dart';

import '../../support/test_dependencies.dart';
import 'support/child_fakes.dart';

/// Os testes rodam no tempo simulado do `testWidgets`: `tester.pump(duracao)` avanca o
/// relogio dos temporizadores da consulta periodica.
void main() {
  late TestDependencies deps;
  late ChildBridge bridge;

  setUpAll(registerChildFallbacks);

  setUp(() {
    (:deps, :bridge) = childDependencies();
    addTearDown(deps.dispose);
  });

  ILinkStateRepository link() => deps.di<ILinkStateRepository>();

  Future<ChildDeviceStatusBloc> start(WidgetTester tester) async {
    final ChildDeviceStatusBloc bloc = deps.di<ChildDeviceStatusBloc>()
      ..add(const ChildDeviceStatusStarted());
    await tester.pump();
    return bloc;
  }

  /// Fecha o BLoC (e o temporizador) antes do fim do teste.
  Future<void> stop(WidgetTester tester, ChildDeviceStatusBloc bloc) async {
    unawaited(bloc.close());
    await tester.pump();
    await tester.pump();
  }

  testWidgets('sem vinculo nao consulta o agente', (WidgetTester tester) async {
    link().update(const LinkState(LinkPhase.unlinked));
    final ChildDeviceStatusBloc bloc = await start(tester);
    await tester.pump(const Duration(seconds: 5));

    expect(bloc.state, const ChildDeviceStatusInitial());
    verifyNever(bridge.agent.getStatus);
    verifyNever(bridge.agent.ensureRunning);
    await stop(tester, bloc);
  });

  testWidgets('aparelho vinculado liga o agente e consulta a cada segundo', (
    WidgetTester tester,
  ) async {
    link().update(const LinkState(LinkPhase.ready));
    final ChildDeviceStatusBloc bloc = await start(tester);
    await tester.pump();

    expect(bloc.state, isA<ChildDeviceStatusLoaded>());
    expect(bloc.state.statusOrNull!.childName, 'João');
    verify(bridge.agent.ensureRunning).called(1);
    verify(bridge.agent.getStatus).called(1);

    bridge.status = fakeStatus(quotaUsedMs: 5000000);
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    verify(bridge.agent.getStatus).called(3);
    expect(bloc.state.statusOrNull!.quotaUsedMs, 5000000);
    await stop(tester, bloc);
  });

  testWidgets('em segundo plano as consultas param ate o app voltar', (WidgetTester tester) async {
    link().update(const LinkState(LinkPhase.ready));
    final ForegroundTracker foreground = deps.di<ForegroundTracker>();
    final ChildDeviceStatusBloc bloc = await start(tester);
    await tester.pump();
    clearInteractions(bridge.agent);

    foreground.update(foreground: false);
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    verifyNever(bridge.agent.getStatus);

    foreground.update(foreground: true);
    bloc.add(const ChildDeviceStatusAppResumed());
    await tester.pump(const Duration(seconds: 1));
    verify(bridge.agent.ensureRunning).called(1);
    verify(bridge.agent.getStatus).called(1);
    await stop(tester, bloc);
  });

  testWidgets('falha passageira mantem o ultimo retrato', (WidgetTester tester) async {
    link().update(const LinkState(LinkPhase.ready));
    final ChildDeviceStatusBloc bloc = await start(tester);
    await tester.pump();

    when(bridge.agent.getStatus).thenThrow(PlatformException(code: 'channel-error'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(bloc.state, isA<ChildDeviceStatusLoaded>());
    await stop(tester, bloc);
  });

  testWidgets('sem retrato a falha aparece e tentar de novo consulta na hora', (
    WidgetTester tester,
  ) async {
    when(bridge.agent.getStatus).thenThrow(PlatformException(code: 'channel-error'));
    link().update(const LinkState(LinkPhase.ready));
    final ChildDeviceStatusBloc bloc = await start(tester);
    await tester.pump();
    expect(bloc.state, isA<ChildDeviceStatusFailure>());
    expect((bloc.state as ChildDeviceStatusFailure).failure, isA<NativeFailure>());

    when(bridge.agent.getStatus).thenAnswer((_) async => bridge.status);
    bloc.add(const ChildDeviceStatusRefreshRequested(force: true));
    await tester.pump();

    expect(bloc.state, isA<ChildDeviceStatusLoaded>());
    await stop(tester, bloc);
  });

  testWidgets('agente desativado pelo responsavel desfaz o vinculo e para as consultas', (
    WidgetTester tester,
  ) async {
    link().update(const LinkState(LinkPhase.ready));
    final ChildDeviceStatusBloc bloc = await start(tester);
    await tester.pump();

    bridge.status = fakeStatus(active: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(link().current.phase, LinkPhase.unlinked);
    expect(link().current.unlinkReason, UnlinkReason.revokedByGuardian);
    expect(bloc.state, const ChildDeviceStatusInitial());
    clearInteractions(bridge.agent);
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    verifyNever(bridge.agent.getStatus);
    await stop(tester, bloc);
  });

  testWidgets('vinculo concluido depois de abrir passa a consultar', (WidgetTester tester) async {
    link().update(const LinkState(LinkPhase.unlinked));
    final ChildDeviceStatusBloc bloc = await start(tester);
    verifyNever(bridge.agent.getStatus);

    link().update(const LinkState(LinkPhase.onboarding));
    await tester.pump();
    await tester.pump();

    expect(bloc.state, isA<ChildDeviceStatusLoaded>());
    verify(bridge.agent.ensureRunning).called(1);
    await stop(tester, bloc);
  });
}
