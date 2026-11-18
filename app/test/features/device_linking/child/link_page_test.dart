import 'dart:async';

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/constants/storage_keys.dart';
import 'package:parentalynx/features/device_linking/domain/entities/link_state.dart';
import 'package:parentalynx/features/device_linking/domain/repositories/i_link_state_repository.dart';
import 'package:parentalynx/features/device_linking/presentation/bloc/child_link/child_link_bloc.dart';
import 'package:parentalynx/features/device_linking/presentation/bloc/child_linking/child_linking_bloc.dart';
import 'package:parentalynx/features/device_linking/presentation/pages/link_page.dart';

import '../../../support/fake_backend.dart';
import '../../../support/fakes.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';
import '../../child_mode/support/child_fakes.dart';

/// Desmonta a arvore para encerrar os temporizadores periodicos das telas e fecha o
/// [ChildLinkBloc], criado no tempo simulado do teste.
Future<void> _unmount(WidgetTester tester, TestDependencies deps) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  // No tempo simulado o fechamento nao pode ser esperado direto: os quadros seguintes o
  // concluem.
  unawaited(deps.di<ChildLinkBloc>().close());
  await tester.pump();
  await tester.pump();
}

/// Deixa as respostas dos dubles chegarem e as animacoes de entrada terminarem.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(registerChildFallbacks);

  Future<void> pumpLinkPage(WidgetTester tester, TestDependencies deps) {
    return pumpWidgetInApp(
      tester,
      MultiBlocProvider(
        providers: <BlocProvider<Object?>>[
          BlocProvider<ChildLinkBloc>.value(value: deps.di<ChildLinkBloc>()),
          BlocProvider<ChildLinkingBloc>(
            create: (BuildContext context) =>
                deps.di<ChildLinkingBloc>()..add(const ChildLinkingStarted()),
          ),
        ],
        child: const LinkPage(),
      ),
      di: deps.di,
    );
  }

  testWidgets('formulario pede o codigo e sugere o nome do aparelho', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    final TestDependencies deps = childDependencies().deps;
    addTearDown(deps.dispose);
    await pumpLinkPage(tester, deps);
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
    await _unmount(tester, deps);
  });

  testWidgets('espera mostra o numero de confirmacao em destaque', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    final InMemorySecureStore store = InMemorySecureStore(<String, String>{
      StorageKeys.childPendingClaim: jsonEncode(<String, Object?>{
        'linkId': 'link-1',
        'pollToken': 'pp_token',
        'confirmCode': '4821',
        'guardianName': 'Maria',
        'expiresAt': 1790000000000,
      }),
    });
    final FakeBackend backend = FakeBackend()
      ..onJson('GET', '/v1/pairing/status', <String, Object?>{'status': 'pending'});
    final TestDependencies deps = childDependencies(backend: backend, secureStore: store).deps;
    addTearDown(deps.dispose);
    await pumpLinkPage(tester, deps);
    await _settle(tester);

    expect(find.text('4 8 2 1'), findsOneWidget);
    expect(find.textContaining('Maria precisa aprovar'), findsOneWidget);
    expect(find.text('Esperando a aprovação...'), findsOneWidget);
    await expectScreenshot(tester, 'child_link_waiting');
    await _unmount(tester, deps);
  });

  testWidgets('vinculo desfeito pelo responsavel aparece na tela do codigo', (
    WidgetTester tester,
  ) async {
    final TestDependencies deps = childDependencies().deps;
    addTearDown(deps.dispose);
    deps.di<ILinkStateRepository>().update(
      const LinkState(LinkPhase.unlinked, unlinkReason: UnlinkReason.revokedByGuardian),
    );
    await pumpLinkPage(tester, deps);
    await _settle(tester);

    expect(find.textContaining('foi removido pelo responsável'), findsOneWidget);
    await _unmount(tester, deps);
  });
}
