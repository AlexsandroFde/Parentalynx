import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_account.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_session.dart';
import 'package:parentalynx/features/settings/domain/entities/audit_entry.dart';
import 'package:parentalynx/features/settings/domain/repositories/i_account_management_repository.dart';
import 'package:parentalynx/features/settings/settings_module.dart';

import '../../../support/fake_backend.dart';
import '../../../support/guardian_fixtures.dart';
import '../../../support/test_dependencies.dart';

/// Gestao da conta contra o servidor falso, no formato do protocolo.
void main() {
  late FakeBackend backend;
  late IAccountManagementRepository account;

  setUp(() {
    backend = FakeBackend();
    final TestDependencies deps = TestDependencies(backend: backend, sessionToken: 'gs_x');
    addTearDown(deps.dispose);
    registerSettingsModule(deps.di);
    account = deps.di<IAccountManagementRepository>();
  });

  test('ajustes da conta usam as rotas do protocolo', () async {
    backend.onJson('PATCH', '/v1/guardian/me', <String, Object?>{
      'guardian': guardianJson(displayName: 'Maria S.'),
    });
    backend.onJson('GET', '/v1/guardian/audit', <String, Object?>{
      'entries': <Object?>[
        <String, Object?>{'id': 5, 'at': 1, 'action': 'policy.update', 'summary': 'Limite 2h'},
      ],
      'nextBefore': 5,
    });
    backend.on('DELETE', '/v1/guardian/account', (_) => http.Response('', 204));

    final Result<GuardianAccount> renamed = await account.updateProfile(displayName: 'Maria S.');
    expect(renamed.valueOrNull?.displayName, 'Maria S.');
    expect(backend.lastBody('PATCH', '/v1/guardian/me'), <String, Object?>{
      'displayName': 'Maria S.',
    });

    final AuditLogPage page = (await account.audit()).valueOrNull!;
    expect(page.entries.single.summary, 'Limite 2h');
    expect(page.nextBefore, 5);
    expect(backend.calls('GET', '/v1/guardian/audit').single.url.queryParameters, <String, String>{
      'limit': '30',
    });

    expect(await account.deleteAccount('Girassol-azul-42'), isA<Ok<void>>());
    expect(backend.lastBody('DELETE', '/v1/guardian/account')['password'], 'Girassol-azul-42');
  });

  test('ajustes de retencao e alertas enviam todos os valores', () async {
    backend.onJson('PATCH', '/v1/guardian/me', <String, Object?>{'guardian': guardianJson()});

    await account.updateProfile(settings: const GuardianSettings(retentionDays: 30));

    expect(backend.lastBody('PATCH', '/v1/guardian/me'), <String, Object?>{
      'settings': <String, Object?>{
        'retentionDays': 30,
        'syncStaleMinutes': 180,
        'offlineHours': 24,
        'lowTimeMinutes': 10,
      },
    });
  });

  test('sessoes, senha, chave de recuperacao e paginacao da auditoria', () async {
    backend.onJson('GET', '/v1/guardian/sessions', <String, Object?>{
      'sessions': <Object?>[
        sessionJson(),
        <String, Object?>{'id': 's2', 'lastSeenAt': 10},
      ],
    });
    backend.on('DELETE', '/v1/guardian/sessions/s2', (_) => http.Response('', 204));
    backend.onJson('POST', '/v1/guardian/password', <String, Object?>{});
    backend.onJson('POST', '/v1/guardian/recovery-key', <String, Object?>{
      'recoveryKey': 'RK-NOVA',
    });
    backend.onJson('GET', '/v1/guardian/audit', <String, Object?>{
      'entries': <Object?>[
        <String, Object?>{'id': 3, 'deviceName': 'Galaxy da Maria', 'ip': '10.0.0.1'},
      ],
    });

    final List<GuardianSessionInfo> sessions = (await account.listSessions()).valueOrNull!;
    expect(sessions.first.current, isTrue);
    expect(sessions.last.deviceName, '');
    expect(sessions.last.current, isFalse);

    expect(await account.revokeSession('s2'), isA<Ok<void>>());
    await account.changePassword(currentPassword: 'antiga', newPassword: 'Girassol-azul-42');
    expect(backend.lastBody('POST', '/v1/guardian/password'), <String, Object?>{
      'currentPassword': 'antiga',
      'newPassword': 'Girassol-azul-42',
    });
    expect((await account.regenerateRecoveryKey('senha')).valueOrNull, 'RK-NOVA');

    final AuditLogPage older = (await account.audit(before: 5)).valueOrNull!;
    expect(older.hasMore, isFalse);
    expect(older.entries.single.action, '');
    expect(older.entries.single.deviceName, 'Galaxy da Maria');
    expect(backend.calls('GET', '/v1/guardian/audit').last.url.queryParameters['before'], '5');
  });

  test('recusa do servidor vira falha da API', () async {
    backend.onError('POST', '/v1/guardian/recovery-key', status: 401, code: 'invalid_credentials');

    final Result<String> result = await account.regenerateRecoveryKey('errada');

    expect(result.failureOrNull, isA<ApiFailure>());
    expect((result.failureOrNull! as ApiFailure).code, 'invalid_credentials');
  });
}
