import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/core/constants/storage_keys.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_account.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_session.dart';
import 'package:parentalynx/features/authentication/domain/repositories/i_session_repository.dart';
import 'package:parentalynx/features/authentication/presentation/bloc/auth/auth_bloc.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/devices/devices_bloc.dart';
import 'package:parentalynx/features/settings/presentation/pages/change_password_page.dart';
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
  Future<GoRouter> pumpAt(
    WidgetTester tester,
    String location, {
    Brightness brightness = Brightness.light,
    Size size = phoneSize,
  }) {
    return pumpGuardianRoutes(
      tester,
      routes: settingsRoutes(deps.di),
      location: location,
      deps: deps,
      brightness: brightness,
      size: size,
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

      final Finder generate = find.widgetWithText(FilledButton, 'Gerar nova chave');
      await tester.tap(find.text('Gerar nova chave'));
      await settle(tester);
      expect(
        find.text('A chave atual deixa de valer assim que a nova for gerada.'),
        findsOneWidget,
      );
      await tester.tap(generate);
      await settle(tester);
      expect(find.text('Digite a senha administrativa.'), findsOneWidget);
      expect(backend.calls('POST', '/v1/guardian/recovery-key'), isEmpty);

      await tester.enterText(find.byType(TextField), 'errada');
      await tester.tap(generate);
      await settle(tester);
      // A recusa aparece no proprio pedido de senha, que continua aberto.
      expect(find.text('Senha incorreta.'), findsOneWidget);
      expect(generate, findsOneWidget);

      backend.onJson('POST', '/v1/guardian/recovery-key', <String, Object?>{
        'recoveryKey': 'RK-7H2KD-9QWXA',
      });
      await tester.enterText(find.byType(TextField), 'Girassol-azul-42');
      await tester.tap(generate);
      await settle(tester);

      expect(backend.lastBody('POST', '/v1/guardian/recovery-key'), <String, Object?>{
        'password': 'Girassol-azul-42',
      });
      expect(find.text('Guarde a chave de recuperação'), findsOneWidget);
      expect(find.text('NOVA CHAVE GERADA'), findsOneWidget);
      expect(find.textContaining('RK-7H2KD-9QWXA'), findsOneWidget);

      await tester.ensureVisible(find.text('Guardei a chave em um lugar seguro'));
      await tester.tap(find.text('Guardei a chave em um lugar seguro'));
      await settle(tester);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continuar'));
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
      expect(
        find.text('Senha alterada. Os outros celulares conectados precisam entrar de novo.'),
        findsOneWidget,
      );
      expect(find.text('Conta e senha'), findsOneWidget);
      expect(find.byType(ChangePasswordPage), findsNothing);
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
    await tester.tap(find.widgetWithText(FilledButton, 'Encerrar sessão'));
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

    // Sem descricao do servidor, o assunto aparece em palavras comuns, nunca o codigo.
    expect(find.text('Acesso à conta'), findsOneWidget);
    expect(find.text('auth.login'), findsNothing);
    expect(find.text('Carregar mais antigos'), findsNothing);
    expect(backend.calls('GET', '/v1/guardian/audit').last.url.queryParameters['before'], '9');
  });

  testWidgets('privacidade: encurtar o historico pede confirmacao antes de gravar', (
    WidgetTester tester,
  ) async {
    backend.on('PATCH', '/v1/guardian/me', (http.Request request) {
      return jsonResponse(<String, Object?>{'guardian': guardianJson()});
    });
    await pumpAt(tester, GuardianPaths.privacy);

    expect(find.text('Guardar o histórico por'), findsOneWidget);
    final ChoiceChip current = tester.widget(find.widgetWithText(ChoiceChip, '90 dias'));
    expect(current.selected, isTrue);

    // Desistir na confirmacao nao grava nada.
    await tester.tap(find.text('30 dias'));
    await settle(tester);
    expect(find.text('Guardar o histórico por 30 dias?'), findsOneWidget);
    expect(find.text('O que for apagado não pode ser recuperado.'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    expect(backend.calls('PATCH', '/v1/guardian/me'), isEmpty);

    await tester.tap(find.text('30 dias'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Reduzir para 30 dias'));
    await settle(tester);

    final Map<String, Object?> body = backend.lastBody('PATCH', '/v1/guardian/me');
    expect((body['settings']! as Map<String, Object?>)['retentionDays'], 30);
    expect(find.text('Ajuste salvo.'), findsOneWidget);
  });

  testWidgets('privacidade: aumentar o historico grava sem confirmacao', (
    WidgetTester tester,
  ) async {
    backend.on('PATCH', '/v1/guardian/me', (http.Request request) {
      return jsonResponse(<String, Object?>{'guardian': guardianJson()});
    });
    await pumpAt(tester, GuardianPaths.privacy);

    await tester.tap(find.text('180 dias'));
    await settle(tester);

    final Map<String, Object?> body = backend.lastBody('PATCH', '/v1/guardian/me');
    expect((body['settings']! as Map<String, Object?>)['retentionDays'], 180);
  });

  testWidgets('privacidade: aviso de pouco tempo escolhido na folha de opcoes', (
    WidgetTester tester,
  ) async {
    backend.on('PATCH', '/v1/guardian/me', (http.Request request) {
      return jsonResponse(<String, Object?>{'guardian': guardianJson()});
    });
    await pumpAt(tester, GuardianPaths.privacy);

    await tester.scrollUntilVisible(find.text('Pouco tempo restante'), 300);
    expect(find.text('Quando faltar 10min'), findsOneWidget);
    await tester.tap(find.text('Pouco tempo restante'));
    await settle(tester);
    await tester.tap(find.text('15min'));
    await settle(tester);

    final Map<String, Object?> body = backend.lastBody('PATCH', '/v1/guardian/me');
    expect((body['settings']! as Map<String, Object?>)['lowTimeMinutes'], 15);
  });

  testWidgets('exclusao sem conexao avisa que nada foi apagado', (WidgetTester tester) async {
    backend.on('DELETE', '/v1/guardian/account', (_) => throw const NetworkFailure());
    await pumpAt(tester, GuardianPaths.account);
    await tester.scrollUntilVisible(find.text('Excluir conta e dados'), 300);
    await tester.tap(find.text('Excluir conta e dados'));
    await settle(tester);
    // A tela diz qual conta sera apagada.
    expect(find.textContaining('A conta maria@exemplo.com'), findsOneWidget);

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Girassol-azul-42');
    await tester.enterText(fields.at(1), 'EXCLUIR');
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Excluir conta e todos os dados'));
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir conta e todos os dados'));
    await settle(tester);

    expect(find.text('A conta não foi excluída'), findsOneWidget);
    expect(find.textContaining('Nada foi apagado.'), findsOneWidget);
    expect(deps.di<AuthBloc>().state, isA<AuthReady>());
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

  // Aparencia de cada tela: temas claro e escuro, fonte 2x e diretrizes de acessibilidade.

  void sessionsAndAudit() {
    backend.onJson('GET', '/v1/guardian/sessions', <String, Object?>{
      'sessions': <Object?>[
        sessionJson(),
        <String, Object?>{
          'id': 's2',
          'deviceName': 'Moto do Pedro',
          'lastSeenAt': deps.clock.now().subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
          'current': false,
        },
      ],
    });
    final int now = deps.clock.now().millisecondsSinceEpoch;
    backend.onJson('GET', '/v1/guardian/audit', <String, Object?>{
      'entries': <Object?>[
        <String, Object?>{
          'id': 3,
          'at': now - 120000,
          'action': 'policy.update',
          'summary': 'Limite diário de João alterado de 2h para 2h30',
          'deviceName': 'Galaxy da Maria',
        },
        <String, Object?>{
          'id': 2,
          'at': now - 3600000,
          'action': 'auth.elevate_failed',
          'summary': 'Senha administrativa incorreta',
          'deviceName': 'Galaxy da Maria',
          'ip': '189.10.2.3',
        },
        <String, Object?>{
          'id': 1,
          'at': now - 90000000,
          'action': 'auth.login',
          'summary': 'Entrada em Galaxy da Maria',
          'ip': '189.10.2.3',
        },
      ],
    });
  }

  /// Abre uma tela pela rota ou, nas telas empilhadas, pelo toque na conta.
  Future<void> open(
    WidgetTester tester,
    String screen, {
    Brightness brightness = Brightness.light,
    Size size = phoneSize,
  }) async {
    sessionsAndAudit();
    final String location = switch (screen) {
      'sessoes' => GuardianPaths.sessions,
      'bloqueio' => GuardianPaths.security,
      'privacidade' => GuardianPaths.privacy,
      'registro' => GuardianPaths.audit,
      _ => GuardianPaths.account,
    };
    await pumpAt(tester, location, brightness: brightness, size: size);
    if (screen == 'trocar_senha') {
      await tester.tap(find.text('Trocar senha'));
      await settle(tester);
    }
    if (screen == 'excluir_conta') {
      await tester.scrollUntilVisible(find.text('Excluir conta e dados'), 300);
      await tester.tap(find.text('Excluir conta e dados'));
      await settle(tester);
    }
  }

  for (final String screen in <String>[
    'conta',
    'trocar_senha',
    'excluir_conta',
    'sessoes',
    'bloqueio',
    'privacidade',
    'registro',
  ]) {
    testWidgets('$screen: captura no tema claro', tags: 'screenshot', (WidgetTester tester) async {
      await open(tester, screen);
      await expectScreenshot(tester, 'guardian_$screen');
    });

    testWidgets('$screen: captura no tema escuro', tags: 'screenshot', (WidgetTester tester) async {
      await open(tester, screen, brightness: Brightness.dark);
      await expectScreenshot(tester, 'guardian_${screen}_escuro');
    });

    testWidgets('$screen: funciona com a fonte no maior tamanho', (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, screen, size: const Size(392, 3600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$screen: segue as diretrizes de acessibilidade', (WidgetTester tester) async {
      await open(tester, screen, size: const Size(392, 2400));
      await expectAccessible(tester);
    });
  }
}
