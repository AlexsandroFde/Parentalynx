import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/platform/native_api.g.dart';
import 'package:parentalynx/features/onboarding/onboarding_module.dart';
import 'package:parentalynx/features/onboarding/presentation/bloc/onboarding/onboarding_bloc.dart';
import 'package:parentalynx/features/onboarding/presentation/pages/welcome_page.dart';
import 'package:parentalynx/features/server_config/presentation/bloc/server_config_bloc.dart';
import 'package:parentalynx/features/user_role/domain/entities/user_role.dart';
import 'package:parentalynx/features/user_role/domain/repositories/i_user_role_repository.dart';

import '../../../support/fake_backend.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

/// Boas-vindas com os BLoCs reais, a ponte nativa simulada e o servidor falso.
void main() {
  late FakeBackend backend;

  TestDependencies build({String serverUrl = 'https://servidor.teste'}) {
    final TestDependencies deps = TestDependencies(backend: backend, serverUrl: serverUrl);
    addTearDown(deps.dispose);
    registerOnboardingModule(deps.di);
    return deps;
  }

  Future<void> pumpWelcome(WidgetTester tester, TestDependencies deps) {
    return pumpWidgetInApp(
      tester,
      MultiBlocProvider(
        providers: <BlocProvider<Object?>>[
          BlocProvider<ServerConfigBloc>(
            create: (BuildContext context) => deps.di<ServerConfigBloc>(),
          ),
          BlocProvider<OnboardingBloc>(create: (BuildContext context) => deps.di<OnboardingBloc>()),
        ],
        child: const WelcomePage(),
      ),
      di: deps.di,
    );
  }

  setUp(() => backend = FakeBackend());

  testWidgets('mostra as duas opcoes de modo e o aviso de transparencia', (
    WidgetTester tester,
  ) async {
    await pumpWelcome(tester, build());

    expect(find.text('Sou o responsável'), findsOneWidget);
    expect(find.text('Este é o aparelho da criança'), findsOneWidget);
    expect(find.text('Controle transparente'), findsOneWidget);
    expect(find.text('Configurar servidor'), findsOneWidget);
  });

  testWidgets('escolher responsavel grava o modo no lado nativo', (WidgetTester tester) async {
    final TestDependencies deps = build();
    await pumpWelcome(tester, deps);

    await tester.tap(find.text('Sou o responsável'));
    await tester.pumpAndSettle();

    verify(() => deps.native.mode.setMode(AppMode.guardian)).called(1);
    expect(deps.di<IUserRoleRepository>().current, UserRole.guardian);
  });

  testWidgets('escolher crianca grava o modo crianca', (WidgetTester tester) async {
    final TestDependencies deps = build();
    await pumpWelcome(tester, deps);

    await tester.tap(find.text('Este é o aparelho da criança'));
    await tester.pumpAndSettle();

    verify(() => deps.native.mode.setMode(AppMode.child)).called(1);
    expect(deps.di<IUserRoleRepository>().current, UserRole.child);
  });

  testWidgets('sem servidor configurado pede o endereco antes de escolher', (
    WidgetTester tester,
  ) async {
    final TestDependencies deps = build(serverUrl: '');
    await pumpWelcome(tester, deps);

    await tester.tap(find.text('Sou o responsável'));
    await tester.pumpAndSettle();

    expect(find.text('Servidor'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
    verifyNever(() => deps.native.mode.setMode(any()));
  });

  testWidgets('com o servidor gravado na folha, a escolha continua', (WidgetTester tester) async {
    backend.onJson('GET', '/v1/meta', <String, Object?>{'name': 'ParentaLynx', 'version': '1'});
    final TestDependencies deps = build(serverUrl: '');
    await pumpWelcome(tester, deps);

    await tester.tap(find.text('Este é o aparelho da criança'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://servidor.teste');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Salvar'), findsNothing);
    verify(() => deps.native.mode.setMode(AppMode.child)).called(1);
    expect(deps.di<IUserRoleRepository>().current, UserRole.child);
  });

  testWidgets('fechar a folha do servidor sem gravar nao escolhe o modo', (
    WidgetTester tester,
  ) async {
    final TestDependencies deps = build(serverUrl: '');
    await pumpWelcome(tester, deps);

    await tester.tap(find.text('Sou o responsável'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Salvar'), findsNothing);
    verifyNever(() => deps.native.mode.setMode(any()));
    // A escolha pode ser feita de novo.
    await tester.tap(find.text('Sou o responsável'));
    await tester.pumpAndSettle();
    expect(find.text('Salvar'), findsOneWidget);
  });

  testWidgets('falha do lado nativo e mostrada e o modo nao muda', (WidgetTester tester) async {
    final TestDependencies deps = build();
    when(() => deps.native.mode.setMode(any())).thenThrow(
      PlatformException(code: 'denied', message: 'Autenticação do responsável necessária.'),
    );
    await pumpWelcome(tester, deps);

    await tester.tap(find.text('Sou o responsável'));
    await tester.pumpAndSettle();

    expect(find.text('Autenticação do responsável necessária.'), findsOneWidget);
    expect(deps.di<IUserRoleRepository>().current, UserRole.unset);
  });

  testWidgets('captura da tela de boas-vindas', tags: 'screenshot', (WidgetTester tester) async {
    await pumpWelcome(tester, build());
    await expectScreenshot(tester, 'onboarding_welcome');
  });
}
