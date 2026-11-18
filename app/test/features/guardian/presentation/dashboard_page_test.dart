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

  Future<GoRouter> pumpDashboard(WidgetTester tester, {Size size = const Size(392, 1500)}) {
    return pumpGuardianRoutes(
      tester,
      routes: dashboardRoutes(deps.di),
      location: GuardianPaths.home,
      deps: deps,
      size: size,
      wrap: (Widget app) => BlocProvider<DevicesBloc>(
        create: (BuildContext context) => deps.di<DevicesBloc>()..add(const DevicesStarted()),
        child: app,
      ),
    );
  }

  testWidgets('mostra o tempo de hoje, o estado e os apps mais usados', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.text('João'), findsWidgets);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Regras aplicadas no aparelho'), findsOneWidget);
    // Limite de 2h30 com 1h10 usados: restam 1h20.
    expect(find.text('1h 20min'), findsOneWidget);
    expect(find.text('restante hoje'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Tentativa de abrir app bloqueado'), findsOneWidget);
    expect(find.text('Não garantido'), findsOneWidget);
  });

  testWidgets('tempo extra envia o comando e confirma', (WidgetTester tester) async {
    const String path = '/v1/guardian/devices/$deviceId/extra-time';
    deps.backend.on('POST', path, (http.Request request) {
      return jsonResponse(<String, Object?>{'policyVersion': 13, 'policy': policyJson()});
    });
    await pumpDashboard(tester);

    await tester.tap(find.widgetWithText(ActionChip, '30min'));
    await settle(tester);

    expect(deps.backend.calls('POST', path), hasLength(1));
    expect(deps.backend.lastBody('POST', path), <String, Object?>{'minutes': 30});
    expect(find.text('30min a mais enviados para João.'), findsOneWidget);
  });

  testWidgets('pedido de tempo pendente leva aos alertas', (WidgetTester tester) async {
    installStandardRoutes(deps.backend, device: deviceJson(pendingTimeRequests: 1));
    await pumpDashboard(tester);

    expect(find.text('João pediu mais tempo'), findsOneWidget);
    await tester.tap(find.text('Ver pedidos'));
    await settle(tester);

    expect(find.text('destino ${GuardianPaths.alerts}'), findsOneWidget);
  });

  testWidgets('proteção degradada aparece como aviso', (WidgetTester tester) async {
    installStandardRoutes(
      deps.backend,
      device: deviceJson(issues: <String>['accessibility_disabled']),
    );
    await pumpDashboard(tester);

    expect(find.text('Serviço de acessibilidade desativado'), findsOneWidget);
  });

  group('capturas', () {
    testWidgets('painel liberado', tags: 'screenshot', (WidgetTester tester) async {
      await pumpDashboard(tester, size: const Size(392, 1700));
      await expectScreenshot(tester, 'dashboard_liberado');
    });

    testWidgets('painel bloqueado pelo limite', tags: 'screenshot', (WidgetTester tester) async {
      installStandardRoutes(
        deps.backend,
        device: deviceJson(
          lockState: 'daily_limit',
          releaseAt: DateTime(2026, 11, 18).millisecondsSinceEpoch,
          quotaUsedMs: 9000000,
          totalUsedMs: 9600000,
        ),
      );
      await pumpDashboard(tester, size: const Size(392, 1000));

      expect(find.text('Limite diário atingido'), findsOneWidget);
      expect(find.text('Liberação prevista amanhã às 00:00.'), findsOneWidget);
      await expectScreenshot(tester, 'dashboard_bloqueado');
    });

    testWidgets('painel sem aparelho', tags: 'screenshot', (WidgetTester tester) async {
      deps.backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{'devices': <Object?>[]});
      await pumpDashboard(tester, size: phoneSize);

      expect(find.text('Nenhum aparelho vinculado'), findsOneWidget);
      await tester.tap(find.text('Vincular aparelho'));
      await settle(tester);

      expect(find.text('destino ${GuardianPaths.pairing}'), findsOneWidget);
    });
  });
}
