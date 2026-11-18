import 'package:flutter/services.dart';
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
import 'package:parentalynx/features/child_mode/presentation/texts/home_texts.dart';
import 'package:parentalynx/features/device_linking/domain/entities/link_state.dart';
import 'package:parentalynx/features/device_linking/domain/repositories/i_link_state_repository.dart';
import 'package:parentalynx/features/screen_time/presentation/bloc/time_request_sheet/time_request_sheet_bloc.dart';
import 'package:parentalynx/shared/design_system/design_system.dart';

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

  group('permissoes', () {
    Future<void> pumpPermissions(
      WidgetTester tester, {
      Size size = const Size(392, 2600),
      Brightness brightness = Brightness.light,
      double textScale = 1,
    }) {
      bridge.permissions = fakePermissions(
        accessibility: false,
        overlay: false,
        restrictedSettingsLikely: true,
      );
      return pumpChildPage(
        tester,
        deps.di,
        BlocProvider<PermissionsBloc>(
          create: (BuildContext context) =>
              deps.di<PermissionsBloc>()..add(const PermissionsLoadRequested()),
          child: const PermissionsPage(setup: true),
        ),
        size: size,
        brightness: brightness,
        textScale: textScale,
      );
    }

    for (final Brightness brightness in Brightness.values) {
      final String suffix = brightness == Brightness.light ? '' : '_escuro';
      testWidgets(
        'destacam o proximo passo, como ligar e a divulgacao da acessibilidade ($brightness)',
        tags: 'screenshot',
        (WidgetTester tester) async {
          when(bridge.device.openAccessibilitySettings).thenAnswer((_) async {});
          await pumpPermissions(tester, brightness: brightness);
          await settleChild(tester);

          expect(find.text('2 de 3 permissões obrigatórias ligadas'), findsOneWidget);
          expect(find.text('Próximo passo'), findsOneWidget);
          expect(find.text('Proteção padrão'), findsOneWidget);
          expect(find.text('O que este serviço faz'), findsOneWidget);
          expect(find.text('A opção está apagada?'), findsOneWidget);
          expect(find.text('Toque em "Ativar acessibilidade".'), findsOneWidget);
          expect(find.text('Continuar mesmo assim'), findsOneWidget);
          await expectScreenshot(tester, 'child_permissions$suffix');

          await tester.tap(find.text('Ativar acessibilidade'));
          await tester.pump();
          verify(bridge.device.openAccessibilitySettings).called(1);
          await unmountChildApp(tester, deps.di);
        },
      );
    }

    testWidgets('continuar sem as obrigatorias pede confirmacao', (WidgetTester tester) async {
      await pumpPermissions(tester, size: phoneSize);
      await settleChild(tester);

      await tester.tap(find.text('Continuar mesmo assim'));
      await settleChild(tester);
      expect(find.text('Continuar sem as permissões?'), findsOneWidget);
      await tester.tap(find.text('Voltar e ligar'));
      await settleChild(tester);
      expect(find.text('Continuar sem as permissões?'), findsNothing);
      expect(deps.di<ILinkStateRepository>().current.phase, LinkPhase.ready);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('funcionam com a fonte no maior tamanho', (WidgetTester tester) async {
      await pumpPermissions(tester, size: phoneSize, textScale: 2);
      await settleChild(tester);
      expect(tester.takeException(), isNull);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('seguem as diretrizes de acessibilidade', (WidgetTester tester) async {
      await pumpPermissions(tester);
      await settleChild(tester);
      await expectAccessible(tester);
      await unmountChildApp(tester, deps.di);
    });
  });

  group('transparencia', () {
    for (final Brightness brightness in Brightness.values) {
      final String suffix = brightness == Brightness.light ? '' : '_escuro';
      testWidgets('explica o que o app faz e o que ele nao ve ($brightness)', tags: 'screenshot', (
        WidgetTester tester,
      ) async {
        await pumpChildPage(
          tester,
          deps.di,
          const TransparencyPage(setup: true),
          size: const Size(392, 2500),
          brightness: brightness,
        );
        await settleChild(tester);

        expect(find.text('O que este app faz'), findsOneWidget);
        expect(find.text('O que este app NÃO vê'), findsOneWidget);
        expect(find.text('Suas mensagens e conversas.'), findsOneWidget);
        expect(find.text('Entendi, continuar'), findsOneWidget);
        await expectScreenshot(tester, 'child_transparency$suffix');
        await unmountChildApp(tester, deps.di);
      });
    }

    testWidgets('fora da configuracao mostra quem cuida das regras', (WidgetTester tester) async {
      await pumpChildPage(tester, deps.di, const TransparencyPage(setup: false));
      await settleChild(tester);

      expect(find.text('Sobre o controle'), findsOneWidget);
      expect(
        find.text('Maria é o responsável por este aparelho e é quem define as regras.'),
        findsOneWidget,
      );
      expect(find.text('Entendi, continuar'), findsNothing);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('funciona com a fonte no maior tamanho e e acessivel', (WidgetTester tester) async {
      await pumpChildPage(tester, deps.di, const TransparencyPage(setup: true), textScale: 2);
      await settleChild(tester);
      expect(tester.takeException(), isNull);
      await unmountChildApp(tester, deps.di);

      await pumpChildPage(
        tester,
        deps.di,
        const TransparencyPage(setup: true),
        size: const Size(392, 2500),
      );
      await settleChild(tester);
      await expectAccessible(tester);
      await unmountChildApp(tester, deps.di);
    });
  });

  group('tela inicial', () {
    Future<void> pumpHome(
      WidgetTester tester, {
      Size size = phoneSize,
      Brightness brightness = Brightness.light,
      double textScale = 1,
    }) {
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
        brightness: brightness,
        textScale: textScale,
      );
    }

    void pendingRequest() {
      bridge.requests = <TimeRequestInfo>[
        TimeRequestInfo(
          id: 'r1',
          createdAtMs: msAt(15, 0),
          minutes: 30,
          status: 'pending',
          delivered: true,
        ),
      ];
    }

    const Size tall = Size(392, 2250);

    for (final Brightness brightness in Brightness.values) {
      final String suffix = brightness == Brightness.light ? '' : '_escuro';
      testWidgets(
        'liberado mostra o tempo restante, o pedido e as regras ($brightness)',
        tags: 'screenshot',
        (WidgetTester tester) async {
          pendingRequest();
          await pumpHome(tester, size: tall, brightness: brightness);
          await settleChild(tester);

          expect(find.text('Olá, João!'), findsOneWidget);
          expect(find.text('Controle parental ativo'), findsOneWidget);
          expect(find.text('1h 20min'), findsOneWidget);
          expect(
            find.bySemanticsLabel(
              'Restam 1 hora e 20 minutos para usar hoje, de 2 horas e 30 minutos.',
            ),
            findsOneWidget,
          );
          expect(find.text('Você usou 1h 10min de 2h 30min.'), findsOneWidget);
          expect(find.text('Pedir mais tempo'), findsOneWidget);
          expect(find.text('Pedido de 30min'), findsOneWidget);
          expect(find.text('Esperando a resposta'), findsOneWidget);
          expect(find.text('Navegador seguro'), findsOneWidget);
          expect(find.text('Vídeos'), findsOneWidget);
          expect(find.text('Escola Digital'), findsOneWidget);
          expect(find.text('Tempo por dia: 2h 30min.'), findsOneWidget);
          expect(find.text('Regras em dia'), findsOneWidget);
          await expectScreenshot(tester, 'child_home$suffix');
          await unmountChildApp(tester, deps.di);
        },
      );

      testWidgets(
        'limite atingido explica o motivo e quando o tempo volta ($brightness)',
        tags: 'screenshot',
        (WidgetTester tester) async {
          bridge.status = fakeStatus(
            lockState: LockState.dailyLimit,
            quotaUsedMs: 9000000,
            releaseAtMs: msAt(0, 0, dayOffset: 1),
          );
          await pumpHome(tester, brightness: brightness);
          await settleChild(tester);

          expect(find.text('Seu tempo de hoje acabou'), findsOneWidget);
          expect(find.text('O tempo volta amanhã às 00:00.'), findsOneWidget);
          expect(find.text(lockedStillWorks), findsOneWidget);
          expect(find.text('Pedir mais tempo'), findsOneWidget);
          // O anel some: o motivo e quando volta ocupam o lugar do numero.
          expect(find.text('0min'), findsNothing);
          await expectScreenshot(tester, 'child_home_locked$suffix');
          await unmountChildApp(tester, deps.di);
        },
      );
    }

    testWidgets(
      'hora de dormir mostra o nome da pausa e quando o aparelho volta',
      tags: 'screenshot',
      (WidgetTester tester) async {
        bridge.status = fakeStatus(
          lockState: LockState.schedule,
          activeScheduleLabel: 'Hora de dormir',
          releaseAtMs: msAt(7, 0, dayOffset: 1),
        );
        await pumpHome(tester);
        await settleChild(tester);

        expect(find.text('Hora de dormir'), findsOneWidget);
        expect(find.text('O aparelho volta amanhã às 07:00.'), findsOneWidget);
        // Durante a pausa o pedido continua possivel, mas nao e a acao principal.
        final AppButton request = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Pedir mais tempo'),
        );
        expect(request.variant, AppButtonVariant.secondary);
        await expectScreenshot(tester, 'child_home_bedtime');
        await unmountChildApp(tester, deps.di);
      },
    );

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
      expect(find.textContaining('fale com Maria'), findsOneWidget);
      expect(find.text('O controle precisa de atenção'), findsOneWidget);
      expect(find.text('Ver permissões'), findsOneWidget);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('sem limite nao oferece pedir mais tempo', (WidgetTester tester) async {
      bridge.status = fakeStatus(limitEnabled: false);
      await pumpHome(tester);
      await settleChild(tester);

      expect(find.text('Sem limite de tempo hoje'), findsOneWidget);
      expect(find.text('Pedir mais tempo'), findsNothing);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('pedir mais tempo registra o pedido no agente', tags: 'screenshot', (
      WidgetTester tester,
    ) async {
      when(() => bridge.agent.submitTimeRequest(any(), any())).thenAnswer((_) async => 'req-1');
      await pumpHome(tester);
      await settleChild(tester);

      await tester.tap(find.text('Pedir mais tempo'));
      await settleChild(tester);
      expect(find.text('Quanto tempo?'), findsOneWidget);
      expect(find.text('O pedido vai para Maria, que decide se aprova.'), findsOneWidget);
      await expectScreenshot(tester, 'child_time_request_sheet');

      await tester.tap(find.text('1h'));
      await tester.pump();
      await tester.tap(find.text('Enviar pedido'));
      await settleChild(tester);

      verify(() => bridge.agent.submitTimeRequest(60, null)).called(1);
      expect(find.text('Quanto tempo?'), findsNothing);
      expect(find.text('Pedido enviado. Você vê a resposta aqui.'), findsOneWidget);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('com um pedido sem resposta a folha avisa antes de mandar outro', (
      WidgetTester tester,
    ) async {
      pendingRequest();
      await pumpHome(tester);
      await settleChild(tester);

      await tester.tap(find.text('Pedir mais tempo'));
      await settleChild(tester);
      expect(find.textContaining('Você já pediu 30min há 30 min'), findsOneWidget);

      // Fechar a folha nao manda nada.
      await tester.tap(find.byTooltip('Fechar'));
      await settleChild(tester);
      expect(find.text('Quanto tempo?'), findsNothing);
      verifyNever(() => bridge.agent.submitTimeRequest(any(), any()));
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('falha ao enviar o pedido explica e deixa tentar de novo', (
      WidgetTester tester,
    ) async {
      when(() => bridge.agent.submitTimeRequest(any(), any()))
          .thenThrow(PlatformException(code: 'IllegalStateException', details: 'Cause: x'));
      await pumpHome(tester);
      await settleChild(tester);

      await tester.tap(find.text('Pedir mais tempo'));
      await settleChild(tester);
      await tester.tap(find.text('Enviar pedido'));
      await settleChild(tester);

      expect(find.text('O pedido não foi enviado'), findsOneWidget);
      expect(find.text('Enviar pedido'), findsOneWidget);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('atualizar agora avisa o resultado', (WidgetTester tester) async {
      when(bridge.agent.syncNow).thenAnswer((_) async => SyncOutcome(ok: true, atMs: 1));
      await pumpHome(tester, size: tall);
      await settleChild(tester);

      await tester.tap(find.text('Atualizar agora'));
      await settleChild(tester);

      verify(bridge.agent.syncNow).called(1);
      expect(find.text('Pronto: as regras estão em dia.'), findsOneWidget);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('funciona com a fonte no maior tamanho', (WidgetTester tester) async {
      pendingRequest();
      await pumpHome(tester, textScale: 2);
      await settleChild(tester);
      expect(tester.takeException(), isNull);
      // Com a fonte ampliada o valor do anel tambem aparece em texto.
      expect(find.text('Restam 1h 20min para usar hoje.'), findsOneWidget);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('pausa funciona com a fonte no maior tamanho', (WidgetTester tester) async {
      bridge.status = fakeStatus(
        lockState: LockState.schedule,
        activeScheduleLabel: 'Hora de dormir',
        releaseAtMs: msAt(7, 0, dayOffset: 1),
      );
      await pumpHome(tester, textScale: 2);
      await settleChild(tester);
      expect(tester.takeException(), isNull);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('segue as diretrizes de acessibilidade', (WidgetTester tester) async {
      pendingRequest();
      await pumpHome(tester, size: tall);
      await settleChild(tester);
      await expectAccessible(tester);
      await unmountChildApp(tester, deps.di);
    });
  });

  group('area do responsavel', () {
    Future<void> pumpGuardianArea(
      WidgetTester tester, {
      Size size = phoneSize,
      Brightness brightness = Brightness.light,
      double textScale = 1,
    }) {
      return pumpChildPage(
        tester,
        deps.di,
        BlocProvider<GuardianAreaBloc>(
          create: (BuildContext context) => deps.di<GuardianAreaBloc>(),
          child: const GuardianAreaPage(),
        ),
        size: size,
        brightness: brightness,
        textScale: textScale,
      );
    }

    void acceptPassword() {
      when(() => bridge.agent.verifyAdminPassword('errada')).thenAnswer(
        (_) async =>
            AdminAuthResult(outcome: AdminAuthOutcome.invalid, retryAfterSec: 0, attemptsLeft: 4),
      );
      when(() => bridge.agent.verifyAdminPassword('Senha#Forte1')).thenAnswer(
        (_) async =>
            AdminAuthResult(outcome: AdminAuthOutcome.ok, retryAfterSec: 0, attemptsLeft: -1),
      );
    }

    Future<void> signIn(WidgetTester tester) async {
      await tester.enterText(find.byType(EditableText), 'Senha#Forte1');
      await tester.tap(find.text('Entrar'));
      await settleChild(tester);
    }

    for (final Brightness brightness in Brightness.values) {
      final String suffix = brightness == Brightness.light ? '' : '_escuro';
      testWidgets(
        'senha incorreta mostra o erro e a correta abre as operacoes ($brightness)',
        tags: 'screenshot',
        (WidgetTester tester) async {
          acceptPassword();
          when(() => bridge.agent.grantLocalOverride(30)).thenAnswer((_) async {});
          await pumpGuardianArea(tester, size: const Size(392, 1500), brightness: brightness);
          await settleChild(tester);

          expect(find.text('Só para o responsável'), findsOneWidget);
          await tester.enterText(find.byType(EditableText), 'errada');
          await tester.tap(find.text('Entrar'));
          await settleChild(tester);
          expect(find.text('Senha incorreta. Restam 4 tentativas.'), findsOneWidget);
          await expectScreenshot(tester, 'child_guardian_area_password$suffix');

          await signIn(tester);
          expect(find.text('Liberar o uso agora'), findsOneWidget);
          expect(find.text('Desvincular este aparelho'), findsOneWidget);
          expect(find.text('Administrador do dispositivo'), findsOneWidget);
          await expectScreenshot(tester, 'child_guardian_area$suffix');

          await tester.tap(find.text('30min'));
          await settleChild(tester);
          verify(() => bridge.agent.grantLocalOverride(30)).called(1);
          expect(find.text('Uso liberado por 30min.'), findsOneWidget);
          await unmountChildApp(tester, deps.di);
        },
      );
    }

    testWidgets('desvincular pede confirmacao com a consequencia', (WidgetTester tester) async {
      acceptPassword();
      await pumpGuardianArea(tester, size: const Size(392, 1500));
      await settleChild(tester);
      await signIn(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Desvincular'));
      await settleChild(tester);
      expect(find.text('Desvincular este aparelho?'), findsOneWidget);
      expect(
        find.text('Para controlar este aparelho de novo, será preciso um novo código.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await settleChild(tester);
      expect(find.text('Desvincular este aparelho?'), findsNothing);
      verifyNever(() => bridge.agent.unlink(any()));
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

    testWidgets('funciona com a fonte no maior tamanho', (WidgetTester tester) async {
      acceptPassword();
      await pumpGuardianArea(tester, textScale: 2);
      await settleChild(tester);
      expect(tester.takeException(), isNull);
      await signIn(tester);
      expect(tester.takeException(), isNull);
      await unmountChildApp(tester, deps.di);
    });

    testWidgets('segue as diretrizes de acessibilidade', (WidgetTester tester) async {
      acceptPassword();
      await pumpGuardianArea(tester, size: const Size(392, 1500));
      await settleChild(tester);
      await expectAccessible(tester);
      await signIn(tester);
      await expectAccessible(tester);
      await unmountChildApp(tester, deps.di);
    });
  });
}
