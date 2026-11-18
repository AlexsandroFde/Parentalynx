import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/features/app_management/app_management_module.dart';
import 'package:parentalynx/features/blocking/blocking_module.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';
import 'package:parentalynx/features/guardian/guardian_module.dart';
import 'package:parentalynx/features/guardian/guardian_routes.dart';
import 'package:parentalynx/features/notifications/notifications_module.dart';
import 'package:parentalynx/features/screen_time/screen_time_module.dart';

import '../../../support/fake_backend.dart';
import '../../../support/guardian_api_fixtures.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

void main() {
  late TestDependencies deps;

  setUp(() {
    // O relogio do teste fica no momento dos dados de exemplo (fixtureNow).
    deps = TestDependencies(sessionToken: 'gs_teste');
    registerNotificationsModule(deps.di);
    registerAppManagementModule(deps.di);
    registerBlockingModule(deps.di);
    registerScreenTimeModule(deps.di);
    registerGuardianModule(deps.di);
    installStandardRoutes(deps.backend);
  });

  tearDown(() => deps.dispose());

  Future<GoRouter> pumpDashboard(
    WidgetTester tester, {
    Size size = const Size(392, 1500),
    Brightness brightness = Brightness.light,
  }) {
    return pumpGuardianRoutes(
      tester,
      routes: dashboardRoutes(deps.di),
      location: GuardianPaths.home,
      deps: deps,
      size: size,
      brightness: brightness,
      destinations: const <String>[
        GuardianPaths.pairing,
        GuardianPaths.alerts,
        GuardianPaths.timeRequests,
      ],
      wrap: (Widget app) => BlocProvider<DevicesBloc>(
        create: (BuildContext context) => deps.di<DevicesBloc>()..add(const DevicesStarted()),
        child: app,
      ),
    );
  }

  Map<String, Object?> blockedByLimit() {
    return deviceJson(
      lockState: 'daily_limit',
      releaseAt: DateTime(2026, 11, 18).millisecondsSinceEpoch,
      quotaUsedMs: 9000000,
      totalUsedMs: 9600000,
    );
  }

  testWidgets('mostra quem, o estado, o tempo de hoje e os apps mais usados', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, size: const Size(392, 2600));

    expect(find.text('João'), findsWidgets);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Bateria 76%'), findsOneWidget);
    expect(find.text('Regras aplicadas no aparelho'), findsOneWidget);
    // Limite de 2h30 com 1h10 usados: restam 1h20.
    expect(find.text('1h 20min'), findsOneWidget);
    expect(find.text('restam hoje'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Tentativa de abrir app bloqueado'), findsOneWidget);
    expect(find.text('Não garantido'), findsOneWidget);
  });

  testWidgets('tempo extra envia, confirma e fica aguardando o aparelho', (
    WidgetTester tester,
  ) async {
    const String path = '/v1/guardian/devices/$deviceId/extra-time';
    deps.backend.on('POST', path, (http.Request request) {
      return jsonResponse(<String, Object?>{'policyVersion': 13, 'policy': policyJson()});
    });
    await pumpDashboard(tester);

    await tester.tap(find.widgetWithText(FilledButton, '+ 30min'));
    await settle(tester);

    expect(deps.backend.calls('POST', path), hasLength(1));
    expect(deps.backend.lastBody('POST', path), <String, Object?>{'minutes': 30});
    expect(
      find.text('30min a mais para hoje. O aparelho de João recebe em instantes.'),
      findsOneWidget,
    );
    // Salvo no servidor, mas so aplicado quando o aparelho confirmar a versao 13.
    expect(find.text('Aguardando o aparelho confirmar'), findsOneWidget);
    expect(find.text('Regras aplicadas no aparelho'), findsNothing);
  });

  testWidgets('falha no comando diz o que nao foi feito e oferece tentar de novo', (
    WidgetTester tester,
  ) async {
    const String path = '/v1/guardian/devices/$deviceId/extra-time';
    deps.backend.onError(
      'POST',
      path,
      status: 400,
      code: 'invalid_request',
      message: 'O servidor recusou o pedido.',
    );
    await pumpDashboard(tester);

    await tester.tap(find.widgetWithText(FilledButton, '+ 15min'));
    await settle(tester);

    expect(find.textContaining('O tempo extra não foi enviado.'), findsOneWidget);
    await tester.tap(find.text('Tentar de novo'));
    await settle(tester);
    expect(deps.backend.calls('POST', path), hasLength(2));
  });

  testWidgets('pausar pede confirmacao com o prazo e so envia depois', (WidgetTester tester) async {
    const String path = '/v1/guardian/devices/$deviceId/lock';
    deps.backend.on('POST', path, (http.Request request) {
      return jsonResponse(<String, Object?>{
        'policyVersion': 13,
        'policy': policyJson(
          overrides: <String, Object?>{
            'extraTime': <Object?>[],
            'manualLock': <String, Object?>{
              'active': true,
              'until': fixtureNow.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
              'setAt': 1,
            },
            'suspension': <String, Object?>{'until': 0, 'scopes': <String>[], 'setAt': null},
          },
        ),
      });
    });
    await pumpDashboard(tester);

    await tester.tap(find.text('Pausar agora'));
    await settle(tester);
    expect(find.text('Pausar o aparelho de João?'), findsOneWidget);
    expect(deps.backend.calls('POST', path), isEmpty);

    await tester.tap(find.text('Por 30 minutos'));
    await settle(tester);
    expect(find.text('Volta ao normal às 16:00.'), findsOneWidget);
    await tester.tap(find.text('Pausar por 30 minutos'));
    await settle(tester);

    expect(deps.backend.calls('POST', path), hasLength(1));
    expect(find.text('Pausa salva. O aparelho de João recebe em instantes.'), findsOneWidget);
    // O aparelho ainda nao confirmou a pausa.
    expect(find.text('Pausa aguardando o aparelho'), findsOneWidget);
    expect(find.text('Retomar agora'), findsOneWidget);
  });

  testWidgets('suspender exige escolher pelo menos uma regra', (WidgetTester tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.text('Suspender regras'));
    await settle(tester);
    await tester.tap(find.text('Limite de tempo'));
    await tester.tap(find.text('Horários e períodos de bloqueio'));
    await settle(tester);
    await tester.tap(find.text('Suspender por 1h'));
    await settle(tester);

    expect(find.text('Escolha pelo menos uma regra para suspender.'), findsOneWidget);
    expect(deps.backend.calls('POST', '/v1/guardian/devices/$deviceId/suspend'), isEmpty);
  });

  testWidgets('pedido de tempo pendente leva aos pedidos', (WidgetTester tester) async {
    installStandardRoutes(deps.backend, device: deviceJson(pendingTimeRequests: 1));
    await pumpDashboard(tester);

    expect(find.text('João pediu mais tempo'), findsOneWidget);
    await tester.tap(find.text('Ver pedidos'));
    await settle(tester);

    expect(find.text('destino ${GuardianPaths.timeRequests}'), findsOneWidget);
  });

  testWidgets('protecao degradada aparece como aviso com o que fazer', (WidgetTester tester) async {
    installStandardRoutes(
      deps.backend,
      device: deviceJson(issues: <String>['accessibility_disabled']),
    );
    await pumpDashboard(tester, size: const Size(392, 2600));

    expect(find.text('Serviço de acessibilidade desativado'), findsOneWidget);
    expect(find.textContaining('reative a acessibilidade'), findsOneWidget);
    expect(find.text('1 problema para resolver.'), findsOneWidget);
  });

  testWidgets('bloqueio mostra a regra que bloqueou e quando libera', (WidgetTester tester) async {
    installStandardRoutes(deps.backend, device: blockedByLimit());
    await pumpDashboard(tester);

    expect(find.text('Limite diário atingido'), findsOneWidget);
    expect(find.text('Libera amanhã às 00:00. Até lá, só as exceções funcionam.'), findsOneWidget);
  });

  testWidgets('funciona com a fonte no maior tamanho', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpDashboard(tester, size: const Size(392, 4000));

    expect(tester.takeException(), isNull);
    // O numero dentro do anel diminui para caber; o mesmo valor aparece em texto.
    expect(find.text('Restam 1h 20min de 2h 30min hoje.'), findsOneWidget);
  });

  testWidgets('segue as diretrizes de acessibilidade', (WidgetTester tester) async {
    await pumpDashboard(tester, size: const Size(392, 2600));
    await expectAccessible(tester);
  });

  group('capturas', () {
    for (final Brightness brightness in Brightness.values) {
      final String theme = brightness == Brightness.light ? '' : '_escuro';

      testWidgets('painel liberado$theme', tags: 'screenshot', (WidgetTester tester) async {
        await pumpDashboard(tester, size: const Size(392, 2250), brightness: brightness);
        await expectScreenshot(tester, 'dashboard_liberado$theme');
      });

      testWidgets('painel bloqueado pelo limite$theme', tags: 'screenshot', (
        WidgetTester tester,
      ) async {
        installStandardRoutes(deps.backend, device: blockedByLimit());
        await pumpDashboard(tester, size: const Size(392, 1100), brightness: brightness);
        await expectScreenshot(tester, 'dashboard_bloqueado$theme');
      });

      testWidgets('painel sem aparelho$theme', tags: 'screenshot', (WidgetTester tester) async {
        deps.backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{
          'devices': <Object?>[],
        });
        await pumpDashboard(tester, size: phoneSize, brightness: brightness);

        expect(find.text('Nenhum aparelho vinculado'), findsOneWidget);
        await expectScreenshot(tester, 'dashboard_sem_aparelho$theme');
        await tester.tap(find.text('Vincular aparelho'));
        await settle(tester);

        expect(find.text('destino ${GuardianPaths.pairing}'), findsOneWidget);
      });
    }
  });
}
