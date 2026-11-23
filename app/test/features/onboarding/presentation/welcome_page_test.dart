import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/platform/native_api.g.dart';
import 'package:parentalynx/features/onboarding/onboarding_module.dart';
import 'package:parentalynx/features/onboarding/presentation/bloc/onboarding/onboarding_bloc.dart';
import 'package:parentalynx/features/onboarding/presentation/pages/welcome_page.dart';
import 'package:parentalynx/features/user_role/domain/entities/user_role.dart';
import 'package:parentalynx/features/user_role/domain/repositories/i_user_role_repository.dart';

import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

/// Boas-vindas com os BLoCs reais e a ponte nativa simulada.
void main() {
  TestDependencies build() {
    final TestDependencies deps = TestDependencies();
    addTearDown(deps.dispose);
    registerOnboardingModule(deps.di);
    return deps;
  }

  Future<void> pumpWelcome(
    WidgetTester tester,
    TestDependencies deps, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Size size = phoneSize,
  }) {
    return pumpWidgetInApp(
      tester,
      BlocProvider<OnboardingBloc>(
        create: (BuildContext context) => deps.di<OnboardingBloc>(),
        child: const WelcomePage(),
      ),
      di: deps.di,
      brightness: brightness,
      textScale: textScale,
      size: size,
    );
  }

  testWidgets('mostra as duas opcoes de papel e o aviso de transparencia, sem servidor', (
    WidgetTester tester,
  ) async {
    await pumpWelcome(tester, build());

    expect(find.text('Sou o responsável'), findsOneWidget);
    expect(find.text('Este é o aparelho da criança'), findsOneWidget);
    expect(find.text('Controle transparente'), findsOneWidget);
    // O endereco do servidor e fixo no codigo: nao ha o que configurar aqui.
    expect(find.text('Servidor'), findsNothing);
    expect(find.text('https://servidor.teste'), findsNothing);
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

  testWidgets('falha do lado nativo e mostrada e o modo nao muda', (WidgetTester tester) async {
    final TestDependencies deps = build();
    when(() => deps.native.mode.setMode(any())).thenThrow(
      PlatformException(code: 'denied', message: 'Autenticação do responsável necessária.'),
    );
    await pumpWelcome(tester, deps);

    await tester.tap(find.text('Sou o responsável'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível definir o papel deste aparelho'), findsOneWidget);
    expect(find.text('Autenticação do responsável necessária.'), findsOneWidget);
    expect(deps.di<IUserRoleRepository>().current, UserRole.unset);
  });

  testWidgets('captura da tela de boas-vindas', tags: 'screenshot', (WidgetTester tester) async {
    await pumpWelcome(tester, build());
    await expectScreenshot(tester, 'onboarding_welcome');
  });

  testWidgets('captura da tela de boas-vindas no tema escuro', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    await pumpWelcome(tester, build(), brightness: Brightness.dark);
    await expectScreenshot(tester, 'onboarding_welcome_escuro');
  });

  testWidgets('boas-vindas funciona com a fonte no maior tamanho', (WidgetTester tester) async {
    await pumpWelcome(tester, build(), textScale: 2, size: const Size(392, 3200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('boas-vindas segue as diretrizes de acessibilidade', (WidgetTester tester) async {
    await pumpWelcome(tester, build(), size: const Size(392, 1600));
    await expectAccessible(tester);
  });
}
