import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/features/authentication/domain/repositories/i_current_account_repository.dart';
import 'package:parentalynx/features/notifications/domain/entities/alert_type.dart';
import 'package:parentalynx/features/notifications/notifications_module.dart';
import 'package:parentalynx/features/notifications/presentation/bloc/notification_permission/notification_permission_bloc.dart';
import 'package:parentalynx/features/notifications/presentation/bloc/notification_prefs/notification_prefs_bloc.dart';
import 'package:parentalynx/features/notifications/presentation/pages/notification_prefs_page.dart';
import 'package:parentalynx/features/notifications/presentation/texts/notification_texts.dart';

import '../../../support/fake_backend.dart';
import '../../../support/guardian_api_fixtures.dart' show settle;
import '../../../support/native_doubles.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';
import '../support/notification_fakes.dart';

void main() {
  const String prefsPath = '/v1/guardian/notification-prefs';

  late TestDependencies deps;

  TestDependencies createDeps({bool notificationsAllowed = true}) {
    final TestDependencies created = TestDependencies(
      sessionToken: 'gs_x',
      native: NativeDoubles(notificationsAllowed: notificationsAllowed),
    );
    registerNotificationsModule(created.di);
    // Conta do painel aberta, com dois avisos desligados.
    created.di.registerSingleton<ICurrentAccountRepository>(
      FakeCurrentAccount(
        accountWithPrefs(<String, bool>{'low_time': false, 'policy_changed': false}),
      ),
    );
    created.backend.on('PUT', prefsPath, (http.Request request) {
      return jsonResponse(<String, Object?>{'notificationPrefs': jsonDecode(request.body)});
    });
    return created;
  }

  setUp(() => deps = createDeps());

  tearDown(() => deps.dispose());

  Future<void> pumpPrefs(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    await pumpWidgetInApp(
      tester,
      MultiBlocProvider(
        providers: <BlocProvider<Object?>>[
          BlocProvider<NotificationPermissionBloc>(
            create: (BuildContext context) {
              return deps.di<NotificationPermissionBloc>()
                ..add(const NotificationPermissionStarted());
            },
          ),
          BlocProvider<NotificationPrefsBloc>(
            create: (BuildContext context) {
              return deps.di<NotificationPrefsBloc>()..add(const NotificationPrefsStarted());
            },
          ),
        ],
        child: const NotificationPrefsPage(),
      ),
      di: deps.di,
      brightness: brightness,
      textScale: textScale,
      size: const Size(392, 2250),
    );
    await settle(tester);
  }

  test('os grupos das preferencias cobrem todos os tipos de alerta uma vez', () {
    final List<AlertType> grouped = <AlertType>[
      for (final AlertPreferenceGroup group in alertPreferenceGroups) ...group.types,
    ];
    expect(grouped.toSet(), AlertType.values.toSet());
    expect(grouped.length, AlertType.values.length);
  });

  testWidgets(
    'preferencias agrupadas por assunto, com a consequencia de desligar',
    tags: 'screenshot',
    (WidgetTester tester) async {
      await deps.dispose();
      deps = createDeps(notificationsAllowed: false);
      await pumpPrefs(tester);

      expect(find.text('Notificações desativadas no sistema'), findsOneWidget);
      for (final AlertPreferenceGroup group in alertPreferenceGroups) {
        expect(find.text(group.title), findsOneWidget);
        expect(find.text(group.footer), findsOneWidget);
      }
      final Switch lowTime = tester.widget<Switch>(
        find.descendant(
          of: find.ancestor(of: find.text('Pouco tempo restante'), matching: find.byType(InkWell)),
          matching: find.byType(Switch),
        ),
      );
      expect(lowTime.value, isFalse);
      await expectScreenshot(tester, 'notification_prefs');
    },
  );

  testWidgets('preferencias no tema escuro', tags: 'screenshot', (WidgetTester tester) async {
    await pumpPrefs(tester, brightness: Brightness.dark);
    await expectScreenshot(tester, 'notification_prefs_escuro');
  });

  testWidgets('preferencias seguem as diretrizes de acessibilidade', (WidgetTester tester) async {
    await pumpPrefs(tester);
    await expectAccessible(tester);
  });

  testWidgets('preferencias funcionam com a fonte no maior tamanho', (WidgetTester tester) async {
    await pumpPrefs(tester, textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tocar na linha liga o aviso e envia o mapa completo', (WidgetTester tester) async {
    // Resposta com atraso, para a tela mostrar o andamento.
    deps.backend.on('PUT', prefsPath, (http.Request request) async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return jsonResponse(<String, Object?>{'notificationPrefs': jsonDecode(request.body)});
    });
    await pumpPrefs(tester);

    await tester.tap(find.text('Pouco tempo restante'));
    await tester.pump();
    expect(find.text('Salvando…'), findsOneWidget);
    await settle(tester);

    final Map<String, Object?> body = deps.backend.lastBody('PUT', prefsPath);
    expect(body['low_time'], isTrue);
    expect(body['policy_changed'], isFalse);
    expect(body.length, AlertType.values.length);
    expect(find.text('Salvando…'), findsNothing);
  });

  testWidgets('recusa do servidor diz qual escolha falhou e desfaz a mudanca', (
    WidgetTester tester,
  ) async {
    deps.backend.on('PUT', prefsPath, (_) => errorResponse(500, 'internal'));
    await pumpPrefs(tester);

    await tester.tap(find.text('Novo app instalado'));
    await settle(tester);

    expect(find.textContaining('Não foi possível salvar "Novo app instalado"'), findsOneWidget);
    final Switch newApp = tester.widget<Switch>(
      find.descendant(
        of: find.ancestor(of: find.text('Novo app instalado'), matching: find.byType(InkWell)),
        matching: find.byType(Switch),
      ),
    );
    expect(newApp.value, isTrue);
  });
}
