import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide LockState;
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/app/app.dart';
import 'package:parentalynx/app/theme/app_theme.dart';
import 'package:parentalynx/features/child/agent/presentation/child_session.dart';
import 'package:parentalynx/features/child/child_routes.dart';

import '../../support/test_app.dart';
import 'support/child_fakes.dart';

class _Refresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// Roteador so com a area da crianca, ligado como em `lib/app/router.dart`.
final Provider<GoRouter> _routerProvider = Provider<GoRouter>((Ref ref) {
  final _Refresh refresh = _Refresh();
  ref.onDispose(refresh.dispose);
  registerChildRouterRefresh(ref, refresh.refresh);
  final GoRouter router = GoRouter(
    initialLocation: ChildPaths.root,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) => childRedirect(ref, state),
    routes: childRoutes,
  );
  ref.onDispose(router.dispose);
  return router;
});

class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: ref.watch(_routerProvider),
      theme: AppTheme.light(),
      locale: appLocale,
      supportedLocales: const <Locale>[appLocale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: wrapAppContent,
    );
  }
}

void main() {
  late ChildBridge bridge;

  setUpAll(registerChildFallbacks);

  setUp(() {
    bridge = ChildBridge();
    when(bridge.mode.consumeLaunchAction).thenAnswer((_) async => null);
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = phoneSize * 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: bridge.overrides(), child: const _App()));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    return ProviderScope.containerOf(tester.element(find.byType(_App)));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('aparelho sem vinculo abre a tela do codigo', (WidgetTester tester) async {
    bridge.status = fakeStatus(active: false);
    final ProviderContainer container = await pumpApp(tester);

    expect(container.read(childLinkProvider), ChildLinkPhase.unlinked);
    expect(find.text('Vincular este aparelho'), findsOneWidget);
    verifyNever(bridge.agent.ensureRunning);
    await unmount(tester);
  });

  testWidgets('aparelho vinculado abre a tela inicial e liga o agente', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(tester);

    expect(container.read(childLinkProvider), ChildLinkPhase.ready);
    expect(find.text('Olá, João!'), findsOneWidget);
    verify(bridge.agent.ensureRunning).called(greaterThanOrEqualTo(1));
    await unmount(tester);
  });

  testWidgets('recem-vinculado passa pela transparencia e pelas permissoes', (
    WidgetTester tester,
  ) async {
    bridge.status = fakeStatus(active: false);
    final ProviderContainer container = await pumpApp(tester);

    bridge.status = fakeStatus();
    container.read(childLinkProvider.notifier).markLinked();
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('O que este app faz'), findsOneWidget);
    expect(find.text('O que este app NÃO vê'), findsOneWidget);

    await tester.tap(find.text('Entendi, continuar'));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Permissões do controle'), findsOneWidget);

    await tester.tap(find.text('Concluir'));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(container.read(childLinkProvider), ChildLinkPhase.ready);
    expect(find.text('Olá, João!'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('acao de abertura leva a area do responsavel', (WidgetTester tester) async {
    when(bridge.mode.consumeLaunchAction).thenAnswer((_) async => 'guardian_area');
    await pumpApp(tester);

    expect(find.text('Só para o responsável'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('vinculo removido pelo responsavel volta a tela do codigo com o aviso', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Olá, João!'), findsOneWidget);

    bridge.status = fakeStatus(active: false);
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Vincular este aparelho'), findsOneWidget);
    expect(find.textContaining('foi removido pelo responsável'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('falha ao consultar o agente oferece tentar de novo', (WidgetTester tester) async {
    when(bridge.agent.getStatus).thenThrow(PlatformException(code: 'channel-error'));
    final ProviderContainer container = await pumpApp(tester);

    expect(container.read(childLinkProvider), ChildLinkPhase.failed);
    expect(find.text('Tentar de novo'), findsOneWidget);

    when(bridge.agent.getStatus).thenAnswer((_) async => fakeStatus(active: false));
    await tester.tap(find.text('Tentar de novo'));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Vincular este aparelho'), findsOneWidget);
    await unmount(tester);
  });
}
