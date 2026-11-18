import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/platform/native_api.g.dart' hide AgentStatus;
import 'package:parentalynx/features/app_management/domain/entities/allowed_app.dart';
import 'package:parentalynx/features/app_management/domain/entities/app_usage.dart';
import 'package:parentalynx/features/child_mode/presentation/bloc/child_home/child_home_bloc.dart';
import 'package:parentalynx/features/child_mode/presentation/services/foreground_tracker.dart';

import '../../support/test_dependencies.dart';
import 'support/child_fakes.dart';

void main() {
  late TestDependencies deps;
  late ChildBridge bridge;

  setUpAll(registerChildFallbacks);

  setUp(() {
    (:deps, :bridge) = childDependencies();
    addTearDown(deps.dispose);
  });

  Future<ChildHomeBloc> start() async {
    final ChildHomeBloc bloc = deps.di<ChildHomeBloc>()..add(const ChildHomeStarted());
    addTearDown(bloc.close);
    await pumpEventQueue();
    return bloc;
  }

  test('carrega regras, uso do mais usado para o menos usado, apps liberados e pedidos', () async {
    bridge.requests = <TimeRequestInfo>[
      TimeRequestInfo(id: 'a', createdAtMs: 1, minutes: 30, status: 'pending', delivered: true),
      TimeRequestInfo(id: 'b', createdAtMs: 2, minutes: 15, status: 'denied', delivered: true),
    ];
    final ChildHomeBloc bloc = await start();

    final summary = bloc.state.summary!;
    expect(summary.policy, isNotNull);
    expect(summary.usage.map((AppUsage u) => u.label), <String>[
      'Vídeos',
      'WhatsApp',
      'Jogo de Corrida',
    ]);
    expect(summary.exceptions.map((AllowedApp a) => a.label), <String>[
      'WhatsApp',
      'Escola Digital',
    ]);
    expect(summary.requests.first.id, 'b');
  });

  test('falha na leitura mantem o que ja esta na tela', () async {
    final ChildHomeBloc bloc = await start();
    when(bridge.agent.getTodayUsage).thenThrow(PlatformException(code: 'channel-error'));

    bloc.add(const ChildHomeRefreshRequested());
    await pumpEventQueue();

    expect(bloc.state.summary!.usage, hasLength(3));
  });

  testWidgets('atualiza a cada 15 segundos so em primeiro plano', (WidgetTester tester) async {
    final ChildHomeBloc bloc = deps.di<ChildHomeBloc>()..add(const ChildHomeStarted());
    await tester.pump();
    verify(bridge.agent.getTodayUsage).called(1);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    verify(bridge.agent.getTodayUsage).called(1);

    deps.di<ForegroundTracker>().update(foreground: false);
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 15));
    verifyNever(bridge.agent.getTodayUsage);
    unawaited(bloc.close());
    await tester.pump();
    await tester.pump();
  });

  test('sincronizar avisa o resultado e rele o resumo', () async {
    when(bridge.agent.syncNow)
        .thenAnswer((_) async => SyncOutcome(ok: false, atMs: 1, errorCode: 'network'));
    final ChildHomeBloc bloc = await start();
    clearInteractions(bridge.agent);

    bloc.add(const ChildHomeSyncRequested());
    await pumpEventQueue();

    expect(bloc.state.syncing, isFalse);
    expect(bloc.state.notice!.kind, HomeNoticeKind.warning);
    expect(bloc.state.notice!.message, contains('Sem conexão'));
    verify(bridge.agent.getTodayUsage).called(1);
  });

  test('app liberado que nao abriu vira aviso', () async {
    when(() => bridge.agent.launchApp('com.escola')).thenAnswer((_) async => false);
    final ChildHomeBloc bloc = await start();

    bloc.add(
      const ChildHomeAppLaunchRequested(
        AllowedApp(packageName: 'com.escola', label: 'Escola Digital', category: 'other'),
      ),
    );
    await pumpEventQueue();

    expect(bloc.state.notice!.message, 'Não foi possível abrir Escola Digital.');
  });

  test('abrir o navegador seguro chama o agente e a falha vira aviso', () async {
    when(() => bridge.agent.openManagedBrowser(any()))
        .thenThrow(PlatformException(code: 'IllegalStateException', details: 'Cause: x'));
    final ChildHomeBloc bloc = await start();

    bloc.add(const ChildHomeBrowserRequested());
    await pumpEventQueue();

    verify(() => bridge.agent.openManagedBrowser(null)).called(1);
    expect(bloc.state.notice!.kind, HomeNoticeKind.failure);
    expect(bloc.state.notice!.message, 'Não foi possível abrir o navegador.');
  });

  test('pedido de tempo enviado avisa e rele os pedidos', () async {
    final ChildHomeBloc bloc = await start();
    bridge.requests = <TimeRequestInfo>[
      TimeRequestInfo(id: 'novo', createdAtMs: 5, minutes: 30, status: 'pending', delivered: false),
    ];

    bloc.add(const ChildHomeTimeRequestSent());
    await pumpEventQueue();

    expect(bloc.state.notice!.message, 'Pedido enviado. Você vê a resposta aqui.');
    expect(bloc.state.summary!.requests.single.id, 'novo');
  });
}
