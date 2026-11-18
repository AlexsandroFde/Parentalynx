import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/core/security/totp.dart';
import 'package:parentalynx/features/child_device/child_device_routes.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/child_device/child_device_bloc.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/offline_code/offline_code_bloc.dart';
import 'package:parentalynx/features/child_device/presentation/pages/device_detail_page.dart';

import '../../../support/fake_backend.dart';
import '../../../support/fakes.dart';
import '../../../support/guardian_api_fixtures.dart' show pumpGuardianRoutes, settle;
import '../../../support/guardian_fixtures.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

void main() {
  const String devicePath = '/v1/guardian/devices/d1';

  late TestDependencies deps;

  setUp(() {
    final Map<String, Object?> devices = <String, Object?>{
      'devices': <Object?>[
        deviceJson(pendingTimeRequests: 1, issues: <String>['accessibility_disabled']),
        deviceJson(id: 'd2', childName: 'Bia', online: false),
        deviceJson(id: 'd3', childName: 'Leo', status: 'revoked'),
      ],
    };
    // Os exemplos usam o relogio real ("ha 1 min"): o relogio do teste parte de depois deles.
    deps = TestDependencies(sessionToken: 'gs_x', clock: FakeClock(DateTime.now()));
    deps.backend.onJson('GET', '/v1/guardian/devices', devices);
  });

  tearDown(() => deps.dispose());

  /// O `DevicesBloc` vive no escopo da sessao e mantem a lista da conta carregada.
  Widget devicesScope(Widget child) {
    return BlocProvider<DevicesBloc>(
      create: (BuildContext context) => deps.di<DevicesBloc>()..add(const DevicesStarted()),
      child: child,
    );
  }

  Future<GoRouter> pumpDetail(
    WidgetTester tester, {
    Size size = phoneSize,
    Brightness brightness = Brightness.light,
  }) {
    return pumpGuardianRoutes(
      tester,
      routes: childDeviceRoutes(deps.di),
      location: GuardianPaths.device('d1'),
      deps: deps,
      size: size,
      brightness: brightness,
      wrap: devicesScope,
    );
  }

  Future<GoRouter> pumpList(
    WidgetTester tester, {
    Size size = phoneSize,
    Brightness brightness = Brightness.light,
  }) {
    return pumpGuardianRoutes(
      tester,
      routes: childDeviceRoutes(deps.di),
      location: GuardianPaths.devices,
      deps: deps,
      size: size,
      brightness: brightness,
      wrap: devicesScope,
    );
  }

  /// Rola a tela ate [finder] aparecer inteiro na tela.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300);
    await tester.ensureVisible(finder);
    await settle(tester);
  }

  testWidgets('detalhe do aparelho mostra o nivel de protecao e as permissoes com o que fazer', (
    WidgetTester tester,
  ) async {
    await pumpWidgetInApp(
      tester,
      devicesScope(
        BlocProvider<ChildDeviceBloc>(
          create: (BuildContext context) {
            return deps.di<ChildDeviceBloc>()..add(const ChildDeviceStarted('d1'));
          },
          child: DeviceDetailPage(
            offlineCodeBloc: (String secret) => deps.di<OfflineCodeBloc>(param1: secret),
          ),
        ),
      ),
      di: deps.di,
    );
    await settle(tester);

    expect(find.text('Regras aplicadas no aparelho'), findsOneWidget);
    expect(find.text('Nível de proteção'), findsOneWidget);
    expect(find.text('Padrão'), findsOneWidget);
    expect(find.text('O que não é garantido'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Acessibilidade'), 300);
    expect(find.text('Serviço de acessibilidade desativado'), findsOneWidget);
    expect(find.textContaining('reative a acessibilidade'), findsOneWidget);
    expect(find.text('Desativada'), findsWidgets);
  });

  testWidgets('a lista de aparelhos separa ativos e desvinculados e abre o detalhe', (
    WidgetTester tester,
  ) async {
    await pumpList(tester);

    expect(find.text('Aparelhos'), findsOneWidget);
    expect(find.text('Ativos'), findsOneWidget);
    expect(find.text('Proteção incompleta'), findsOneWidget);
    expect(find.text('Desvinculados'), findsOneWidget);
    await tester.tap(find.text('João'));
    await settle(tester);

    expect(find.text('Nível de proteção'), findsOneWidget);
  });

  testWidgets('renomear envia o nome novo e confirma', (WidgetTester tester) async {
    deps.backend.on('PATCH', devicePath, (http.Request request) {
      return jsonResponse(<String, Object?>{'device': deviceJson(childName: 'Joãozinho')});
    });
    await pumpDetail(tester);

    await tester.tap(find.byTooltip('Trocar o nome'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Joãozinho');
    await tester.tap(find.text('Salvar'));
    await settle(tester);

    expect(deps.backend.lastBody('PATCH', devicePath), <String, Object?>{'childName': 'Joãozinho'});
    expect(find.text('Nome alterado.'), findsOneWidget);
  });

  testWidgets('nome longo demais mostra o erro sem enviar', (WidgetTester tester) async {
    await pumpDetail(tester);

    await tester.tap(find.byTooltip('Trocar o nome'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'J' * 41);
    await tester.tap(find.text('Salvar'));
    await settle(tester);

    expect(find.text('Informe um nome com até 40 caracteres.'), findsOneWidget);
    expect(deps.backend.calls('PATCH', devicePath), isEmpty);
  });

  testWidgets('exportar compartilha os dados como arquivo', (WidgetTester tester) async {
    deps.backend.onJson('GET', '$devicePath/export', <String, Object?>{
      'device': <String, Object?>{'id': 'd1'},
    });
    await pumpDetail(tester);

    await reveal(tester, find.text('Exportar dados'));
    await tester.tap(find.text('Exportar dados'));
    await settle(tester);

    expect(deps.share.files, <String>['parentalynx-2026-11-17.json']);
  });

  testWidgets('codigo offline mostra o codigo do momento e a contagem', (
    WidgetTester tester,
  ) async {
    const String secret = 'JBSWY3DPEHPK3PXP';
    deps.backend.onJson('GET', '$devicePath/offline-secret', <String, Object?>{'secret': secret});
    await pumpDetail(tester);
    // Dez segundos depois da virada do minuto: faltam 50 s para o codigo mudar.
    deps.clock.current = DateTime(2026, 11, 17, 15, 30, 10);
    final String code = const Totp().generate(secret, deps.clock.now().millisecondsSinceEpoch);

    await reveal(tester, find.text('Mostrar código'));
    await tester.tap(find.text('Mostrar código'));
    await settle(tester);

    expect(find.text('Código de acesso offline'), findsWidgets);
    expect(find.text('${code.substring(0, 4)} ${code.substring(4)}'), findsOneWidget);
    expect(find.text('Muda em 50 s'), findsOneWidget);

    deps.clock.advance(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Muda em 49 s'), findsOneWidget);

    // Fecha a folha, o que encerra a contagem.
    await tester.tap(find.byTooltip('Fechar'));
    await settle(tester);
    expect(find.text('Muda em 49 s'), findsNothing);
  });

  testWidgets('desvincular pede confirmacao com a consequencia antes de enviar', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester);

    await reveal(tester, find.text('Desvincular aparelho'));
    await tester.tap(find.text('Desvincular aparelho'));
    await settle(tester);

    expect(find.text('Desvincular o aparelho de João?'), findsOneWidget);
    expect(find.textContaining('O histórico fica guardado'), findsWidgets);
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    expect(deps.backend.calls('POST', '$devicePath/revoke'), isEmpty);
  });

  testWidgets('apagar o aparelho pede confirmacao, apaga e volta para a lista', (
    WidgetTester tester,
  ) async {
    deps.backend.onJson('DELETE', devicePath, <String, Object?>{'ok': true});
    await pumpDetail(tester);

    await reveal(tester, find.text('Apagar aparelho e histórico'));
    await tester.tap(find.text('Apagar aparelho e histórico'));
    await settle(tester);
    expect(find.text('Apagar João?'), findsOneWidget);
    expect(find.text('Esta ação não pode ser desfeita.'), findsOneWidget);
    await tester.tap(find.text('Apagar tudo'));
    await settle(tester);

    expect(deps.backend.calls('DELETE', devicePath), hasLength(1));
    expect(find.text('Aparelho apagado.'), findsOneWidget);
    expect(find.text('Aparelhos'), findsOneWidget);
  });

  testWidgets('detalhe e lista funcionam com a fonte no maior tamanho', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpDetail(tester, size: const Size(392, 2400));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Apagar aparelho e histórico'), 400);
    expect(tester.takeException(), isNull);

    await pumpList(tester);
    expect(find.text('Ativos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detalhe e lista seguem as diretrizes de acessibilidade', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, size: const Size(392, 2600));
    await expectAccessible(tester);

    await pumpList(tester);
    await expectAccessible(tester);
  });

  group('capturas', () {
    for (final Brightness brightness in Brightness.values) {
      final String theme = brightness == Brightness.light ? '' : '_escuro';

      testWidgets('detalhe do aparelho$theme', tags: 'screenshot', (WidgetTester tester) async {
        await pumpDetail(tester, size: const Size(392, 2600), brightness: brightness);
        await expectScreenshot(tester, 'guardian_device_detail$theme');
      });

      testWidgets('lista de aparelhos$theme', tags: 'screenshot', (WidgetTester tester) async {
        await pumpList(tester, brightness: brightness);
        await expectScreenshot(tester, 'guardian_devices$theme');
      });

      testWidgets('codigo de acesso offline$theme', tags: 'screenshot', (
        WidgetTester tester,
      ) async {
        deps.backend.onJson('GET', '$devicePath/offline-secret', <String, Object?>{
          'secret': 'JBSWY3DPEHPK3PXP',
        });
        await pumpDetail(tester, brightness: brightness);
        deps.clock.current = DateTime(2026, 11, 17, 15, 30, 10);
        await reveal(tester, find.text('Mostrar código'));
        await tester.tap(find.text('Mostrar código'));
        await settle(tester);
        await expectScreenshot(tester, 'guardian_offline_code$theme');
        await tester.tap(find.byTooltip('Fechar'));
        await settle(tester);
      });
    }
  });
}
