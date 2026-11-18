import 'package:flutter/widgets.dart' hide LockState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/platform/native_api.g.dart' hide AgentStatus;
import 'package:parentalynx/features/child_mode/presentation/bloc/child_home/child_home_bloc.dart';
import 'package:parentalynx/features/child_mode/presentation/bloc/guardian_area/guardian_area_bloc.dart';
import 'package:parentalynx/features/child_mode/presentation/bloc/permissions/permissions_bloc.dart';
import 'package:parentalynx/features/child_mode/presentation/pages/child_home_page.dart';
import 'package:parentalynx/features/child_mode/presentation/pages/guardian_area_page.dart';
import 'package:parentalynx/features/child_mode/presentation/pages/permissions_page.dart';
import 'package:parentalynx/features/child_mode/presentation/pages/transparency_page.dart';
import 'package:parentalynx/features/device_linking/domain/entities/link_state.dart';
import 'package:parentalynx/features/device_linking/domain/repositories/i_link_state_repository.dart';
import 'package:parentalynx/features/screen_time/presentation/bloc/time_request_sheet/time_request_sheet_bloc.dart';

import '../../support/test_app.dart';
import '../../support/test_dependencies.dart';
import 'support/child_app.dart';
import 'support/child_fakes.dart';

void main() {
  late TestDependencies deps;
  late ChildBridge bridge;

  setUpAll(registerChildFallbacks);

  setUp(() {
    (:deps, :bridge) = childDependencies();
    addTearDown(deps.dispose);
    deps.di<ILinkStateRepository>().update(const LinkState(LinkPhase.ready));
  });

  testWidgets(
    'permissoes destacam o proximo passo e a divulgacao da acessibilidade',
    tags: 'screenshot',
    (WidgetTester tester) async {
      bridge.permissions = fakePermissions(
        accessibility: false,
        overlay: false,
        restrictedSettingsLikely: true,
      );
      when(bridge.device.openAccessibilitySettings).thenAnswer((_) async {});
      await pumpChildPage(
        tester,
        deps.di,
        BlocProvider<PermissionsBloc>(
          create: (BuildContext context) =>
              deps.di<PermissionsBloc>()..add(const PermissionsLoadRequested()),
          child: const PermissionsPage(setup: true),
        ),
        size: const Size(392, 2150),
      );
      await settleChild(tester);

      expect(find.text('2 de 3 permissões obrigatórias ligadas'), findsOneWidget);
      expect(find.text('Proteção padrão'), findsOneWidget);
      expect(find.text('O que este serviço faz'), findsOneWidget);
      expect(find.text('A opção está apagada?'), findsOneWidget);
      expect(find.text('Continuar mesmo assim'), findsOneWidget);
      await expectScreenshot(tester, 'child_permissions');

      await tester.tap(find.text('Ativar acessibilidade'));
      await tester.pump();
      verify(bridge.device.openAccessibilitySettings).called(1);
      await unmountChildApp(tester, deps.di);
    },
  );

  testWidgets('transparencia mostra quem cuida das regras', (WidgetTester tester) async {
    await pumpChildPage(tester, deps.di, const TransparencyPage(setup: false));
    await settleChild(tester);

    expect(find.text('Sobre o controle'), findsOneWidget);
    expect(
      find.text('Maria é o responsável por este aparelho e é quem define as regras.'),
      findsOneWidget,
    );
    await unmountChildApp(tester, deps.di);
  });

  group('tela inicial', () {
    Future<void> pumpHome(WidgetTester tester, {Size size = phoneSize}) {
      return pumpChildPage(
        tester,
        deps.di,
        MultiBlocProvider(
          providers: <BlocProvider<Object?>>[
            BlocProvider<ChildHomeBloc>(
              create: (BuildContext context) =>
                  deps.di<ChildHomeBloc>()..add(const ChildHomeStarted()),
            ),
            BlocProvider<TimeRequestSheetBloc>(
              create: (BuildContext context) => deps.di<TimeRequestSheetBloc>(),
            ),
          ],
          child: const ChildHomePage(),
        ),
        size: size,
      );
    }

    testWidgets('liberado mostra a contagem regressiva, o uso e as regras', tags: 'screenshot', (
      WidgetTester tester,
    ) async {
      bridge.requests = <TimeRequestInfo>[
        TimeRequestInfo(
          id: 'r1',
          createdAtMs: msAt(15, 0),
          minutes: 30,
          status: 'pending',
          delivered: true,
        ),
      ];
      await pumpHome(tester, size: const Size(392, 1900));
      await settleChild(tester);

      expect(find.text('Olá, João!'), findsOneWidget);
      expect(find.text('Controle parental ativo'), findsOneWidget);
      expect(find.text('1:20:00'), findsOneWidget);
      expect(find.text('Você usou 1h 10min de 2h 30min.'), findsOneWidget);
      expect(find.text('Pedir mais tempo'), findsOneWidget);
      expect(find.text('Abrir o navegador seguro'), findsOneWidget);
      expect(find.text('Vídeos'), findsOneWidget);
      expect(find.text('Escola Digital'), findsOneWidget);
      expect(find.text('Tempo por dia: 2h 30min.'), findsOneWidget);
      expect(find.text('Esperando a resposta'), findsOneWidget);
      await expectScreenshot(tester, 'child_home');
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('limite atingido explica o bloqueio e quando o tempo volta', tags: 'screenshot', (
      WidgetTester tester,
    ) async {
      bridge.status = fakeStatus(
        lockState: LockState.dailyLimit,
        quotaUsedMs: 9000000,
        releaseAtMs: msAt(0, 0, dayOffset: 1),
      );
      await pumpHome(tester);
      await settleChild(tester);

      expect(find.text('Seu tempo de hoje acabou'), findsOneWidget);
      expect(find.textContaining('O tempo volta amanhã às 00:00'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('o tempo acabou'), findsOneWidget);
      await expectScreenshot(tester, 'child_home_locked');
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('bloqueio por horario mostra o nome do periodo', (WidgetTester tester) async {
      bridge.status = fakeStatus(
        lockState: LockState.schedule,
        activeScheduleLabel: 'Hora de dormir',
        releaseAtMs: msAt(7, 0, dayOffset: 1),
      );
      await pumpHome(tester);
      await settleChild(tester);

      expect(find.text('Hora de dormir'), findsWidgets);
      expect(find.textContaining('volta a liberar amanhã às 07:00'), findsOneWidget);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('aparelho pausado e permissao desligada aparecem para a crianca', (
      WidgetTester tester,
    ) async {
      bridge.status = fakeStatus(
        lockState: LockState.manualLock,
        issues: <String>['accessibility_disabled'],
      );
      await pumpHome(tester);
      await settleChild(tester);

      expect(find.text('Aparelho em pausa'), findsOneWidget);
      expect(find.textContaining('Fale com Maria para liberar'), findsOneWidget);
      expect(find.text('O controle precisa de atenção'), findsOneWidget);
      expect(find.text('Ver permissões'), findsOneWidget);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('pedir mais tempo registra o pedido no agente', (WidgetTester tester) async {
      when(() => bridge.agent.submitTimeRequest(any(), any())).thenAnswer((_) async => 'req-1');
      await pumpHome(tester);
      await settleChild(tester);

      await tester.tap(find.text('Pedir mais tempo'));
      await settleChild(tester);
      expect(find.text('Quanto tempo?'), findsOneWidget);
      await tester.tap(find.text('1h'));
      await tester.pump();
      await tester.tap(find.text('Enviar pedido'));
      await settleChild(tester);

      verify(() => bridge.agent.submitTimeRequest(60, null)).called(1);
      expect(find.text('Pedido enviado. Você vê a resposta aqui.'), findsOneWidget);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('sincronizar agora avisa o resultado', (WidgetTester tester) async {
      when(bridge.agent.syncNow).thenAnswer((_) async => SyncOutcome(ok: true, atMs: 1));
      await pumpHome(tester, size: const Size(392, 1900));
      await settleChild(tester);

      await tester.tap(find.text('Sincronizar agora'));
      await settleChild(tester);

      verify(bridge.agent.syncNow).called(1);
      expect(find.text('Tudo sincronizado.'), findsOneWidget);
      await unmountChildApp(tester, deps.di);
    });
  });

  group('area do responsavel', () {
    Future<void> pumpGuardianArea(WidgetTester tester, {Size size = phoneSize}) {
      return pumpChildPage(
        tester,
        deps.di,
        BlocProvider<GuardianAreaBloc>(
          create: (BuildContext context) => deps.di<GuardianAreaBloc>(),
          child: const GuardianAreaPage(),
        ),
        size: size,
      );
    }

    testWidgets('senha incorreta mostra o erro e a correta abre as operacoes', tags: 'screenshot', (
      WidgetTester tester,
    ) async {
      when(() => bridge.agent.verifyAdminPassword('errada')).thenAnswer(
        (_) async =>
            AdminAuthResult(outcome: AdminAuthOutcome.invalid, retryAfterSec: 0, attemptsLeft: 4),
      );
      when(() => bridge.agent.verifyAdminPassword('Senha#Forte1')).thenAnswer(
        (_) async =>
            AdminAuthResult(outcome: AdminAuthOutcome.ok, retryAfterSec: 0, attemptsLeft: -1),
      );
      when(() => bridge.agent.grantLocalOverride(30)).thenAnswer((_) async {});
      await pumpGuardianArea(tester, size: const Size(392, 1250));
      await settleChild(tester);

      expect(find.text('Só para o responsável'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'errada');
      await tester.tap(find.text('Entrar'));
      await settleChild(tester);
      expect(find.text('Senha incorreta. Restam 4 tentativas.'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'Senha#Forte1');
      await tester.tap(find.text('Entrar'));
      await settleChild(tester);
      expect(find.text('Liberar o uso agora'), findsOneWidget);
      expect(find.text('Desvincular este aparelho'), findsOneWidget);
      expect(find.text('Administrador do dispositivo'), findsOneWidget);
      await expectScreenshot(tester, 'child_guardian_area');

      await tester.tap(find.text('30min'));
      await settleChild(tester);
      verify(() => bridge.agent.grantLocalOverride(30)).called(1);
      expect(find.text('Uso liberado por 30min.'), findsOneWidget);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('alternar para o codigo offline explica onde encontra-lo', (
      WidgetTester tester,
    ) async {
      await pumpGuardianArea(tester);
      await settleChild(tester);

      await tester.tap(find.text('Usar o código de acesso offline'));
      await settleChild(tester);

      expect(find.text('Onde achar o código'), findsOneWidget);
      expect(find.text('Entrar com o código'), findsOneWidget);
      await unmountChildApp(tester, deps.di);
    });
  });
}
