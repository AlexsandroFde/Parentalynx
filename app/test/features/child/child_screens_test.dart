import 'dart:convert';

import 'package:flutter/widgets.dart' hide LockState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/platform/native_providers.dart';
import 'package:parentalynx/core/storage/secure_store.dart';
import 'package:parentalynx/features/child/browser/presentation/browser_controller.dart';
import 'package:parentalynx/features/child/browser/presentation/browser_engine.dart';
import 'package:parentalynx/features/child/browser/presentation/browser_page.dart';
import 'package:parentalynx/features/child/guardian_area/presentation/guardian_area_page.dart';
import 'package:parentalynx/features/child/home/presentation/child_home_page.dart';
import 'package:parentalynx/features/child/linking/data/pairing_repository.dart';
import 'package:parentalynx/features/child/linking/presentation/link_page.dart';
import 'package:parentalynx/features/child/permissions/presentation/permissions_page.dart';

import '../../support/test_app.dart';
import 'support/child_fakes.dart';

/// Desmonta a arvore para encerrar os temporizadores periodicos das telas.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

/// Deixa as respostas dos dubles chegarem e as animacoes de entrada terminarem.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  late ChildBridge bridge;

  setUpAll(registerChildFallbacks);

  setUp(() => bridge = ChildBridge());

  group('vinculacao', () {
    testWidgets('formulario pede o codigo e sugere o nome do aparelho', tags: 'screenshot', (
      WidgetTester tester,
    ) async {
      await pumpWidgetInApp(tester, const LinkPage(), overrides: bridge.overrides());
      await _settle(tester);

      expect(find.text('Vincular este aparelho'), findsOneWidget);
      expect(find.text('Moto G de João'), findsOneWidget);
      expect(find.text('Voltar e escolher outro modo'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).first, 'ab2d9xyz');
      await tester.pump();
      expect(find.text('AB2D-9XYZ'), findsOneWidget);
      // Espera a animacao do botao, que acabou de ser habilitado.
      await tester.pump(const Duration(milliseconds: 400));
      await expectScreenshot(tester, 'child_link');
      await _unmount(tester);
    });

    testWidgets('espera mostra o numero de confirmacao em destaque', tags: 'screenshot', (
      WidgetTester tester,
    ) async {
      final InMemorySecureStore store = InMemorySecureStore(<String, String>{
        SecurePendingClaimStore.key: jsonEncode(<String, Object?>{
          'linkId': 'link-1',
          'pollToken': 'pp_token',
          'confirmCode': '4821',
          'guardianName': 'Maria',
          'expiresAt': 1790000000000,
        }),
      });
      await pumpWidgetInApp(
        tester,
        const LinkPage(),
        overrides: bridge.overrides(
          secureStore: store,
          httpClient: MockClient((http.Request request) async {
            return jsonResponse(<String, Object?>{'status': 'pending'});
          }),
        ),
      );
      await _settle(tester);

      expect(find.text('4 8 2 1'), findsOneWidget);
      expect(find.textContaining('Maria precisa aprovar'), findsOneWidget);
      expect(find.text('Esperando a aprovação...'), findsOneWidget);
      await expectScreenshot(tester, 'child_link_waiting');
      await _unmount(tester);
    });
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
      await pumpWidgetInApp(
        tester,
        const PermissionsPage(setup: true),
        overrides: bridge.overrides(),
        size: const Size(392, 2150),
      );
      await _settle(tester);

      expect(find.text('2 de 3 permissões obrigatórias ligadas'), findsOneWidget);
      expect(find.text('Proteção padrão'), findsOneWidget);
      expect(find.text('O que este serviço faz'), findsOneWidget);
      expect(find.text('A opção está apagada?'), findsOneWidget);
      expect(find.text('Continuar mesmo assim'), findsOneWidget);
      await expectScreenshot(tester, 'child_permissions');

      await tester.tap(find.text('Ativar acessibilidade'));
      await tester.pump();
      verify(bridge.device.openAccessibilitySettings).called(1);
      await _unmount(tester);
    },
  );

  group('tela inicial', () {
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
      await pumpWidgetInApp(
        tester,
        const ChildHomePage(),
        overrides: bridge.overrides(),
        size: const Size(392, 1900),
      );
      await _settle(tester);

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
      await _unmount(tester);
    });

    testWidgets('limite atingido explica o bloqueio e quando o tempo volta', tags: 'screenshot', (
      WidgetTester tester,
    ) async {
      bridge.status = fakeStatus(
        lockState: LockState.dailyLimit,
        quotaUsedMs: 9000000,
        releaseAtMs: msAt(0, 0, dayOffset: 1),
      );
      await pumpWidgetInApp(tester, const ChildHomePage(), overrides: bridge.overrides());
      await _settle(tester);

      expect(find.text('Seu tempo de hoje acabou'), findsOneWidget);
      expect(find.textContaining('O tempo volta amanhã às 00:00'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('o tempo acabou'), findsOneWidget);
      await expectScreenshot(tester, 'child_home_locked');
      await _unmount(tester);
    });

    testWidgets('bloqueio por horario mostra o nome do periodo', (WidgetTester tester) async {
      bridge.status = fakeStatus(
        lockState: LockState.schedule,
        activeScheduleLabel: 'Hora de dormir',
        releaseAtMs: msAt(7, 0, dayOffset: 1),
      );
      await pumpWidgetInApp(tester, const ChildHomePage(), overrides: bridge.overrides());
      await _settle(tester);

      expect(find.text('Hora de dormir'), findsWidgets);
      expect(find.textContaining('volta a liberar amanhã às 07:00'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('aparelho pausado e permissao desligada aparecem para a crianca', (
      WidgetTester tester,
    ) async {
      bridge.status = fakeStatus(
        lockState: LockState.manualLock,
        issues: <String>['accessibility_disabled'],
      );
      await pumpWidgetInApp(tester, const ChildHomePage(), overrides: bridge.overrides());
      await _settle(tester);

      expect(find.text('Aparelho em pausa'), findsOneWidget);
      expect(find.textContaining('Fale com Maria para liberar'), findsOneWidget);
      expect(find.text('O controle precisa de atenção'), findsOneWidget);
      expect(find.text('Ver permissões'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('pedir mais tempo registra o pedido no agente', (WidgetTester tester) async {
      when(() => bridge.agent.submitTimeRequest(any(), any())).thenAnswer((_) async => 'req-1');
      await pumpWidgetInApp(tester, const ChildHomePage(), overrides: bridge.overrides());
      await _settle(tester);

      await tester.tap(find.text('Pedir mais tempo'));
      await _settle(tester);
      expect(find.text('Quanto tempo?'), findsOneWidget);
      await tester.tap(find.text('1h'));
      await tester.pump();
      await tester.tap(find.text('Enviar pedido'));
      await _settle(tester);

      verify(() => bridge.agent.submitTimeRequest(60, null)).called(1);
      expect(find.text('Pedido enviado. Você vê a resposta aqui.'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('area do responsavel', () {
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
      await pumpWidgetInApp(
        tester,
        const GuardianAreaPage(),
        overrides: bridge.overrides(),
        size: const Size(392, 1250),
      );
      await _settle(tester);

      expect(find.text('Só para o responsável'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'errada');
      await tester.tap(find.text('Entrar'));
      await _settle(tester);
      expect(find.text('Senha incorreta. Restam 4 tentativas.'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'Senha#Forte1');
      await tester.tap(find.text('Entrar'));
      await _settle(tester);
      expect(find.text('Liberar o uso agora'), findsOneWidget);
      expect(find.text('Desvincular este aparelho'), findsOneWidget);
      expect(find.text('Administrador do dispositivo'), findsOneWidget);
      await expectScreenshot(tester, 'child_guardian_area');

      await tester.tap(find.text('30min'));
      await _settle(tester);
      verify(() => bridge.agent.grantLocalOverride(30)).called(1);
      expect(find.text('Uso liberado por 30min.'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('alternar para o codigo offline explica onde encontra-lo', (
      WidgetTester tester,
    ) async {
      await pumpWidgetInApp(tester, const GuardianAreaPage(), overrides: bridge.overrides());
      await _settle(tester);

      await tester.tap(find.text('Usar o código de acesso offline'));
      await _settle(tester);

      expect(find.text('Onde achar o código'), findsOneWidget);
      expect(find.text('Entrar com o código'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('navegador gerenciado', () {
    late MockBrowserApi api;
    late FakeBrowserEngine engine;

    setUp(() {
      api = MockBrowserApi();
      engine = FakeBrowserEngine();
      when(api.getConfig).thenAnswer(
        (_) async =>
            BrowserConfig(enabled: true, logHistory: true, safeSearch: true, allowlistMode: false),
      );
      when(api.consumeInitialUrl).thenAnswer((_) async => null);
      when(() => api.recordVisit(any(), any(), any(), any())).thenAnswer((_) async {});
    });

    Future<ProviderContainer> pumpBrowser(WidgetTester tester) async {
      await pumpWidgetInApp(
        tester,
        const BrowserPage(),
        overrides: [
          browserApiProvider.overrideWithValue(api),
          browserEngineProvider.overrideWithValue(engine),
        ],
      );
      await _settle(tester);
      return ProviderScope.containerOf(tester.element(find.byType(BrowserPage)));
    }

    testWidgets(
      'pagina inicial avisa que o historico e visto pelo responsavel',
      tags: 'screenshot',
      (WidgetTester tester) async {
        await pumpBrowser(tester);

        expect(find.text('Navegador ParentaLynx'), findsOneWidget);
        expect(find.text('O responsável vê o histórico deste navegador.'), findsOneWidget);
        expect(find.textContaining('A busca segura está ligada'), findsOneWidget);
        await expectScreenshot(tester, 'child_browser_start');
        await _unmount(tester);
      },
    );

    testWidgets('site barrado mostra a pagina de bloqueio com o motivo', tags: 'screenshot', (
      WidgetTester tester,
    ) async {
      when(() => api.evaluateUrl('https://apostas.exemplo/')).thenAnswer(
        (_) async => UrlDecision(allowed: false, reason: 'category', category: 'gambling'),
      );
      final ProviderContainer container = await pumpBrowser(tester);

      await tester.enterText(find.byType(EditableText), 'https://apostas.exemplo/');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await _settle(tester);

      expect(find.text('Este site não abre aqui'), findsOneWidget);
      expect(find.text('apostas.exemplo'), findsWidgets);
      expect(find.textContaining('apostas e jogos de azar'), findsOneWidget);
      expect(engine.loaded, isEmpty);
      expect(container.read(browserControllerProvider).blocked, isNotNull);
      await expectScreenshot(tester, 'child_browser_blocked');
      await _unmount(tester);
    });

    testWidgets('navegador desligado pelo responsavel fica indisponivel', (
      WidgetTester tester,
    ) async {
      when(api.getConfig).thenAnswer(
        (_) async => BrowserConfig(
          enabled: false,
          logHistory: false,
          safeSearch: false,
          allowlistMode: false,
        ),
      );
      await pumpBrowser(tester);

      expect(find.text('Navegador indisponível'), findsOneWidget);
      await _unmount(tester);
    });
  });
}
