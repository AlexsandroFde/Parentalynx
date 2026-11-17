import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/config/app_config.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/core/storage/secure_store.dart';
import 'package:parentalynx/features/guardian/alerts/presentation/alerts_center_page.dart';
import 'package:parentalynx/features/guardian/auth/domain/guardian_account.dart';
import 'package:parentalynx/features/guardian/auth/presentation/login_page.dart';
import 'package:parentalynx/features/guardian/auth/presentation/recovery_key_page.dart';
import 'package:parentalynx/features/guardian/auth/presentation/register_page.dart';
import 'package:parentalynx/features/guardian/auth/presentation/session_controller.dart';
import 'package:parentalynx/features/guardian/auth/presentation/sign_in_page.dart';
import 'package:parentalynx/features/guardian/auth/presentation/unlock_page.dart';
import 'package:parentalynx/features/guardian/devices/presentation/device_detail_page.dart';
import 'package:parentalynx/features/guardian/pairing/presentation/pairing_page.dart';
import 'package:parentalynx/features/guardian/settings/presentation/more_page.dart';

import '../../support/test_app.dart';
import 'support/guardian_test_support.dart';

/// Sessao fixa, para montar telas que dependem do painel aberto.
class _FixedSession extends GuardianSessionController {
  _FixedSession(this._session);

  final GuardianSession _session;

  @override
  GuardianSession build() => _session;
}

GuardianReady _ready({String? pendingRecoveryKey}) {
  return GuardianReady(
    account: GuardianAccount.fromJson(JsonMap(guardianJson())),
    session: GuardianSessionInfo.fromJson(JsonMap(sessionJson())),
    pendingRecoveryKey: pendingRecoveryKey,
  );
}

void main() {
  late FakeBackend backend;
  late NativeDoubles native;
  late FakeClock clock;
  late FakeShareService share;

  setUp(() {
    backend = FakeBackend();
    native = NativeDoubles();
    clock = FakeClock();
    share = FakeShareService();
    backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{
      'devices': <Object?>[
        deviceJson(pendingTimeRequests: 1, issues: <String>['accessibility_disabled']),
      ],
    });
  });

  List<Override> overrides({String? token = 'gs_x', GuardianSession? session, SecureStore? store}) {
    return <Override>[
      ...guardianOverrides(
        backend: backend,
        native: native,
        sessionToken: token,
        clock: clock,
        share: share,
        secureStore: store,
      ),
      if (session != null) guardianSessionProvider.overrideWith(() => _FixedSession(session)),
    ];
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('porta de entrada', tags: 'screenshot', (WidgetTester tester) async {
    await pumpWidgetInApp(tester, const SignInPage(), overrides: overrides(token: null));
    await settle(tester);

    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.text('Já tenho conta'), findsOneWidget);
    expect(find.text('Voltar para a escolha de modo'), findsOneWidget);
    await expectScreenshot(tester, 'guardian_sign_in');
  });

  testWidgets('registro valida a senha antes de enviar', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    await pumpWidgetInApp(tester, const RegisterPage(), overrides: overrides(token: null));
    await settle(tester);
    final Finder fields = find.byType(TextField);
    // O nome do aparelho vem preenchido pelo sistema.
    expect(find.text('Galaxy da Maria'), findsOneWidget);

    await tester.enterText(fields.at(0), 'Maria Souza');
    await tester.enterText(fields.at(1), 'maria@exemplo.com');
    await tester.enterText(fields.at(2), 'curta1');
    await tester.enterText(fields.at(3), 'outra');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await settle(tester);

    expect(find.text('Use pelo menos 10 caracteres.'), findsOneWidget);
    expect(find.text('As senhas não são iguais.'), findsOneWidget);
    expect(backend.calls('POST', '/v1/auth/register'), isEmpty);

    await tester.enterText(fields.at(2), 'Girassol-azul-42');
    await tester.enterText(fields.at(3), 'Girassol-azul-42');
    await settle(tester);
    await tester.ensureVisible(find.text('Criar conta').first);
    await settle(tester);
    expect(find.textContaining('Força:'), findsOneWidget);
    await expectScreenshot(tester, 'guardian_register');
  });

  testWidgets('registro mostra o erro de e-mail ja usado no campo', (WidgetTester tester) async {
    backend.onError('POST', '/v1/auth/register', status: 409, code: 'email_in_use');
    await pumpWidgetInApp(tester, const RegisterPage(), overrides: overrides(token: null));
    await settle(tester);
    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Maria Souza');
    await tester.enterText(fields.at(1), 'maria@exemplo.com');
    await tester.enterText(fields.at(2), 'Girassol-azul-42');
    await tester.enterText(fields.at(3), 'Girassol-azul-42');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await settle(tester);

    expect(find.textContaining('Já existe uma conta com este e-mail'), findsOneWidget);
  });

  testWidgets('login mostra bloqueio por tentativas com o tempo de espera', (
    WidgetTester tester,
  ) async {
    backend.onError(
      'POST',
      '/v1/auth/login',
      status: 423,
      code: 'account_locked',
      details: <String, Object?>{'retryAfterSec': 120},
    );
    await pumpWidgetInApp(tester, const LoginPage(), overrides: overrides(token: null));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'maria@exemplo.com');
    await tester.enterText(find.byType(TextField).at(1), 'qualquer');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await settle(tester);

    expect(find.text('Muitas tentativas. Tente de novo em 2 minutos.'), findsOneWidget);
  });

  testWidgets('chave de recuperacao: copiar e confirmar', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    await pumpWidgetInApp(
      tester,
      const RecoveryKeyPage(),
      overrides: overrides(session: _ready(pendingRecoveryKey: 'RK-7H2KD-9QWXA-4MNP8-TZ5VB-C3RGE')),
    );
    await settle(tester);

    await tester.tap(find.text('Copiar'));
    await settle(tester);
    expect(share.copied.single, 'RK-7H2KD-9QWXA-4MNP8-TZ5VB-C3RGE');
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await expectScreenshot(tester, 'guardian_recovery_key');
  });

  testWidgets('tela de bloqueio mostra a conta gravada', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    await pumpWidgetInApp(
      tester,
      const UnlockPage(),
      overrides: overrides(
        store: InMemorySecureStore(<String, String>{
          StorageKeys.guardianEmail: 'maria@exemplo.com',
        }),
      ),
    );
    await settle(tester);

    expect(find.textContaining('maria@exemplo.com'), findsOneWidget);
    await expectScreenshot(tester, 'guardian_unlock');
  });

  testWidgets('vinculacao: gera o codigo e mostra o pedido com a confirmacao', tags: 'screenshot', (
    WidgetTester tester,
  ) async {
    final int expiresAt = clock.now.add(const Duration(minutes: 14)).millisecondsSinceEpoch;
    backend.onJson('GET', '/v1/guardian/pairing-codes/active', <String, Object?>{
      'code': null,
      'pending': <Object?>[],
    });
    backend.onJson('POST', '/v1/guardian/pairing-codes', <String, Object?>{
      'id': 'c1',
      'code': 'AB2D9XYZ',
      'expiresAt': expiresAt,
    }, status: 201);
    await pumpWidgetInApp(tester, const PairingPage(), overrides: overrides(session: _ready()));
    await settle(tester);
    expect(find.text('Gerar código de vinculação'), findsOneWidget);

    backend.onJson('GET', '/v1/guardian/pairing-codes/active', <String, Object?>{
      'code': <String, Object?>{'id': 'c1', 'expiresAt': expiresAt},
      'pending': <Object?>[],
    });
    await tester.tap(find.text('Gerar código'));
    await settle(tester);

    expect(find.text('AB2D-9XYZ'), findsOneWidget);
    expect(find.text('Expira em 14:00'), findsOneWidget);
    await tester.tap(find.text('Copiar'));
    await settle(tester);
    expect(share.copied.single, 'AB2D-9XYZ');
    await tester.pump(const Duration(seconds: 5));
    await expectScreenshot(tester, 'guardian_pairing_code');

    // O aparelho da crianca usou o codigo: o pedido aparece na consulta seguinte.
    backend.onJson('GET', '/v1/guardian/pairing-codes/active', <String, Object?>{
      'code': null,
      'pending': <Object?>[
        deviceJson(id: 'p1', status: 'pending', childName: '', confirmCode: '4821'),
      ],
    });
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);

    expect(find.text('Pedido de vínculo'), findsOneWidget);
    expect(find.text('4 8 2 1'), findsOneWidget);
    expect(find.text('AB2D-9XYZ'), findsNothing);

    // Aprovar exige o nome da crianca.
    await tester.tap(find.widgetWithText(FilledButton, 'Aprovar'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Aprovar').last);
    await settle(tester);
    expect(find.text('Informe o nome da criança.'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    await expectScreenshot(tester, 'guardian_pairing_request');
  });

  testWidgets('central de alertas', tags: 'screenshot', (WidgetTester tester) async {
    backend.onJson('GET', '/v1/guardian/alerts', <String, Object?>{
      'alerts': <Object?>[
        alertJson(
          id: 4,
          type: 'time_request',
          title: 'Pedido de tempo adicional',
          body: 'João pediu mais 30 minutos.',
          createdAt: minutesAgo(3),
        ),
        alertJson(id: 3, createdAt: minutesAgo(25)),
        alertJson(
          id: 2,
          type: 'permission_changed',
          title: 'Permissão desativada',
          body: 'O serviço de acessibilidade foi desativado no aparelho de João.',
          read: true,
          createdAt: minutesAgo(50),
        ),
        alertJson(
          id: 1,
          type: 'blocked_app_attempt',
          title: 'Tentativa de abrir app bloqueado',
          body: 'João tentou abrir o TikTok.',
          read: true,
          createdAt: minutesAgo(58),
        ),
      ],
      'latestId': 4,
      'unread': 2,
    });
    await pumpWidgetInApp(
      tester,
      const AlertsCenterPage(),
      overrides: overrides(session: _ready()),
    );
    await settle(tester);

    expect(find.text('1 pedido de tempo aguardando resposta'), findsOneWidget);
    expect(find.text('Limite diário atingido'), findsOneWidget);
    expect(find.textContaining('até cerca de 15 minutos'), findsOneWidget);
    await expectScreenshot(tester, 'guardian_alerts');
  });

  testWidgets(
    'detalhe do aparelho mostra o nivel de protecao e as permissoes',
    tags: 'screenshot',
    (WidgetTester tester) async {
      await pumpWidgetInApp(
        tester,
        const DeviceDetailPage(deviceId: 'd1'),
        overrides: overrides(session: _ready()),
      );
      await settle(tester);

      expect(find.text('Nível de proteção'), findsOneWidget);
      expect(find.text('Padrão'), findsOneWidget);
      expect(find.text('O que não é garantido'), findsOneWidget);
      await expectScreenshot(tester, 'guardian_device_detail');

      await tester.scrollUntilVisible(find.text('Acessibilidade: desativada'), 300);
      expect(find.textContaining('serviço de acessibilidade está desativado'), findsOneWidget);
    },
  );

  testWidgets('aba Mais', tags: 'screenshot', (WidgetTester tester) async {
    await pumpWidgetInApp(tester, const MorePage(), overrides: overrides(session: _ready()));
    await settle(tester);

    expect(find.text('Maria Souza'), findsOneWidget);
    expect(find.text('1 aparelho ativo'), findsOneWidget);
    expect(find.text('1 aguardando resposta'), findsOneWidget);
    await expectScreenshot(tester, 'guardian_more');
  });
}
