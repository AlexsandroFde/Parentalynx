import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/core/navigation/launch_action.dart';
import 'package:parentalynx/features/child_mode/child_mode_routes.dart';
import 'package:parentalynx/features/device_linking/domain/entities/link_state.dart';
import 'package:parentalynx/features/device_linking/domain/repositories/i_link_state_repository.dart';

import '../../support/fakes.dart';
import '../../support/test_dependencies.dart';
import 'support/child_app.dart';
import 'support/child_fakes.dart';

void main() {
  late TestDependencies deps;
  late ChildBridge bridge;
  late FakeLaunchActionSource launch;

  setUpAll(registerChildFallbacks);

  setUp(() {
    launch = FakeLaunchActionSource();
    (:deps, :bridge) = childDependencies(launchActions: launch);
    addTearDown(deps.dispose);
  });

  LinkPhase phase() => deps.di<ILinkStateRepository>().current.phase;

  Future<void> settle(WidgetTester tester, {int frames = 4}) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  group('redirecionamento pela fase do vinculo', () {
    test('sem resposta do agente so a tela de entrada', () {
      expect(childRedirect(LinkPhase.unknown, ChildPaths.home), ChildPaths.root);
      expect(childRedirect(LinkPhase.failed, ChildPaths.root), isNull);
    });

    test('sem vinculo so a tela do codigo', () {
      expect(childRedirect(LinkPhase.unlinked, ChildPaths.root), ChildPaths.link);
      expect(childRedirect(LinkPhase.unlinked, ChildPaths.link), isNull);
    });

    test('recem-vinculado so a configuracao inicial', () {
      expect(childRedirect(LinkPhase.onboarding, ChildPaths.home), ChildPaths.setupTransparency);
      expect(childRedirect(LinkPhase.onboarding, ChildPaths.setupPermissions), isNull);
    });

    test('pronto sai das telas de entrada e deixa as demais', () {
      expect(childRedirect(LinkPhase.ready, ChildPaths.link), ChildPaths.home);
      expect(childRedirect(LinkPhase.ready, ChildPaths.setupTransparency), ChildPaths.home);
      expect(childRedirect(LinkPhase.ready, ChildPaths.guardianArea), isNull);
      expect(childRedirect(LinkPhase.ready, ChildPaths.about), isNull);
    });
  });

  testWidgets('aparelho sem vinculo abre a tela do codigo', (WidgetTester tester) async {
    bridge.status = fakeStatus(active: false);
    await pumpChildArea(tester, deps.di);

    expect(phase(), LinkPhase.unlinked);
    expect(find.text('Vincular este aparelho'), findsOneWidget);
    verifyNever(bridge.agent.ensureRunning);
    await unmountChildApp(tester, deps.di);
  });

  testWidgets('aparelho vinculado abre a tela inicial e liga o agente', (
    WidgetTester tester,
  ) async {
    await pumpChildArea(tester, deps.di);

    expect(phase(), LinkPhase.ready);
    expect(find.text('Olá, João!'), findsOneWidget);
    verify(bridge.agent.ensureRunning).called(greaterThanOrEqualTo(1));
    await unmountChildApp(tester, deps.di);
  });

  testWidgets('recem-vinculado passa pela transparencia e pelas permissoes', (
    WidgetTester tester,
  ) async {
    bridge.status = fakeStatus(active: false);
    await pumpChildArea(tester, deps.di);

    // O mesmo efeito da ativacao do agente depois da aprovacao.
    bridge.status = fakeStatus();
    deps.di<ILinkStateRepository>().update(const LinkState(LinkPhase.onboarding));
    await settle(tester);
    expect(find.text('O que este app faz'), findsOneWidget);
    expect(find.text('O que este app NÃO vê'), findsOneWidget);

    await tester.tap(find.text('Entendi, continuar'));
    await settle(tester);
    expect(find.text('Permissões do controle'), findsOneWidget);

    await tester.tap(find.text('Concluir'));
    await settle(tester);
    expect(phase(), LinkPhase.ready);
    expect(find.text('Olá, João!'), findsOneWidget);
    await unmountChildApp(tester, deps.di);
  });

  testWidgets('acao de abertura leva a area do responsavel', (WidgetTester tester) async {
    launch.open(LaunchAction.guardianArea);
    await pumpChildArea(tester, deps.di);
    await settle(tester);

    expect(find.text('Só para o responsável'), findsOneWidget);
    expect(launch.pending, isNull);

    // Voltar leva a tela inicial, aberta por baixo da area do responsavel.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Olá, João!'), findsOneWidget);
    await unmountChildApp(tester, deps.di);
  });

  testWidgets('vinculo removido pelo responsavel volta a tela do codigo com o aviso', (
    WidgetTester tester,
  ) async {
    await pumpChildArea(tester, deps.di);
    expect(find.text('Olá, João!'), findsOneWidget);

    bridge.status = fakeStatus(active: false);
    await settle(tester, frames: 8);

    expect(find.text('Vincular este aparelho'), findsOneWidget);
    expect(find.textContaining('foi removido pelo responsável'), findsOneWidget);
    await unmountChildApp(tester, deps.di);
  });

  testWidgets('falha ao consultar o agente oferece tentar de novo', (WidgetTester tester) async {
    when(bridge.agent.getStatus).thenThrow(PlatformException(code: 'channel-error'));
    await pumpChildArea(tester, deps.di);

    expect(phase(), LinkPhase.failed);
    expect(find.text('Tentar de novo'), findsOneWidget);

    when(bridge.agent.getStatus).thenAnswer((_) async => fakeStatus(active: false));
    await tester.tap(find.text('Tentar de novo'));
    await settle(tester);
    expect(find.text('Vincular este aparelho'), findsOneWidget);
    await unmountChildApp(tester, deps.di);
  });
}
