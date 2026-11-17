import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/platform/native_providers.dart';
import 'package:parentalynx/features/child/agent/presentation/child_session.dart';
import 'package:parentalynx/features/child/browser/domain/browser_navigation.dart';
import 'package:parentalynx/features/child/browser/presentation/browser_controller.dart';
import 'package:parentalynx/features/child/browser/presentation/browser_engine.dart';
import 'package:parentalynx/features/child/guardian_area/presentation/guardian_area_controller.dart';

import 'support/child_fakes.dart';

AdminAuthResult _auth(AdminAuthOutcome outcome, {int retry = 0, int attempts = -1}) {
  return AdminAuthResult(outcome: outcome, retryAfterSec: retry, attemptsLeft: attempts);
}

void main() {
  setUpAll(registerChildFallbacks);

  group('area do responsavel', () {
    late ChildBridge bridge;

    setUp(() => bridge = ChildBridge());

    ProviderContainer build() {
      final ProviderContainer container = ProviderContainer(overrides: bridge.overrides());
      addTearDown(container.dispose);
      container.listen<GuardianAreaState>(guardianAreaControllerProvider, (_, _) {});
      return container;
    }

    test('senha correta libera a area', () async {
      when(() => bridge.agent.verifyAdminPassword('Senha#Forte1'))
          .thenAnswer((_) async => _auth(AdminAuthOutcome.ok));
      final ProviderContainer container = build();

      await container.read(guardianAreaControllerProvider.notifier).verifyPassword('Senha#Forte1');

      expect(container.read(guardianAreaControllerProvider).unlocked, isTrue);
    });

    test('senha incorreta mostra as tentativas restantes', () async {
      when(() => bridge.agent.verifyAdminPassword(any()))
          .thenAnswer((_) async => _auth(AdminAuthOutcome.invalid, attempts: 2));
      final ProviderContainer container = build();

      await container.read(guardianAreaControllerProvider.notifier).verifyPassword('errada');

      final GuardianAreaState state = container.read(guardianAreaControllerProvider);
      expect(state.unlocked, isFalse);
      expect(state.error, 'Senha incorreta. Restam 2 tentativas.');
    });

    test('bloqueio por tentativas informa o tempo de espera', () async {
      when(() => bridge.agent.verifyAdminPassword(any()))
          .thenAnswer((_) async => _auth(AdminAuthOutcome.locked, retry: 600));
      final ProviderContainer container = build();

      await container.read(guardianAreaControllerProvider.notifier).verifyPassword('x');

      expect(container.read(guardianAreaControllerProvider).error, contains('10min'));
    });

    test('sem conexao oferece o codigo de acesso offline', () async {
      when(() => bridge.agent.verifyAdminPassword(any()))
          .thenAnswer((_) async => _auth(AdminAuthOutcome.offline));
      final ProviderContainer container = build();

      await container.read(guardianAreaControllerProvider.notifier).verifyPassword('x');

      final GuardianAreaState state = container.read(guardianAreaControllerProvider);
      expect(state.codeMode, isTrue);
      expect(state.error, contains('código de acesso offline'));
    });

    test('codigo offline valido libera a area', () async {
      when(() => bridge.agent.verifyOfflineCode('12345678'))
          .thenAnswer((_) async => _auth(AdminAuthOutcome.ok));
      final ProviderContainer container = build();
      final GuardianAreaController controller = container.read(
        guardianAreaControllerProvider.notifier,
      );

      await controller.verifyOfflineCode('1234');
      expect(container.read(guardianAreaControllerProvider).error, 'O código tem 8 números.');
      await controller.verifyOfflineCode('1234 5678');

      expect(container.read(guardianAreaControllerProvider).unlocked, isTrue);
    });

    test('erro inesperado da ponte vira mensagem sem detalhes tecnicos', () async {
      when(() => bridge.agent.verifyAdminPassword(any())).thenThrow(
        PlatformException(code: 'NullPointerException', message: 'npe', details: 'Cause: null'),
      );
      final ProviderContainer container = build();

      await container.read(guardianAreaControllerProvider.notifier).verifyPassword('x');

      expect(
        container.read(guardianAreaControllerProvider).error,
        'O aparelho não respondeu como esperado. Tente de novo.',
      );
    });

    test('operacao recusada com acesso vencido volta a pedir a senha', () async {
      when(() => bridge.agent.verifyAdminPassword(any()))
          .thenAnswer((_) async => _auth(AdminAuthOutcome.ok));
      when(() => bridge.agent.grantLocalOverride(30)).thenThrow(
        PlatformException(code: 'admin_auth_required', message: 'Autenticação necessária.'),
      );
      when(() => bridge.agent.isAdminAuthValid()).thenAnswer((_) async => false);
      final ProviderContainer container = build();
      final GuardianAreaController controller = container.read(
        guardianAreaControllerProvider.notifier,
      );
      await controller.verifyPassword('Senha#Forte1');

      await expectLater(controller.grantOverride(30), throwsA(isA<AppFailure>()));

      final GuardianAreaState state = container.read(guardianAreaControllerProvider);
      expect(state.unlocked, isFalse);
      expect(state.error, contains('venceu'));
    });

    test('desvincular revoga com a senha, marca sem vinculo e volta a escolha de modo', () async {
      when(() => bridge.agent.verifyAdminPassword(any()))
          .thenAnswer((_) async => _auth(AdminAuthOutcome.ok));
      when(() => bridge.agent.unlink('Senha#Forte1')).thenAnswer((_) async => true);
      when(() => bridge.mode.setMode(AppMode.unset)).thenAnswer((_) async {});
      final ProviderContainer container = build();
      final GuardianAreaController controller = container.read(
        guardianAreaControllerProvider.notifier,
      );
      await controller.verifyPassword('Senha#Forte1');

      expect(await controller.unlink(), isTrue);

      verify(() => bridge.agent.unlink('Senha#Forte1')).called(1);
      verify(() => bridge.mode.setMode(AppMode.unset)).called(1);
      expect(container.read(childLinkProvider), ChildLinkPhase.unlinked);
      expect(container.read(appModeProvider), AppMode.unset);
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
      when(() => api.recordVisit(any(), any(), any(), any())).thenAnswer((_) async {});
    });

    Future<ProviderContainer> build() async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          browserApiProvider.overrideWithValue(api),
          browserEngineProvider.overrideWithValue(engine),
        ],
      );
      addTearDown(container.dispose);
      container.listen<BrowserState>(browserControllerProvider, (_, _) {});
      await pumpEventQueue();
      return container;
    }

    void decide(String url, UrlDecision decision) {
      when(() => api.evaluateUrl(url)).thenAnswer((_) async => decision);
    }

    test('configuracao desligada deixa o navegador indisponivel', () async {
      when(api.getConfig).thenAnswer(
        (_) async => BrowserConfig(
          enabled: false,
          logHistory: false,
          safeSearch: false,
          allowlistMode: false,
        ),
      );
      final ProviderContainer container = await build();

      expect(container.read(browserControllerProvider).phase, BrowserPhase.disabled);
      await container.read(browserControllerProvider.notifier).open('https://exemplo.com');
      expect(engine.loaded, isEmpty);
    });

    test('endereco liberado e carregado e a visita e registrada com o titulo', () async {
      decide('https://exemplo.com', UrlDecision(allowed: true));
      final ProviderContainer container = await build();
      final BrowserController controller = container.read(browserControllerProvider.notifier);

      await controller.submitAddress('exemplo.com');
      expect(engine.loaded, <String>['https://exemplo.com']);

      engine.pageTitle = 'Exemplo';
      controller.onPageFinished('https://exemplo.com');
      await pumpEventQueue();

      final BrowserState state = container.read(browserControllerProvider);
      expect(state.title, 'Exemplo');
      expect(state.blocked, isNull);
      verify(() => api.recordVisit('https://exemplo.com', 'Exemplo', false, null)).called(1);
    });

    test('endereco barrado nao carrega, mostra o bloqueio e registra a tentativa', () async {
      decide('https://ruim.com', UrlDecision(allowed: false, reason: 'domain_blocked'));
      final ProviderContainer container = await build();

      await container.read(browserControllerProvider.notifier).open('https://ruim.com');

      final BrowserState state = container.read(browserControllerProvider);
      expect(engine.loaded, isEmpty);
      expect(state.blocked!.domain, 'ruim.com');
      expect(state.blocked!.reason, 'domain_blocked');
      verify(() => api.recordVisit('https://ruim.com', null, true, 'domain_blocked')).called(1);
    });

    test('busca segura carrega o endereco reescrito', () async {
      const String asked = 'https://www.google.com/search?q=lince';
      const String safe = 'https://www.google.com/search?q=lince&safe=active';
      decide(asked, UrlDecision(allowed: true, rewrittenUrl: safe));
      final ProviderContainer container = await build();

      await container.read(browserControllerProvider.notifier).submitAddress('lince');

      expect(engine.loaded, <String>[safe]);
    });

    test('link tocado na pagina passa pelo filtro', () async {
      decide('https://ok.com/a', UrlDecision(allowed: true));
      decide(
        'https://ruim.com/',
        UrlDecision(allowed: false, reason: 'category', category: 'adult'),
      );
      const String asked = 'https://www.bing.com/search?q=x';
      decide(asked, UrlDecision(allowed: true, rewrittenUrl: '$asked&adlt=strict'));
      final ProviderContainer container = await build();
      final BrowserController controller = container.read(browserControllerProvider.notifier);

      expect(await controller.onNavigationRequest('https://ok.com/a', isMainFrame: true), isTrue);
      expect(await controller.onNavigationRequest('https://ruim.com/', isMainFrame: true), isFalse);
      expect(container.read(browserControllerProvider).blocked!.category, 'adult');
      // Quadros internos nao sao avaliados.
      expect(
        await controller.onNavigationRequest('https://anuncio.com', isMainFrame: false),
        isTrue,
      );
      verifyNever(() => api.evaluateUrl('https://anuncio.com'));
      // Busca reescrita: impede o pedido original e carrega o endereco seguro.
      expect(await controller.onNavigationRequest(asked, isMainFrame: true), isFalse);
      expect(engine.loaded, <String>['$asked&adlt=strict']);
    });

    test('links que nao sao http ou https nao abrem', () async {
      final ProviderContainer container = await build();
      final BrowserController controller = container.read(browserControllerProvider.notifier);

      expect(
        await controller.onNavigationRequest('intent://app#Intent;end', isMainFrame: true),
        isFalse,
      );

      expect(container.read(browserControllerProvider).notice, contains('não abre'));
      verifyNever(() => api.evaluateUrl(any()));
    });

    test('sem resposta do filtro a pagina nao abre', () async {
      when(() => api.evaluateUrl(any())).thenThrow(PlatformException(code: 'channel-error'));
      final ProviderContainer container = await build();

      await container.read(browserControllerProvider.notifier).open('https://exemplo.com');

      final BrowserState state = container.read(browserControllerProvider);
      expect(engine.loaded, isEmpty);
      expect(state.blocked!.reason, NavigationVerdict.checkFailedReason);
      verifyNever(() => api.recordVisit(any(), any(), any(), any()));
    });

    test('pagina iniciada sem passar pelo filtro e conferida e coberta se barrada', () async {
      decide('https://ruim.com/volta', UrlDecision(allowed: false, reason: 'safe_dns'));
      final ProviderContainer container = await build();
      final BrowserController controller = container.read(browserControllerProvider.notifier);

      controller.onPageStarted('https://ruim.com/volta');
      await pumpEventQueue();

      expect(container.read(browserControllerProvider).blocked!.reason, 'safe_dns');
      expect(engine.loaded, <String>[blankPageUrl]);
    });

    test('voltar sai do bloqueio para a pagina anterior ou para o inicio', () async {
      decide('https://ruim.com', UrlDecision(allowed: false, reason: 'domain_blocked'));
      final ProviderContainer container = await build();
      final BrowserController controller = container.read(browserControllerProvider.notifier);
      await controller.open('https://ruim.com');

      expect(await controller.goBack(), isTrue);
      expect(container.read(browserControllerProvider).showStartPage, isTrue);
      // Na pagina inicial nao ha para onde voltar: quem chama fecha o navegador.
      expect(await controller.goBack(), isFalse);
    });
  });
}
