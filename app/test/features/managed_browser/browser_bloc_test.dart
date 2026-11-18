import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/platform/native_api.g.dart';
import 'package:parentalynx/core/platform/native_events.dart';
import 'package:parentalynx/features/managed_browser/domain/entities/navigation_verdict.dart';
import 'package:parentalynx/features/managed_browser/domain/services/browser_navigation_rules.dart';
import 'package:parentalynx/features/managed_browser/managed_browser_module.dart';
import 'package:parentalynx/features/managed_browser/presentation/bloc/browser_bloc.dart';

import '../../support/native_doubles.dart';
import '../../support/test_dependencies.dart';
import 'support/fake_browser_engine.dart';

void main() {
  late TestDependencies deps;
  late MockBrowserApi api;
  late FakeBrowserEngine engine;

  setUp(() {
    deps = TestDependencies();
    addTearDown(deps.dispose);
    registerManagedBrowserModule(deps.di);
    api = deps.native.browser;
    engine = FakeBrowserEngine();
    when(api.getConfig).thenAnswer(
      (_) async =>
          BrowserConfig(enabled: true, logHistory: true, safeSearch: true, allowlistMode: false),
    );
    when(api.consumeInitialUrl).thenAnswer((_) async => null);
    when(() => api.recordVisit(any(), any(), any(), any())).thenAnswer((_) async {});
  });

  Future<BrowserBloc> build() async {
    final BrowserBloc bloc = deps.di<BrowserBloc>(param1: engine)..add(const BrowserStarted());
    addTearDown(bloc.close);
    await pumpEventQueue();
    return bloc;
  }

  BrowserReady ready(BrowserBloc bloc) => bloc.state as BrowserReady;

  void decide(String url, UrlDecision decision) {
    when(() => api.evaluateUrl(url)).thenAnswer((_) async => decision);
  }

  test('configuracao desligada deixa o navegador indisponivel', () async {
    when(api.getConfig).thenAnswer(
      (_) async =>
          BrowserConfig(enabled: false, logHistory: false, safeSearch: false, allowlistMode: false),
    );
    final BrowserBloc bloc = await build();

    expect(bloc.state, isA<BrowserUnavailable>());
    bloc
      ..add(const BrowserUrlRequested('https://exemplo.com'))
      ..add(const BrowserAddressSubmitted('exemplo.com'));
    await pumpEventQueue();
    expect(engine.loaded, isEmpty);
  });

  test('sem resposta do agente o navegador fica indisponivel', () async {
    when(api.getConfig).thenThrow(PlatformException(code: 'channel-error'));

    final BrowserBloc bloc = await build();

    expect(bloc.state, isA<BrowserUnavailable>());
  });

  test('endereco liberado e carregado e a visita e registrada com o titulo', () async {
    decide('https://exemplo.com', UrlDecision(allowed: true));
    final BrowserBloc bloc = await build();

    bloc.add(const BrowserAddressSubmitted('exemplo.com'));
    await pumpEventQueue();
    expect(engine.loaded, <String>['https://exemplo.com']);

    engine.pageTitle = 'Exemplo';
    engine.delegate!.onPageFinished('https://exemplo.com');
    await pumpEventQueue();

    expect(ready(bloc).title, 'Exemplo');
    expect(ready(bloc).blocked, isNull);
    verify(() => api.recordVisit('https://exemplo.com', 'Exemplo', false, null)).called(1);
  });

  test('endereco barrado nao carrega, mostra o bloqueio e registra a tentativa', () async {
    decide('https://ruim.com', UrlDecision(allowed: false, reason: 'domain_blocked'));
    final BrowserBloc bloc = await build();

    bloc.add(const BrowserUrlRequested('https://ruim.com'));
    await pumpEventQueue();

    expect(engine.loaded, isEmpty);
    expect(ready(bloc).blocked!.domain, 'ruim.com');
    expect(ready(bloc).blocked!.reason, 'domain_blocked');
    verify(() => api.recordVisit('https://ruim.com', null, true, 'domain_blocked')).called(1);
  });

  test('busca segura carrega o endereco reescrito', () async {
    const String asked = 'https://www.google.com/search?q=lince';
    const String safe = 'https://www.google.com/search?q=lince&safe=active';
    decide(asked, UrlDecision(allowed: true, rewrittenUrl: safe));
    final BrowserBloc bloc = await build();

    bloc.add(const BrowserAddressSubmitted('lince'));
    await pumpEventQueue();

    expect(engine.loaded, <String>[safe]);
  });

  test('link tocado na pagina passa pelo filtro', () async {
    decide('https://ok.com/a', UrlDecision(allowed: true));
    decide('https://ruim.com/', UrlDecision(allowed: false, reason: 'category', category: 'adult'));
    const String asked = 'https://www.bing.com/search?q=x';
    decide(asked, UrlDecision(allowed: true, rewrittenUrl: '$asked&adlt=strict'));
    final BrowserBloc bloc = await build();
    final BrowserEngineDelegateProbe probe = BrowserEngineDelegateProbe(engine);

    expect(await probe.request('https://ok.com/a'), isTrue);
    expect(await probe.request('https://ruim.com/'), isFalse);
    expect(ready(bloc).blocked!.category, 'adult');
    // Quadros internos nao sao avaliados.
    expect(await probe.request('https://anuncio.com', mainFrame: false), isTrue);
    verifyNever(() => api.evaluateUrl('https://anuncio.com'));
    // Busca reescrita: impede o pedido original e carrega o endereco seguro.
    expect(await probe.request(asked), isFalse);
    expect(engine.loaded, <String>['$asked&adlt=strict']);
  });

  test('links que nao sao http ou https nao abrem', () async {
    final BrowserBloc bloc = await build();

    expect(await BrowserEngineDelegateProbe(engine).request('intent://app#Intent;end'), isFalse);

    expect(ready(bloc).notice, contains('não abre'));
    verifyNever(() => api.evaluateUrl(any()));

    bloc.add(const BrowserNoticeCleared());
    await pumpEventQueue();
    expect(ready(bloc).notice, isNull);
  });

  test('sem resposta do filtro a pagina nao abre', () async {
    when(() => api.evaluateUrl(any())).thenThrow(PlatformException(code: 'channel-error'));
    final BrowserBloc bloc = await build();

    bloc.add(const BrowserUrlRequested('https://exemplo.com'));
    await pumpEventQueue();

    expect(engine.loaded, isEmpty);
    expect(ready(bloc).blocked!.reason, NavigationVerdict.checkFailedReason);
    verifyNever(() => api.recordVisit(any(), any(), any(), any()));
  });

  test('pagina iniciada sem passar pelo filtro e conferida e coberta se barrada', () async {
    decide('https://ruim.com/volta', UrlDecision(allowed: false, reason: 'safe_dns'));
    final BrowserBloc bloc = await build();

    engine.delegate!.onPageStarted('https://ruim.com/volta');
    await pumpEventQueue();

    expect(ready(bloc).blocked!.reason, 'safe_dns');
    expect(engine.loaded, <String>[blankPageUrl]);
  });

  test('voltar sai do bloqueio para a pagina anterior ou para o inicio', () async {
    decide('https://ruim.com', UrlDecision(allowed: false, reason: 'domain_blocked'));
    final BrowserBloc bloc = await build();
    bloc.add(const BrowserUrlRequested('https://ruim.com'));
    await pumpEventQueue();

    bloc.add(const BrowserBackRequested());
    await pumpEventQueue();

    expect(ready(bloc).showStartPage, isTrue);
    // Na pagina inicial nao ha para onde voltar: a tela fecha o navegador.
    expect(ready(bloc).hasPage, isFalse);
    expect(engine.loaded, <String>[blankPageUrl]);
  });

  test('erro ao carregar a pagina principal aparece e recarregar tenta de novo', () async {
    decide('https://exemplo.com', UrlDecision(allowed: true));
    final BrowserBloc bloc = await build();
    bloc.add(const BrowserUrlRequested('https://exemplo.com'));
    await pumpEventQueue();

    engine.delegate!.onMainFrameError('net::ERR_INTERNET_DISCONNECTED');
    await pumpEventQueue();
    expect(ready(bloc).loadError, contains('Confira a internet'));

    bloc.add(const BrowserReloadRequested());
    await pumpEventQueue();
    expect(engine.reloads, 1);
  });

  test('endereco com que o navegador foi aberto e carregado quando ele fica pronto', () async {
    when(api.consumeInitialUrl).thenAnswer((_) async => 'https://exemplo.com/link');
    decide('https://exemplo.com/link', UrlDecision(allowed: true));

    await build();

    expect(engine.loaded, <String>['https://exemplo.com/link']);
  });

  test('endereco recebido com o navegador aberto passa pelo filtro', () async {
    decide('https://ok.com/b', UrlDecision(allowed: true));
    await build();

    deps.di<NativeEventsDispatcher>().onOpenUrl('https://ok.com/b');
    await pumpEventQueue();

    expect(engine.loaded, <String>['https://ok.com/b']);
  });

  test('a configuracao e relida ao voltar e as liberacoes antigas deixam de valer', () async {
    decide('https://ok.com/a', UrlDecision(allowed: true));
    final BrowserBloc bloc = await build();
    final BrowserEngineDelegateProbe probe = BrowserEngineDelegateProbe(engine);
    expect(await probe.request('https://ok.com/a'), isTrue);

    decide('https://ok.com/a', UrlDecision(allowed: false, reason: 'domain_blocked'));
    when(api.getConfig).thenAnswer(
      (_) async =>
          BrowserConfig(enabled: true, logHistory: false, safeSearch: true, allowlistMode: true),
    );
    bloc.add(const BrowserSettingsRefreshRequested());
    await pumpEventQueue();

    expect(ready(bloc).settings.allowlistMode, isTrue);
    expect(await probe.request('https://ok.com/a'), isFalse);
  });

  test('pedido de navegacao sem resposta e recusado quando o navegador fecha', () async {
    final Completer<UrlDecision> pending = Completer<UrlDecision>();
    when(() => api.evaluateUrl('https://lento.com')).thenAnswer((_) => pending.future);
    final BrowserBloc bloc = await build();

    final Future<bool> decision = BrowserEngineDelegateProbe(engine).request('https://lento.com');
    await pumpEventQueue();
    await bloc.close();

    expect(await decision, isFalse);
    pending.complete(UrlDecision(allowed: true));
  });
}

/// Simula os pedidos de navegacao do WebView pelo delegado registrado no motor.
class BrowserEngineDelegateProbe {
  const BrowserEngineDelegateProbe(this.engine);

  final FakeBrowserEngine engine;

  Future<bool> request(String url, {bool mainFrame = true}) {
    return engine.delegate!.onNavigationRequest(url, isMainFrame: mainFrame);
  }
}
