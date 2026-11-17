import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/platform/native_api.g.dart';
import 'package:parentalynx/core/platform/native_providers.dart';
import 'package:parentalynx/features/onboarding/presentation/welcome_page.dart';

import '../../support/test_app.dart';

class _MockAppModeApi extends Mock implements AppModeApi {}

void main() {
  late _MockAppModeApi modeApi;

  setUpAll(() {
    registerFallbackValue(AppMode.unset);
  });

  setUp(() {
    modeApi = _MockAppModeApi();
    when(() => modeApi.setMode(any())).thenAnswer((_) async {});
  });

  List<Override> overrides({String serverUrl = 'https://servidor.teste'}) {
    return <Override>[
      ...baseOverrides(serverUrl: serverUrl),
      appModeApiProvider.overrideWithValue(modeApi),
    ];
  }

  testWidgets('mostra as duas opcoes de modo e o aviso de transparencia', (
    WidgetTester tester,
  ) async {
    await pumpWidgetInApp(tester, const WelcomePage(), overrides: overrides());

    expect(find.text('Sou o responsável'), findsOneWidget);
    expect(find.text('Este é o aparelho da criança'), findsOneWidget);
    expect(find.text('Controle transparente'), findsOneWidget);
    expect(find.text('Configurar servidor'), findsOneWidget);
  });

  testWidgets('escolher responsavel grava o modo no lado nativo', (WidgetTester tester) async {
    await pumpWidgetInApp(tester, const WelcomePage(), overrides: overrides());

    await tester.tap(find.text('Sou o responsável'));
    await tester.pumpAndSettle();

    verify(() => modeApi.setMode(AppMode.guardian)).called(1);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(WelcomePage)),
    );
    expect(container.read(appModeProvider), AppMode.guardian);
  });

  testWidgets('escolher crianca grava o modo crianca', (WidgetTester tester) async {
    await pumpWidgetInApp(tester, const WelcomePage(), overrides: overrides());

    await tester.tap(find.text('Este é o aparelho da criança'));
    await tester.pumpAndSettle();

    verify(() => modeApi.setMode(AppMode.child)).called(1);
  });

  testWidgets('sem servidor configurado pede o endereco antes de escolher', (
    WidgetTester tester,
  ) async {
    await pumpWidgetInApp(tester, const WelcomePage(), overrides: overrides(serverUrl: ''));

    await tester.tap(find.text('Sou o responsável'));
    await tester.pumpAndSettle();

    expect(find.text('Servidor'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
    verifyNever(() => modeApi.setMode(any()));
  });

  testWidgets('falha do lado nativo e mostrada e o modo nao muda', (WidgetTester tester) async {
    when(() => modeApi.setMode(any())).thenThrow(
      PlatformException(code: 'denied', message: 'Autenticação do responsável necessária.'),
    );
    await pumpWidgetInApp(tester, const WelcomePage(), overrides: overrides());

    await tester.tap(find.text('Sou o responsável'));
    await tester.pumpAndSettle();

    expect(find.text('Autenticação do responsável necessária.'), findsOneWidget);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(WelcomePage)),
    );
    expect(container.read(appModeProvider), AppMode.unset);
  });

  testWidgets('captura da tela de boas-vindas', tags: 'screenshot', (WidgetTester tester) async {
    await pumpWidgetInApp(tester, const WelcomePage(), overrides: overrides());
    await expectScreenshot(tester, 'onboarding_welcome');
  });
}
