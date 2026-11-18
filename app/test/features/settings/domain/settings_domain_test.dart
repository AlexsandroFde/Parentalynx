import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_account.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_session.dart';
import 'package:parentalynx/features/authentication/domain/repositories/i_current_account_repository.dart';
import 'package:parentalynx/features/authentication/domain/usecases/end_session.dart';
import 'package:parentalynx/features/authentication/domain/usecases/run_elevated.dart';
import 'package:parentalynx/features/child_device/domain/entities/child_device.dart';
import 'package:parentalynx/features/settings/domain/entities/audit_entry.dart';
import 'package:parentalynx/features/settings/domain/entities/devices_overview.dart';
import 'package:parentalynx/features/settings/domain/entities/password_change_errors.dart';
import 'package:parentalynx/features/settings/domain/repositories/i_account_management_repository.dart';
import 'package:parentalynx/features/settings/domain/services/account_rules.dart';
import 'package:parentalynx/features/settings/domain/usecases/delete_account.dart';
import 'package:parentalynx/features/settings/domain/usecases/revoke_guardian_session.dart';
import 'package:parentalynx/features/settings/domain/usecases/update_account_settings.dart';
import 'package:parentalynx/features/settings/domain/usecases/update_display_name.dart';

import '../../../support/fakes.dart';

class _MockAccountManagement extends Mock implements IAccountManagementRepository {}

class _MockCurrentAccount extends Mock implements ICurrentAccountRepository {}

class _MockEndSession extends Mock implements EndSession {}

const GuardianAccount _account = GuardianAccount(
  id: 'g1',
  email: 'maria@exemplo.com',
  displayName: 'Maria Souza',
  createdAt: 1,
);

ApiFailure _apiFailure(String code) {
  return ApiFailure(status: 403, code: code, message: 'Recusado.');
}

ChildDevice _device({required String id, int pendingTimeRequests = 0}) {
  return ChildDevice(
    id: id,
    status: DeviceLinkStatus.active,
    childName: 'João',
    deviceName: 'Moto G',
    model: 'moto g54',
    manufacturer: 'motorola',
    androidRelease: '14',
    sdkInt: 34,
    appVersion: '1.0.0',
    timezone: 'America/Fortaleza',
    relink: false,
    createdAt: 1,
    online: true,
    today: '2026-11-17',
    managementMode: DeviceManagementMode.standard,
    policyVersion: 3,
    appliedPolicyVersion: 3,
    pendingTimeRequests: pendingTimeRequests,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_account);
    registerFallbackValue(const GuardianSettings());
    registerFallbackValue(SessionEndReason.signedOut);
  });

  group('AccountRules', () {
    test('nome de exibicao entre 1 e 60 caracteres, sem contar os espacos das pontas', () {
      expect(AccountRules.displayNameError('  Maria  '), isNull);
      expect(AccountRules.displayNameError('   '), 'Informe um nome com até 60 caracteres.');
      expect(AccountRules.displayNameError('a' * 61), 'Informe um nome com até 60 caracteres.');
      expect(AccountRules.displayNameError('a' * 60), isNull);
    });

    test('troca de senha confere a atual, a forca da nova e a repeticao', () {
      final PasswordChangeErrors empty = AccountRules.validatePasswordChange(
        current: '',
        next: 'abc',
        confirmation: 'abd',
      );
      expect(empty.current, 'Digite a senha atual.');
      expect(empty.next, isNotNull);
      expect(empty.confirmation, 'As senhas não são iguais.');

      final PasswordChangeErrors ok = AccountRules.validatePasswordChange(
        current: 'antiga',
        next: 'Girassol-azul-42',
        confirmation: 'Girassol-azul-42',
        email: 'maria@exemplo.com',
        displayName: 'Maria Souza',
      );
      expect(ok.isEmpty, isTrue);
    });

    test('exclusao exige a senha e a palavra EXCLUIR, sem diferenciar maiusculas', () {
      expect(AccountRules.canConfirmDeletion(password: 'x', word: ' excluir '), isTrue);
      expect(AccountRules.canConfirmDeletion(password: '', word: 'EXCLUIR'), isFalse);
      expect(AccountRules.canConfirmDeletion(password: 'x', word: 'EXCLUI'), isFalse);
    });

    test('erros da troca de senha somem campo a campo, mantendo a mensagem geral', () {
      const PasswordChangeErrors errors = PasswordChangeErrors(
        current: 'a',
        next: 'b',
        confirmation: 'c',
        form: 'd',
      );
      final PasswordChangeErrors without = errors.without(PasswordChangeField.next);
      expect(without.of(PasswordChangeField.next), isNull);
      expect(without.current, 'a');
      expect(without.form, 'd');
    });
  });

  test('DevicesOverview conta ativos, vinculos pendentes e pedidos de tempo dos ativos', () {
    final DevicesOverview overview = DevicesOverview.of(
      active: <ChildDevice>[
        _device(id: 'd1', pendingTimeRequests: 2),
        _device(id: 'd2', pendingTimeRequests: 1),
      ],
      pending: <ChildDevice>[_device(id: 'p1', pendingTimeRequests: 5)],
    );
    expect(overview.activeDevices, 2);
    expect(overview.pendingLinks, 1);
    expect(overview.pendingTimeRequests, 3);
  });

  test('AuditLogPage tem mais registros so com cursor e com registros na pagina', () {
    const AuditEntry entry = AuditEntry(id: 1, at: 1, action: 'auth.login', summary: '');
    expect(const AuditLogPage(entries: <AuditEntry>[entry], nextBefore: 1).hasMore, isTrue);
    expect(const AuditLogPage(entries: <AuditEntry>[], nextBefore: 1).hasMore, isFalse);
    expect(const AuditLogPage(entries: <AuditEntry>[entry]).hasMore, isFalse);
    expect(entry.title, 'auth.login');
  });

  group('UpdateDisplayName', () {
    late _MockAccountManagement repository;
    late _MockCurrentAccount account;
    late FakeElevationPrompter prompter;
    late UpdateDisplayName updateDisplayName;

    setUp(() {
      repository = _MockAccountManagement();
      account = _MockCurrentAccount();
      prompter = FakeElevationPrompter();
      updateDisplayName = UpdateDisplayName(
        repository: repository,
        account: account,
        runElevated: RunElevated(prompter),
      );
    });

    test('nome invalido nao vai ao servidor', () async {
      final Result<GuardianAccount> result = await updateDisplayName('   ');

      expect(result.failureOrNull, isA<ValidationFailure>());
      verifyNever(() => repository.updateProfile(displayName: any(named: 'displayName')));
    });

    test('nome aceito troca a conta em memoria, pedindo a senha quando o servidor exige', () async {
      final GuardianAccount renamed = _account.copyWith(displayName: 'Maria S.');
      int calls = 0;
      when(() => repository.updateProfile(displayName: 'Maria S.')).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? Err<GuardianAccount>(_apiFailure('elevation_required'))
            : Ok<GuardianAccount>(renamed);
      });

      final Result<GuardianAccount> result = await updateDisplayName('  Maria S. ');

      expect(result.valueOrNull, renamed);
      expect(prompter.requests, 1);
      verify(() => account.replaceAccount(renamed)).called(1);
    });

    test('pedido de senha cancelado devolve cancelamento e nao troca a conta', () async {
      prompter.accept = false;
      when(() => repository.updateProfile(displayName: 'Maria S.'))
          .thenAnswer((_) async => Err<GuardianAccount>(_apiFailure('elevation_required')));

      final Result<GuardianAccount> result = await updateDisplayName('Maria S.');

      expect(result.failureOrNull, isA<CancelledFailure>());
      verifyNever(() => account.replaceAccount(any()));
    });
  });

  test('UpdateAccountSettings grava e troca a conta em memoria', () async {
    final _MockAccountManagement repository = _MockAccountManagement();
    final _MockCurrentAccount account = _MockCurrentAccount();
    const GuardianSettings settings = GuardianSettings(retentionDays: 30);
    final GuardianAccount updated = _account.copyWith(settings: settings);
    when(() => repository.updateProfile(settings: settings))
        .thenAnswer((_) async => Ok<GuardianAccount>(updated));

    final Result<GuardianAccount> result = await UpdateAccountSettings(
      repository: repository,
      account: account,
      runElevated: RunElevated(FakeElevationPrompter()),
    )(settings);

    expect(result.valueOrNull, updated);
    verify(() => account.replaceAccount(updated)).called(1);
  });

  test('RevokeGuardianSession repete depois da senha confirmada', () async {
    final _MockAccountManagement repository = _MockAccountManagement();
    final FakeElevationPrompter prompter = FakeElevationPrompter();
    int calls = 0;
    when(() => repository.revokeSession('s2')).thenAnswer((_) async {
      calls++;
      return calls == 1 ? Err<void>(_apiFailure('elevation_required')) : const Ok<void>(null);
    });

    final Result<void> result = await RevokeGuardianSession(
      repository: repository,
      runElevated: RunElevated(prompter),
    )('s2');

    expect(result, isA<Ok<void>>());
    expect(calls, 2);
    expect(prompter.requests, 1);
  });

  group('DeleteAccount', () {
    test('encerra a sessao com o aviso de conta excluida depois do servidor', () async {
      final _MockAccountManagement repository = _MockAccountManagement();
      final _MockEndSession endSession = _MockEndSession();
      when(() => repository.deleteAccount('senha')).thenAnswer((_) async => const Ok<void>(null));
      when(() => endSession(any())).thenAnswer((_) async {});

      final Result<void> result = await DeleteAccount(
        repository: repository,
        endSession: endSession,
      )('senha');

      expect(result, isA<Ok<void>>());
      verify(() => endSession(SessionEndReason.accountDeleted)).called(1);
    });

    test('senha recusada mantem a sessao', () async {
      final _MockAccountManagement repository = _MockAccountManagement();
      final _MockEndSession endSession = _MockEndSession();
      when(() => repository.deleteAccount('errada'))
          .thenAnswer((_) async => Err<void>(_apiFailure('invalid_credentials')));

      final Result<void> result = await DeleteAccount(
        repository: repository,
        endSession: endSession,
      )('errada');

      expect(result, isA<Err<void>>());
      verifyNever(() => endSession(any()));
    });
  });
}
