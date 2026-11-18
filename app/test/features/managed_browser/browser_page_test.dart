import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/app/browser_app.dart';
import 'package:parentalynx/core/platform/native_api.g.dart';
import 'package:parentalynx/features/managed_browser/managed_browser_module.dart';
import 'package:parentalynx/features/managed_browser/presentation/bloc/browser_bloc.dart';
import 'package:parentalynx/features/managed_browser/presentation/engine/browser_engine.dart';
import 'package:parentalynx/features/managed_browser/presentation/pages/browser_page.dart';

import '../../support/native_doubles.dart';
import '../../support/test_app.dart';
import '../../support/test_dependencies.dart';
import 'support/fake_browser_engine.dart';

/// Deixa as respostas dos dubles chegarem e as animacoes de entrada terminarem.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 600));
}

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

  /// O BLoC e criado pela arvore e fechado quando ela e desmontada, ainda no tempo simulado
  /// do teste.
  Future<BrowserBloc> pumpBrowser(WidgetTester tester) async {
    await pumpWidgetInApp(
      tester,
      RepositoryProvider<BrowserEngine>.value(
        value: engine,
        child: BlocProvider<BrowserBloc>(
          create: (BuildContext context) {
            return deps.di<BrowserBloc>(param1: engine)..add(const BrowserStarted());
          },
          child: const BrowserPage(),
        ),
      ),
      di: deps.di,
    );
    await _settle(tester);
    return BlocProvider.of<BrowserBloc>(tester.element(find.byType(BrowserPage)));
  }

  testWidgets('pagina inicial avisa que o historico e visto pelo responsavel', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    await pumpBrowser(tester);

    expect(find.text('Navegador ParentaLynx'), findsOneWidget);
    expect(find.text('O responsável vê o histórico deste navegador.'), findsOneWidget);
    expect(find.textContaining('A busca segura está ligada'), findsOneWidget);
    await expectScreenshot(tester, 'child_browser_start');
  });

  testWidgets('site barrado mostra a pagina de bloqueio com o motivo', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    when(() => api.evaluateUrl('https://apostas.exemplo/')).thenAnswer(
      (_) async => UrlDecision(allowed: false, reason: 'category', category: 'gambling'),
    );
    final BrowserBloc bloc = await pumpBrowser(tester);

    await tester.enterText(find.byType(EditableText), 'https://apostas.exemplo/');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await _settle(tester);

    expect(find.text('Este site não abre aqui'), findsOneWidget);
    expect(find.text('apostas.exemplo'), findsWidgets);
    expect(find.textContaining('apostas e jogos de azar'), findsOneWidget);
    expect(engine.loaded, isEmpty);
    expect((bloc.state as BrowserReady).blocked, isNotNull);
    await expectScreenshot(tester, 'child_browser_blocked');

    await tester.tap(find.text('Ir para a página inicial'));
    await _settle(tester);
    expect(find.text('Navegador ParentaLynx'), findsOneWidget);
  });

  testWidgets('navegador desligado pelo responsavel fica indisponivel', (
    WidgetTester tester,
  ) async {
    when(api.getConfig).thenAnswer(
      (_) async =>
          BrowserConfig(enabled: false, logHistory: false, safeSearch: false, allowlistMode: false),
    );
    await pumpBrowser(tester);

    expect(find.text('Navegador indisponível'), findsOneWidget);
  });

  testWidgets('link de um tipo que nao abre aqui vira um aviso', (WidgetTester tester) async {
    await pumpBrowser(tester);

    final Future<bool> allowed = engine.delegate!.onNavigationRequest(
      'intent://app#Intent;end',
      isMainFrame: true,
    );
    await _settle(tester);

    expect(await allowed, isFalse);
    expect(find.text('Este tipo de link não abre no navegador seguro.'), findsOneWidget);
  });

  testWidgets('a raiz do navegador monta a tela com o motor do conteiner', (
    WidgetTester tester,
  ) async {
    deps.di.registerFactory<BrowserEngine>(() => engine);
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = phoneSize * 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(BrowserApp(di: deps.di));
    await _settle(tester);

    expect(find.text('Navegador ParentaLynx'), findsOneWidget);
    expect(engine.delegate, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
}
