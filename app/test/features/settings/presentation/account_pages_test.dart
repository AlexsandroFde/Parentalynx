import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/core/constants/storage_keys.dart';
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

/// Telas da aba Mais montadas pelas rotas reais, com a sessao aberta e o servidor falso.
void main() {
  late FakeBackend backend;
  late TestDependencies deps;

  setUp(() {
    backend = FakeBackend();
    deps = TestDependencies(backend: backend, sessionToken: 'gs_x');
    addTearDown(deps.dispose);
    registerSettingsModule(deps.di);
    deps.di<ISessionRepository>().unlock(
      const GuardianProfile(account: _account, session: _session),
    );
  });

  /// As telas abrem por cima da aba Mais, que tambem e montada e precisa do `DevicesBloc`.
  Future<GoRouter> pumpAt(WidgetTester tester, String location) {
    return pumpGuardianRoutes(
      tester,
      routes: settingsRoutes(deps.di),
      location: location,
      deps: deps,
      wrap: (Widget app) => MultiBlocProvider(
        providers: <BlocProvider<Object?>>[
          BlocProvider<AuthBloc>.value(value: deps.di<AuthBloc>()),
          BlocProvider<DevicesBloc>(create: (BuildContext context) => deps.di<DevicesBloc>()),
        ],
        child: app,
      ),
    );
  }

  group('conta e senha', () {
    testWidgets('troca o nome com a regra de tamanho e atualiza a conta', (
      WidgetTester tester,
    ) async {
      backend.onJson('PATCH', '/v1/guardian/me', <String, Object?>{
        'guardian': guardianJson(displayName: 'Maria S.'),
      });
      await pumpAt(tester, GuardianPaths.account);

      await tester.tap(find.text('Nome'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Salvar'));
      await settle(tester);
      expect(find.text('Informe um nome com até 60 caracteres.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), ' Maria S. ');
      await tester.tap(find.text('Salvar'));
      await settle(tester);

      expect(backend.lastBody('PATCH', '/v1/guardian/me'), <String, Object?>{
        'displayName': 'Maria S.',
      });
      expect(find.text('Nome alterado.'), findsOneWidget);
      expect(find.text('Maria S.'), findsOneWidget);
      expect(deps.di<AuthBloc>().state, isA<AuthReady>());
      expect((deps.di<AuthBloc>().state as AuthReady).account.displayName, 'Maria S.');
    });

    testWidgets('nova chave de recuperacao pede a senha e mostra a chave uma vez', (
      WidgetTester tester,
    ) async {
      backend.onError(
        'POST',
        '/v1/guardian/recovery-key',
        status: 401,
        code: 'invalid_credentials',
      );
      await pumpAt(tester, GuardianPaths.account);

      await tester.tap(find.text('Gerar nova chave'));
      await settle(tester);
      await tester.tap(find.text('Gerar'));
      await settle(tester);
      expect(find.text('Digite a senha administrativa.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'errada');
      await tester.tap(find.text('Gerar'));
      await settle(tester);
      expect(find.text('Senha incorreta.'), findsOneWidget);

      backend.onJson('POST', '/v1/guardian/recovery-key', <String, Object?>{
        'recoveryKey': 'RK-7H2KD-9QWXA',
      });
      await tester.tap(find.text('Gerar nova chave'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Girassol-azul-42');
      await tester.tap(find.text('Gerar'));
      await settle(tester);

      expect(backend.lastBody('POST', '/v1/guardian/recovery-key'), <String, Object?>{
        'password': 'Girassol-azul-42',
      });
      expect(find.text('Guarde a chave de recuperação'), findsOneWidget);
      expect(find.textContaining('RK-7H2KD-9QWXA'), findsOneWidget);

      await tester.tap(find.byType(CheckboxListTile));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await settle(tester);
      expect(find.text('Conta e senha'), findsOneWidget);
      expect(find.text('Guarde a chave de recuperação'), findsNothing);
    });

    testWidgets('troca de senha mostra a recusa do servidor e fecha ao concluir', (
      WidgetTester tester,
    ) async {
      backend.onError('POST', '/v1/guardian/password', status: 401, code: 'invalid_credentials');
      await pumpAt(tester, GuardianPaths.account);

      await tester.tap(find.text('Trocar senha'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Trocar senha'));
      await settle(tester);
      expect(find.text('Digite a senha atual.'), findsOneWidget);

      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'antiga');
      await tester.enterText(fields.at(1), 'Girassol-azul-42');
      await tester.enterText(fields.at(2), 'Girassol-azul-42');
      await tester.tap(find.widgetWithText(FilledButton, 'Trocar senha'));
      await settle(tester);
      expect(find.text('A senha atual está incorreta.'), findsOneWidget);

      backend.onJson('POST', '/v1/guardian/password', <String, Object?>{});
      await tester.tap(find.widgetWithText(FilledButton, 'Trocar senha'));
      await settle(tester);

      expect(backend.lastBody('POST', '/v1/guardian/password'), <String, Object?>{
        'currentPassword': 'antiga',
        'newPassword': 'Girassol-azul-42',
      });
      expect(find.text('Senha alterada.'), findsOneWidget);
      expect(find.text('Conta e senha'), findsOneWidget);
      expect(find.text('Repita a nova senha'), findsNothing);
    });

    testWidgets('exclusao exige a palavra de confirmacao e encerra a sessao', (
      WidgetTester tester,
    ) async {
      backend.on('DELETE', '/v1/guardian/account', (_) => http.Response('', 204));
      await pumpAt(tester, GuardianPaths.account);

      await tester.scrollUntilVisible(find.text('Excluir conta e dados'), 300);
      await tester.tap(find.text('Excluir conta e dados'));
      await settle(tester);

      FilledButton button() {
        return tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Excluir conta e todos os dados'),
        );
      }

      expect(button().onPressed, isNull);
      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Girassol-azul-42');
      await tester.enterText(fields.at(1), 'exclui');
      await tester.pump();
      expect(button().onPressed, isNull);
      await tester.enterText(fields.at(1), 'excluir');
      await tester.pump();
      expect(button().onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Excluir conta e todos os dados'));
      await settle(tester);

      expect(backend.lastBody('DELETE', '/v1/guardian/account'), <String, Object?>{
        'password': 'Girassol-azul-42',
      });
      expect(
        deps.di<AuthBloc>().state,
        const AuthSignedOut(reason: SessionEndReason.accountDeleted),
      );
    });
  });

  testWidgets('sessoes conectadas: encerra a sessao de outro aparelho', (
    WidgetTester tester,
  ) async {
    final Map<String, Object?> other = <String, Object?>{
      'id': 's2',
      'deviceName': 'Moto do Pedro',
      'lastSeenAt': deps.clock.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
      'current': false,
    };
    backend.onJson('GET', '/v1/guardian/sessions', <String, Object?>{
      'sessions': <Object?>[sessionJson(), other],
    });
    backend.on('DELETE', '/v1/guardian/sessions/s2', (_) {
      backend.onJson('GET', '/v1/guardian/sessions', <String, Object?>{
        'sessions': <Object?>[sessionJson()],
      });
      return http.Response('', 204);
    });
    await pumpAt(tester, GuardianPaths.sessions);

    expect(find.text('Este aparelho'), findsOneWidget);
    expect(find.text('Último acesso há 5 min'), findsOneWidget);

    await tester.tap(find.text('Encerrar'));
    await settle(tester);
    expect(find.textContaining('"Moto do Pedro" perde o acesso à conta'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Encerrar'));
    await settle(tester);

    expect(backend.calls('DELETE', '/v1/guardian/sessions/s2'), hasLength(1));
    expect(find.text('Sessão encerrada.'), findsOneWidget);
    expect(find.text('Moto do Pedro'), findsNothing);
  });

  testWidgets('registro de alteracoes carrega os registros mais antigos', (
    WidgetTester tester,
  ) async {
    backend.on('GET', '/v1/guardian/audit', (http.Request request) {
      if (request.url.queryParameters['before'] == null) {
        return jsonResponse(<String, Object?>{
          'entries': <Object?>[
            <String, Object?>{'id': 9, 'at': 1, 'action': 'policy.update', 'summary': 'Limite 2h'},
          ],
          'nextBefore': 9,
        });
      }
      return jsonResponse(<String, Object?>{
        'entries': <Object?>[
          <String, Object?>{'id': 4, 'at': 1, 'action': 'auth.login', 'summary': ''},
        ],
      });
    });
    await pumpAt(tester, GuardianPaths.audit);

    expect(find.text('Limite 2h'), findsOneWidget);
    await tester.tap(find.text('Carregar mais antigos'));
    await settle(tester);

    expect(find.text('auth.login'), findsOneWidget);
    expect(find.text('Carregar mais antigos'), findsNothing);
    expect(backend.calls('GET', '/v1/guardian/audit').last.url.queryParameters['before'], '9');
  });

  testWidgets('privacidade grava o prazo de retencao', (WidgetTester tester) async {
    backend.on('PATCH', '/v1/guardian/me', (http.Request request) {
      return jsonResponse(<String, Object?>{'guardian': guardianJson()});
    });
    await pumpAt(tester, GuardianPaths.privacy);

    await tester.scrollUntilVisible(find.text('Guardar o histórico por'), 300);
    expect(find.text('90 dias'), findsOneWidget);
    await tester.tap(find.text('Guardar o histórico por'));
    await settle(tester);
    await tester.tap(find.text('30 dias'));
    await settle(tester);

    final Map<String, Object?> body = backend.lastBody('PATCH', '/v1/guardian/me');
    expect((body['settings']! as Map<String, Object?>)['retentionDays'], 30);
    expect(find.text('Ajuste salvo.'), findsOneWidget);
  });

  testWidgets('bloqueio do painel grava o tempo escolhido e bloqueia agora', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, GuardianPaths.security);

    await tester.tap(find.text('5 minutos'));
    await settle(tester);
    expect(deps.preferences.values[LocalPrefKeys.appLockTimeoutSeconds], 300);

    await tester.tap(find.text('Bloquear agora'));
    await settle(tester);
    expect(deps.di<AuthBloc>().state, isA<AuthLocked>());
  });
}
