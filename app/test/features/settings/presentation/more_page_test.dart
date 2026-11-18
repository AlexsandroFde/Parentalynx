import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_account.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_session.dart';
import 'package:parentalynx/features/authentication/domain/repositories/i_session_repository.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/auth/auth_bloc.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';
import 'package:parentalynx/features/settings/settings_module.dart';
import 'package:parentalynx/features/settings/settings_routes.dart';

import '../../../support/fake_backend.dart';
import '../../../support/guardian_api_fixtures.dart' show pumpGuardianRoutes, settle;
import '../../../support/guardian_fixtures.dart';
import '../../../support/test_app.dart';
import '../../../support/test_dependencies.dart';

const GuardianAccount _account = GuardianAccount(
  id: 'g1',
  email: 'maria@exemplo.com',
  displayName: 'Maria Souza',
  createdAt: 1,
);

const GuardianSessionInfo _session = GuardianSessionInfo(
  id: 's1',
  deviceName: 'Galaxy da Maria',
  createdAt: 1,
  lastSeenAt: 2,
  expiresAt: 99999999999999,
  elevatedUntil: 99999999999999,
  current: true,
);

/// Aba Mais montada com as rotas reais da funcionalidade, a sessao aberta e o servidor falso.
void main() {
  late FakeBackend backend;
  late TestDependencies deps;

  setUp(() {
    backend = FakeBackend();
    backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{
      'devices': <Object?>[
        deviceJson(pendingTimeRequests: 1, issues: <String>['accessibility_disabled']),
      ],
    });
    deps = TestDependencies(backend: backend, sessionToken: 'gs_x');
    addTearDown(deps.dispose);
    registerSettingsModule(deps.di);
    deps.di<ISessionRepository>().unlock(
      const GuardianProfile(account: _account, session: _session),
    );
  });

  Future<GoRouter> pumpMore(WidgetTester tester) {
    return pumpGuardianRoutes(
      tester,
      routes: settingsRoutes(deps.di),
      location: GuardianPaths.more,
      deps: deps,
      wrap: (Widget app) => MultiBlocProvider(
        providers: <BlocProvider<Object?>>[
          BlocProvider<AuthBloc>.value(value: deps.di<AuthBloc>()),
          BlocProvider<DevicesBloc>(
            create: (BuildContext context) => deps.di<DevicesBloc>()..add(const DevicesStarted()),
          ),
        ],
        child: app,
      ),
    );
  }

  testWidgets('aba Mais', tags: 'screenshot', (WidgetTester tester) async {
    await pumpMore(tester);

    expect(find.text('Maria Souza'), findsOneWidget);
    expect(find.text('1 aparelho ativo'), findsOneWidget);
    expect(find.text('1 aguardando resposta'), findsOneWidget);
    await expectScreenshot(tester, 'guardian_more');

    await tester.scrollUntilVisible(find.text('Versão 1.0.0'), 300);
    expect(find.text('https://servidor.teste'), findsOneWidget);
  });

  testWidgets('sair da conta pede confirmacao e encerra a sessao', (WidgetTester tester) async {
    await pumpMore(tester);

    await tester.scrollUntilVisible(find.text('Sair da conta'), 300);
    await tester.tap(find.text('Sair da conta'));
    await settle(tester);
    expect(find.text('Sair da conta?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
    await settle(tester);

    expect(deps.di<AuthBloc>().state, const AuthSignedOut(reason: SessionEndReason.signedOut));
  });

  testWidgets('itens da conta abrem as telas da aba', (WidgetTester tester) async {
    backend.onJson('GET', '/v1/guardian/sessions', <String, Object?>{
      'sessions': <Object?>[sessionJson()],
    });
    final GoRouter router = await pumpMore(tester);

    await tester.tap(find.text('Sessões conectadas'));
    await settle(tester);

    expect(router.state.matchedLocation, GuardianPaths.sessions);
    expect(find.text('Galaxy da Maria'), findsOneWidget);
    expect(find.text('Atual'), findsOneWidget);
  });
}
