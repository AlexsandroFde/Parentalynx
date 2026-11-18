import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';
import 'package:parentalynx/features/device_linking/device_linking_module.dart';
import 'package:parentalynx/features/device_linking/device_linking_routes.dart';
import 'package:parentalynx/features/device_linking/presentation/bloc/device_linking/device_linking_bloc.dart';
import 'package:parentalynx/features/device_linking/presentation/pages/pairing_page.dart';

import '../../../support/fake_backend.dart';
import '../../../support/guardian_api_fixtures.dart' show pumpGuardianRoutes;
import '../../../support/guardian_fixtures.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

const String _activePath = '/v1/guardian/pairing-codes/active';
const String _codesPath = '/v1/guardian/pairing-codes';
const String _confirmLabel = 'O mesmo número aparece no aparelho da criança';

/// Tela de vinculacao do responsavel com o BLoC real e o servidor falso.
void main() {
  late FakeBackend backend;
  late TestDependencies deps;

  setUp(() {
    backend = FakeBackend();
    deps = TestDependencies(backend: backend, sessionToken: 'gs_x');
    addTearDown(deps.dispose);
    registerDeviceLinkingModule(deps.di);
    backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{'devices': <Object?>[]});
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  int minutesBeforeClock(int minutes) {
    return deps.clock.now().subtract(Duration(minutes: minutes)).millisecondsSinceEpoch;
  }

  int minutesAfterClock(int minutes) {
    return deps.clock.now().add(Duration(minutes: minutes)).millisecondsSinceEpoch;
  }

  /// Sem codigo nem pedido: o servidor responde a consulta e aceita gerar um codigo.
  void codeCanBeGenerated({int expiresInMinutes = 14}) {
    final int expiresAt = minutesAfterClock(expiresInMinutes);
    backend.onJson('GET', _activePath, <String, Object?>{'code': null, 'pending': <Object?>[]});
    backend.onJson('POST', _codesPath, <String, Object?>{
      'id': 'c1',
      'code': 'AB2D9XYZ',
      'expiresAt': expiresAt,
    }, status: 201);
  }

  /// O aparelho da crianca usou o codigo: o pedido aparece na consulta seguinte.
  void requestArrives() {
    backend.onJson('GET', _activePath, <String, Object?>{
      'code': null,
      'pending': <Object?>[
        deviceJson(
          id: 'p1',
          status: 'pending',
          childName: '',
          confirmCode: '4821',
          createdAt: minutesBeforeClock(2),
        ),
      ],
    });
  }

  Future<void> pumpPairing(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Size size = phoneSize,
  }) async {
    await pumpWidgetInApp(
      tester,
      MultiBlocProvider(
        providers: <BlocProvider<Object?>>[
          BlocProvider<DevicesBloc>(create: (BuildContext context) => deps.di<DevicesBloc>()),
          BlocProvider<DeviceLinkingBloc>(
            create: (BuildContext context) =>
                deps.di<DeviceLinkingBloc>()..add(const DeviceLinkingStarted()),
          ),
        ],
        child: const PairingPage(),
      ),
      di: deps.di,
      brightness: brightness,
      size: size,
      navigatorKey: deps.navigatorKey,
    );
    await settle(tester);
  }

  testWidgets('vinculacao: gera o codigo e mostra o pedido com a confirmacao', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    codeCanBeGenerated();
    await pumpPairing(tester);
    expect(find.text('Gere um código de vinculação'), findsOneWidget);
    expect(find.text('Passo 1 de 4'), findsOneWidget);

    backend.onJson('GET', _activePath, <String, Object?>{
      'code': <String, Object?>{'id': 'c1', 'expiresAt': minutesAfterClock(14)},
      'pending': <Object?>[],
    });
    await tester.tap(find.text('Gerar código'));
    await settle(tester);

    expect(find.text('AB2D-9XYZ'), findsOneWidget);
    expect(find.text('Expira em 14:00'), findsOneWidget);
    expect(find.text('Vale até as 15:44, uma única vez.'), findsOneWidget);
    expect(find.text('Digite o código no aparelho da criança'), findsOneWidget);
    await tester.tap(find.text('Copiar'));
    await settle(tester);
    expect(deps.share.copied.single, 'AB2D-9XYZ');
    await tester.pump(const Duration(seconds: 5));
    await expectScreenshot(tester, 'guardian_pairing_code');

    requestArrives();
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);

    expect(find.text('Pedido de vínculo'), findsOneWidget);
    expect(find.text('Confira o número de confirmação'), findsOneWidget);
    expect(find.text('4 8 2 1'), findsOneWidget);
    expect(find.text('AB2D-9XYZ'), findsNothing);

    // Aprovar exige conferir o numero e dar o nome da crianca.
    await tester.tap(find.widgetWithText(FilledButton, 'Aprovar'));
    await settle(tester);
    expect(find.text('Aprovar o vínculo?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Aprovar vínculo'));
    await settle(tester);
    expect(find.text('Informe o nome da criança.'), findsOneWidget);
    expect(find.textContaining('Confira o número no aparelho da criança'), findsOneWidget);
    expect(backend.calls('POST', '/v1/guardian/devices/p1/approve'), isEmpty);
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    await expectScreenshot(tester, 'guardian_pairing_request');
  });

  testWidgets('aprovar mostra o sucesso, poe o aparelho em foco e conclui', (
    WidgetTester tester,
  ) async {
    requestArrives();
    backend.onJson('POST', '/v1/guardian/devices/p1/approve', <String, Object?>{
      'device': deviceJson(id: 'p1', childName: 'Ana'),
    });
    late DevicesBloc devices;
    final GoRouter router = await pumpGuardianRoutes(
      tester,
      routes: deviceLinkingRoutes(deps.di),
      location: GuardianPaths.pairing,
      deps: deps,
      destinations: const <String>[GuardianPaths.home],
      wrap: (Widget app) => BlocProvider<DevicesBloc>(
        lazy: false,
        create: (BuildContext context) =>
            devices = deps.di<DevicesBloc>()..add(const DevicesStarted()),
        child: app,
      ),
    );
    expect(find.text('Pedido de vínculo'), findsOneWidget);

    // A recarga feita pela aprovacao ja traz o aparelho aprovado, depois de outro aparelho.
    backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{
      'devices': <Object?>[
        deviceJson(id: 'd0', childName: 'Bia'),
        deviceJson(id: 'p1', childName: 'Ana'),
      ],
    });
    await tester.tap(find.widgetWithText(FilledButton, 'Aprovar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(_confirmLabel));
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.tap(find.widgetWithText(FilledButton, 'Aprovar vínculo'));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(backend.lastBody('POST', '/v1/guardian/devices/p1/approve')['childName'], 'Ana');
    expect(find.text('Aparelho de Ana vinculado'), findsOneWidget);
    expect(find.text('motorola moto g54, Android 14'), findsOneWidget);
    expect(devices.state.selected?.id, 'p1');

    await tester.tap(find.text('Concluir'));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(router.state.matchedLocation, GuardianPaths.home);
  });

  testWidgets('cancelar o codigo pede confirmacao', (WidgetTester tester) async {
    codeCanBeGenerated(expiresInMinutes: 15);
    backend.onJson('DELETE', '$_codesPath/c1', <String, Object?>{});
    await pumpGuardianRoutes(
      tester,
      routes: deviceLinkingRoutes(deps.di),
      location: GuardianPaths.pairing,
      deps: deps,
      destinations: const <String>[GuardianPaths.home],
      wrap: (Widget app) => BlocProvider<DevicesBloc>(
        create: (BuildContext context) => deps.di<DevicesBloc>(),
        child: app,
      ),
    );
    backend.onJson('GET', _activePath, <String, Object?>{
      'code': <String, Object?>{'id': 'c1', 'expiresAt': minutesAfterClock(15)},
      'pending': <Object?>[],
    });
    await tester.tap(find.text('Gerar código'));
    await settle(tester);
    expect(find.text('AB2D-9XYZ'), findsOneWidget);

    await tester.tap(find.text('Cancelar código'));
    await settle(tester);
    expect(find.text('Cancelar o código?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar código'));
    await settle(tester);

    expect(backend.calls('DELETE', '$_codesPath/c1'), hasLength(1));
    expect(find.text('AB2D-9XYZ'), findsNothing);
    expect(find.text('Gere um código de vinculação'), findsOneWidget);
  });

  testWidgets('codigo vencido explica o que houve e oferece gerar outro', (
    WidgetTester tester,
  ) async {
    codeCanBeGenerated(expiresInMinutes: 1);
    await pumpPairing(tester);
    backend.onJson('GET', _activePath, <String, Object?>{
      'code': <String, Object?>{'id': 'c1', 'expiresAt': minutesAfterClock(1)},
      'pending': <Object?>[],
    });
    await tester.tap(find.text('Gerar código'));
    await settle(tester);
    expect(find.text('AB2D-9XYZ'), findsOneWidget);

    deps.clock.advance(const Duration(minutes: 1, seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(find.text('AB2D-9XYZ'), findsNothing);
    expect(find.text('O código venceu'), findsOneWidget);
    expect(find.text('Gerar código'), findsOneWidget);
  });

  testWidgets('funciona com a fonte no maior tamanho e segue as diretrizes de acessibilidade', (
    WidgetTester tester,
  ) async {
    codeCanBeGenerated();
    requestArrives();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPairing(tester, size: const Size(392, 2400));

    expect(tester.takeException(), isNull);
    expect(find.text('4 8 2 1'), findsOneWidget);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await settle(tester);
    await expectAccessible(tester);
  });

  testWidgets('capturas no tema escuro', tags: 'screenshot', (WidgetTester tester) async {
    codeCanBeGenerated();
    await pumpPairing(tester, brightness: Brightness.dark);
    backend.onJson('GET', _activePath, <String, Object?>{
      'code': <String, Object?>{'id': 'c1', 'expiresAt': minutesAfterClock(14)},
      'pending': <Object?>[],
    });
    await tester.tap(find.text('Gerar código'));
    await settle(tester);
    await expectScreenshot(tester, 'guardian_pairing_code_escuro');

    requestArrives();
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await expectScreenshot(tester, 'guardian_pairing_request_escuro');
  });
}
