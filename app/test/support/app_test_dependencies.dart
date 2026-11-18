import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/app/app.dart';
import 'package:parentalynx/app/di/injection.dart';
import 'package:parentalynx/features/app_management/presentation/services/app_icon_images.dart';
import 'package:parentalynx/features/authentication/domain/services/i_elevation_prompter.dart';
import 'package:parentalynx/features/device_sync/domain/repositories/i_realtime_repository.dart';
import 'package:parentalynx/features/user_role/domain/entities/user_role.dart';

import 'fake_backend.dart';
import 'fakes.dart';
import 'native_doubles.dart';
import 'test_app.dart';
import 'test_dependencies.dart';

/// Conteiner com todas as funcionalidades registradas pela raiz de composicao real
/// ([registerFeatureModules]), com o nucleo trocado por dubles. Para os testes do app montado
/// (roteador, redirecionamentos, escopo da sessao).
TestDependencies buildAppTestDependencies({
  FakeBackend? backend,
  NativeDoubles? native,
  UserRole role = UserRole.unset,
  String? sessionToken,
  InMemorySecureStore? secureStore,
  IElevationPrompter? elevationPrompter,
}) {
  final TestDependencies deps = TestDependencies(
    backend: backend,
    native: native,
    role: role,
    sessionToken: sessionToken,
    secureStore: secureStore,
  );
  registerFeatureModules(
    deps.di,
    initialRole: role,
    allowInsecureHttp: true,
    navigatorKey: deps.navigatorKey,
  );
  // A raiz de composicao registra as implementacoes reais: os dubles voltam por cima.
  deps.di
    ..registerSingleton<IRealtimeRepository>(deps.realtime)
    // Sem rede para icones: as telas mostram a inicial de cada app.
    ..registerSingleton<AppIconImages>(const NoAppIconImages());
  if (elevationPrompter != null) {
    deps.di.registerSingleton<IElevationPrompter>(elevationPrompter);
  }
  return deps;
}

/// Monta o app inteiro (raiz, roteador e escopos) no tamanho de um celular.
Future<void> pumpParentaLynxApp(WidgetTester tester, TestDependencies deps) async {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = phoneSize * 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ParentaLynxApp(di: deps.di, navigatorKey: deps.navigatorKey));
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}
