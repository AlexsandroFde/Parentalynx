import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/bloc/action_status.dart';
import 'package:parentalynx/core/bloc/form_status.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/authentication/domain/entities/app_lock_timeout.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_account.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_session.dart';
import 'package:parentalynx/features/authentication/domain/usecases/app_lock_preference.dart';
import 'package:parentalynx/features/server_config/domain/usecases/watch_server_address.dart';
import 'package:parentalynx/features/settings/domain/entities/audit_entry.dart';
import 'package:parentalynx/features/settings/domain/entities/password_change_errors.dart';
import 'package:parentalynx/features/settings/domain/usecases/change_password.dart';
import 'package:parentalynx/features/settings/domain/usecases/delete_account.dart';
import 'package:parentalynx/features/settings/domain/usecases/get_app_version.dart';
import 'package:parentalynx/features/settings/domain/usecases/list_guardian_sessions.dart';
import 'package:parentalynx/features/settings/domain/usecases/load_audit_log.dart';
import 'package:parentalynx/features/settings/domain/usecases/regenerate_recovery_key.dart';
import 'package:parentalynx/features/settings/domain/usecases/revoke_guardian_session.dart';
import 'package:parentalynx/features/settings/domain/usecases/update_account_settings.dart';
import 'package:parentalynx/features/settings/domain/usecases/update_display_name.dart';
import 'package:parentalynx/features/settings/domain/usecases/watch_current_account.dart';
import 'package:parentalynx/features/settings/presentation/bloc/account/account_bloc.dart';
import 'package:parentalynx/features/settings/presentation/bloc/account_settings/account_settings_bloc.dart';
import 'package:parentalynx/features/settings/presentation/bloc/audit_log/audit_log_bloc.dart';
import 'package:parentalynx/features/settings/presentation/bloc/change_password/change_password_bloc.dart';
import 'package:parentalynx/features/settings/presentation/bloc/delete_account/delete_account_bloc.dart';
import 'package:parentalynx/features/settings/presentation/bloc/more/more_bloc.dart';
import 'package:parentalynx/features/settings/presentation/bloc/security/security_settings_bloc.dart';
import 'package:parentalynx/features/settings/presentation/bloc/sessions/sessions_bloc.dart';

class _MockWatchCurrentAccount extends Mock implements WatchCurrentAccount {}

class _MockUpdateDisplayName extends Mock implements UpdateDisplayName {}

class _MockRegenerateRecoveryKey extends Mock implements RegenerateRecoveryKey {}

class _MockChangePassword extends Mock implements ChangePassword {}

class _MockDeleteAccount extends Mock implements DeleteAccount {}

class _MockListGuardianSessions extends Mock implements ListGuardianSessions {}

class _MockRevokeGuardianSession extends Mock implements RevokeGuardianSession {}

class _MockLoadAuditLog extends Mock implements LoadAuditLog {}

class _MockAppLockPreference extends Mock implements AppLockPreference {}

class _MockUpdateAccountSettings extends Mock implements UpdateAccountSettings {}

class _MockWatchServerAddress extends Mock implements WatchServerAddress {}

class _MockGetAppVersion extends Mock implements GetAppVersion {}

const GuardianAccount _account = GuardianAccount(
  id: 'g1',
  email: 'maria@exemplo.com',
  displayName: 'Maria Souza',
  createdAt: 1,
);

const ApiFailure _wrongPassword = ApiFailure(
  status: 401,
  code: 'invalid_credentials',
  message: 'Credenciais invalidas.',
);

const NetworkFailure _offline = NetworkFailure();

GuardianSessionInfo _session(String id, {bool current = false}) {
  return GuardianSessionInfo(
    id: id,
    deviceName: 'Aparelho $id',
    createdAt: 1,
    lastSeenAt: 2,
    expiresAt: 3,
    elevatedUntil: 0,
    current: current,
  );
}

AuditEntry _entry(int id) {
  return AuditEntry(id: id, at: id, action: 'policy.update', summary: 'Alteracao $id');
}

void main() {
  setUpAll(() {
    registerFallbackValue(const GuardianSettings());
    registerFallbackValue(AppLockTimeout.standard);
  });

  group('AccountBloc', () {
    late _MockWatchCurrentAccount watchAccount;
    late _MockUpdateDisplayName updateDisplayName;
    late _MockRegenerateRecoveryKey regenerateRecoveryKey;

    setUp(() {
      watchAccount = _MockWatchCurrentAccount();
      updateDisplayName = _MockUpdateDisplayName();
      regenerateRecoveryKey = _MockRegenerateRecoveryKey();
      when(() => watchAccount.current).thenReturn(_account);
    });

    AccountBloc build() {
      return AccountBloc(
        watchAccount: watchAccount,
        updateDisplayName: updateDisplayName,
        regenerateRecoveryKey: regenerateRecoveryKey,
      );
    }

    test('comeca com a conta em memoria', () {
      expect(build().state.account, _account);
    });

    blocTest<AccountBloc, AccountState>(
      'acompanha as mudancas da conta',
      setUp: () {
        when(() => watchAccount()).thenAnswer(
          (_) => Stream<GuardianAccount?>.fromIterable(<GuardianAccount?>[
            _account,
            _account.copyWith(displayName: 'Maria S.'),
          ]),
        );
      },
      build: build,
      act: (AccountBloc bloc) => bloc.add(const AccountStarted()),
      expect: () => <AccountState>[
        const AccountState(account: _account),
        AccountState(account: _account.copyWith(displayName: 'Maria S.')),
      ],
    );

    blocTest<AccountBloc, AccountState>(
      'nome igual ao atual nao vai ao servidor',
      build: build,
      act: (AccountBloc bloc) => bloc.add(const AccountNameSubmitted(' Maria Souza ')),
      expect: () => const <AccountState>[],
      verify: (_) => verifyNever(() => updateDisplayName(any())),
    );

    blocTest<AccountBloc, AccountState>(
      'nome novo aceito avisa o sucesso',
      setUp: () {
        when(
          () => updateDisplayName('Maria S.'),
        ).thenAnswer((_) async => Ok<GuardianAccount>(_account.copyWith(displayName: 'Maria S.')));
      },
      build: build,
      act: (AccountBloc bloc) => bloc.add(const AccountNameSubmitted('Maria S.')),
      expect: () => const <AccountState>[
        AccountState(account: _account, command: AccountCommand.rename, action: ActionRunning()),
        AccountState(
          account: _account,
          command: AccountCommand.rename,
          action: ActionSucceeded(message: 'Nome alterado.'),
        ),
      ],
    );

    blocTest<AccountBloc, AccountState>(
      'pedido de senha cancelado volta ao repouso sem aviso',
      setUp: () {
        when(() => updateDisplayName('Maria S.'))
            .thenAnswer((_) async => const Err<GuardianAccount>(CancelledFailure()));
      },
      build: build,
      act: (AccountBloc bloc) => bloc.add(const AccountNameSubmitted('Maria S.')),
      expect: () => const <AccountState>[
        AccountState(account: _account, command: AccountCommand.rename, action: ActionRunning()),
        AccountState(account: _account, command: AccountCommand.rename),
      ],
    );

    blocTest<AccountBloc, AccountState>(
      'chave nova fica no estado ate a tela mostrar',
      setUp: () {
        when(() => regenerateRecoveryKey('senha'))
            .thenAnswer((_) async => const Ok<String>('RK-NOVA'));
      },
      build: build,
      act: (AccountBloc bloc) async {
        bloc.add(const AccountRecoveryKeyRequested('senha'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AccountRecoveryKeyShown());
      },
      expect: () => const <AccountState>[
        AccountState(
          account: _account,
          command: AccountCommand.recoveryKey,
          action: ActionRunning(),
        ),
        AccountState(
          account: _account,
          command: AccountCommand.recoveryKey,
          action: ActionSucceeded(),
          recoveryKey: 'RK-NOVA',
        ),
        AccountState(
          account: _account,
          command: AccountCommand.recoveryKey,
          action: ActionSucceeded(),
        ),
      ],
    );

    blocTest<AccountBloc, AccountState>(
      'senha recusada ao gerar a chave vira falha do comando',
      setUp: () {
        when(() => regenerateRecoveryKey('errada'))
            .thenAnswer((_) async => const Err<String>(_wrongPassword));
      },
      build: build,
      act: (AccountBloc bloc) => bloc.add(const AccountRecoveryKeyRequested('errada')),
      expect: () => const <AccountState>[
        AccountState(
          account: _account,
          command: AccountCommand.recoveryKey,
          action: ActionRunning(),
        ),
        AccountState(
          account: _account,
          command: AccountCommand.recoveryKey,
          action: ActionFailed(_wrongPassword),
        ),
      ],
    );
  });

  group('ChangePasswordBloc', () {
    late _MockChangePassword changePassword;
    late _MockWatchCurrentAccount watchAccount;

    setUp(() {
      changePassword = _MockChangePassword();
      watchAccount = _MockWatchCurrentAccount();
      when(() => watchAccount.current).thenReturn(_account);
    });

    ChangePasswordBloc build() {
      return ChangePasswordBloc(changePassword: changePassword, account: watchAccount);
    }

    const ChangePasswordState initial = ChangePasswordState(
      email: 'maria@exemplo.com',
      displayName: 'Maria Souza',
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'confere o formulario antes de enviar',
      build: build,
      act: (ChangePasswordBloc bloc) => bloc.add(
        const ChangePasswordSubmitted(
          currentPassword: '',
          newPassword: 'Girassol-azul-42',
          confirmation: 'outra',
        ),
      ),
      expect: () => <ChangePasswordState>[
        initial.copyWith(
          errors: const PasswordChangeErrors(
            current: 'Digite a senha atual.',
            confirmation: 'As senhas não são iguais.',
          ),
        ),
      ],
      verify: (_) => verifyNever(
        () => changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ),
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'senha atual errada vira a mensagem geral; voltar a digitar nao apaga',
      setUp: () {
        when(() => changePassword(currentPassword: 'antiga', newPassword: 'Girassol-azul-42'))
            .thenAnswer((_) async => const Err<void>(_wrongPassword));
      },
      build: build,
      act: (ChangePasswordBloc bloc) async {
        bloc.add(
          const ChangePasswordSubmitted(
            currentPassword: 'antiga',
            newPassword: 'Girassol-azul-42',
            confirmation: 'Girassol-azul-42',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ChangePasswordFieldEdited(PasswordChangeField.next));
      },
      expect: () => <ChangePasswordState>[
        initial.copyWith(status: FormStatus.submitting),
        initial.copyWith(errors: const PasswordChangeErrors(form: 'A senha atual está incorreta.')),
      ],
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'senha fraca recusada pelo servidor marca o campo da senha nova',
      setUp: () {
        when(() => changePassword(currentPassword: 'antiga', newPassword: 'Girassol-azul-42'))
            .thenAnswer(
              (_) async => const Err<void>(
                ApiFailure(
                  status: 400,
                  code: 'weak_password',
                  message: 'Fraca.',
                  details: JsonMap(<String, Object?>{'reasons': <Object?>[]}),
                ),
              ),
            );
      },
      build: build,
      act: (ChangePasswordBloc bloc) async {
        bloc.add(
          const ChangePasswordSubmitted(
            currentPassword: 'antiga',
            newPassword: 'Girassol-azul-42',
            confirmation: 'Girassol-azul-42',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ChangePasswordFieldEdited(PasswordChangeField.next));
      },
      expect: () => <ChangePasswordState>[
        initial.copyWith(status: FormStatus.submitting),
        initial.copyWith(
          errors: const PasswordChangeErrors(
            next: 'A senha não atende aos requisitos de segurança.',
          ),
        ),
        initial,
      ],
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'senha trocada conclui o formulario',
      setUp: () {
        when(() => changePassword(currentPassword: 'antiga', newPassword: 'Girassol-azul-42'))
            .thenAnswer((_) async => const Ok<void>(null));
      },
      build: build,
      act: (ChangePasswordBloc bloc) => bloc.add(
        const ChangePasswordSubmitted(
          currentPassword: 'antiga',
          newPassword: 'Girassol-azul-42',
          confirmation: 'Girassol-azul-42',
        ),
      ),
      expect: () => <ChangePasswordState>[
        initial.copyWith(status: FormStatus.submitting),
        initial.copyWith(status: FormStatus.succeeded),
      ],
    );
  });

  group('DeleteAccountBloc', () {
    late _MockDeleteAccount deleteAccount;

    setUp(() => deleteAccount = _MockDeleteAccount());

    DeleteAccountBloc build() => DeleteAccountBloc(deleteAccount: deleteAccount);

    blocTest<DeleteAccountBloc, DeleteAccountState>(
      'sem a palavra de confirmacao nada e enviado',
      build: build,
      act: (DeleteAccountBloc bloc) =>
          bloc.add(const DeleteAccountSubmitted(password: 'senha', word: 'EXCLUI')),
      expect: () => const <DeleteAccountState>[],
      verify: (_) => verifyNever(() => deleteAccount(any())),
    );

    blocTest<DeleteAccountBloc, DeleteAccountState>(
      'senha recusada aparece no campo e some ao digitar de novo',
      setUp: () {
        when(() => deleteAccount('errada'))
            .thenAnswer((_) async => const Err<void>(_wrongPassword));
      },
      build: build,
      act: (DeleteAccountBloc bloc) async {
        bloc.add(const DeleteAccountSubmitted(password: 'errada', word: 'excluir'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const DeleteAccountPasswordEdited());
      },
      expect: () => const <DeleteAccountState>[
        DeleteAccountState(status: FormStatus.submitting),
        DeleteAccountState(error: 'Senha incorreta.'),
        DeleteAccountState(),
      ],
    );

    blocTest<DeleteAccountBloc, DeleteAccountState>(
      'conta excluida conclui',
      setUp: () {
        when(() => deleteAccount('senha')).thenAnswer((_) async => const Ok<void>(null));
      },
      build: build,
      act: (DeleteAccountBloc bloc) =>
          bloc.add(const DeleteAccountSubmitted(password: 'senha', word: 'EXCLUIR')),
      expect: () => const <DeleteAccountState>[
        DeleteAccountState(status: FormStatus.submitting),
        DeleteAccountState(status: FormStatus.succeeded),
      ],
    );
  });

  group('SessionsBloc', () {
    late _MockListGuardianSessions listSessions;
    late _MockRevokeGuardianSession revokeSession;
    final List<GuardianSessionInfo> both = <GuardianSessionInfo>[
      _session('s1', current: true),
      _session('s2'),
    ];
    final List<GuardianSessionInfo> onlyCurrent = <GuardianSessionInfo>[
      _session('s1', current: true),
    ];

    setUp(() {
      listSessions = _MockListGuardianSessions();
      revokeSession = _MockRevokeGuardianSession();
    });

    SessionsBloc build() {
      return SessionsBloc(listSessions: listSessions, revokeSession: revokeSession);
    }

    blocTest<SessionsBloc, SessionsState>(
      'carrega a lista',
      setUp: () {
        when(() => listSessions()).thenAnswer((_) async => Ok<List<GuardianSessionInfo>>(both));
      },
      build: build,
      act: (SessionsBloc bloc) => bloc.add(const SessionsLoadRequested()),
      expect: () => <SessionsState>[const SessionsLoading(), SessionsLoaded(sessions: both)],
    );

    blocTest<SessionsBloc, SessionsState>(
      'falha ao carregar oferece tentar de novo',
      setUp: () {
        when(() => listSessions())
            .thenAnswer((_) async => const Err<List<GuardianSessionInfo>>(_offline));
      },
      build: build,
      act: (SessionsBloc bloc) => bloc.add(const SessionsLoadRequested()),
      expect: () => const <SessionsState>[SessionsLoading(), SessionsError(_offline)],
    );

    blocTest<SessionsBloc, SessionsState>(
      'sessao encerrada recarrega a lista',
      setUp: () {
        when(() => revokeSession('s2')).thenAnswer((_) async => const Ok<void>(null));
        when(() => listSessions())
            .thenAnswer((_) async => Ok<List<GuardianSessionInfo>>(onlyCurrent));
      },
      build: build,
      seed: () => SessionsLoaded(sessions: both),
      act: (SessionsBloc bloc) => bloc.add(const SessionRevokeRequested('s2')),
      expect: () => <SessionsState>[
        SessionsLoaded(sessions: both, action: const ActionRunning()),
        SessionsLoaded(
          sessions: onlyCurrent,
          action: const ActionSucceeded(message: 'Sessão encerrada.'),
        ),
      ],
    );

    blocTest<SessionsBloc, SessionsState>(
      'sem rede para recarregar, so tira a sessao encerrada da lista',
      setUp: () {
        when(() => revokeSession('s2')).thenAnswer((_) async => const Ok<void>(null));
        when(() => listSessions())
            .thenAnswer((_) async => const Err<List<GuardianSessionInfo>>(_offline));
      },
      build: build,
      seed: () => SessionsLoaded(sessions: both),
      act: (SessionsBloc bloc) => bloc.add(const SessionRevokeRequested('s2')),
      expect: () => <SessionsState>[
        SessionsLoaded(sessions: both, action: const ActionRunning()),
        SessionsLoaded(
          sessions: onlyCurrent,
          action: const ActionSucceeded(message: 'Sessão encerrada.'),
        ),
      ],
    );

    blocTest<SessionsBloc, SessionsState>(
      'encerramento recusado mantem a lista e avisa a falha',
      setUp: () {
        when(() => revokeSession('s2')).thenAnswer((_) async => const Err<void>(_offline));
      },
      build: build,
      seed: () => SessionsLoaded(sessions: both),
      act: (SessionsBloc bloc) => bloc.add(const SessionRevokeRequested('s2')),
      expect: () => <SessionsState>[
        SessionsLoaded(sessions: both, action: const ActionRunning()),
        SessionsLoaded(sessions: both, action: const ActionFailed(_offline)),
      ],
    );
  });

  group('AuditLogBloc', () {
    late _MockLoadAuditLog loadAuditLog;

    setUp(() => loadAuditLog = _MockLoadAuditLog());

    AuditLogBloc build() => AuditLogBloc(loadAuditLog: loadAuditLog);

    blocTest<AuditLogBloc, AuditLogState>(
      'registro vazio',
      setUp: () {
        when(() => loadAuditLog())
            .thenAnswer((_) async => const Ok<AuditLogPage>(AuditLogPage(entries: <AuditEntry>[])));
      },
      build: build,
      act: (AuditLogBloc bloc) => bloc.add(const AuditLogLoadRequested()),
      expect: () => const <AuditLogState>[AuditLogLoading(), AuditLogEmpty()],
    );

    blocTest<AuditLogBloc, AuditLogState>(
      'carrega as paginas mais antigas ate acabar',
      setUp: () {
        when(() => loadAuditLog()).thenAnswer(
          (_) async =>
              Ok<AuditLogPage>(AuditLogPage(entries: <AuditEntry>[_entry(9)], nextBefore: 9)),
        );
        when(() => loadAuditLog(before: 9)).thenAnswer(
          (_) async =>
              Ok<AuditLogPage>(AuditLogPage(entries: <AuditEntry>[_entry(4)], nextBefore: 4)),
        );
        when(() => loadAuditLog(before: 4)).thenAnswer(
          (_) async => const Ok<AuditLogPage>(AuditLogPage(entries: <AuditEntry>[], nextBefore: 1)),
        );
      },
      build: build,
      act: (AuditLogBloc bloc) async {
        bloc.add(const AuditLogLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AuditLogMoreRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AuditLogMoreRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AuditLogMoreRequested());
      },
      expect: () => <AuditLogState>[
        const AuditLogLoading(),
        AuditLogLoaded(entries: <AuditEntry>[_entry(9)], nextBefore: 9),
        AuditLogLoaded(entries: <AuditEntry>[_entry(9)], nextBefore: 9, loadingMore: true),
        AuditLogLoaded(entries: <AuditEntry>[_entry(9), _entry(4)], nextBefore: 4),
        AuditLogLoaded(
          entries: <AuditEntry>[_entry(9), _entry(4)],
          nextBefore: 4,
          loadingMore: true,
        ),
        AuditLogLoaded(entries: <AuditEntry>[_entry(9), _entry(4)]),
      ],
    );

    blocTest<AuditLogBloc, AuditLogState>(
      'falha na pagina seguinte mantem os registros e permite tentar de novo',
      setUp: () {
        when(() => loadAuditLog(before: 9))
            .thenAnswer((_) async => const Err<AuditLogPage>(_offline));
      },
      build: build,
      seed: () => AuditLogLoaded(entries: <AuditEntry>[_entry(9)], nextBefore: 9),
      act: (AuditLogBloc bloc) => bloc.add(const AuditLogMoreRequested()),
      expect: () => <AuditLogState>[
        AuditLogLoaded(entries: <AuditEntry>[_entry(9)], nextBefore: 9, loadingMore: true),
        AuditLogLoaded(entries: <AuditEntry>[_entry(9)], nextBefore: 9, moreFailure: _offline),
      ],
    );
  });

  group('SecuritySettingsBloc', () {
    late _MockAppLockPreference appLock;

    setUp(() {
      appLock = _MockAppLockPreference();
      when(() => appLock.read()).thenAnswer((_) async => AppLockTimeout.fiveMinutes);
      when(() => appLock.write(any())).thenAnswer((_) async {});
    });

    blocTest<SecuritySettingsBloc, SecuritySettingsState>(
      'mostra o tempo gravado e grava o escolhido',
      build: () => SecuritySettingsBloc(appLock: appLock),
      act: (SecuritySettingsBloc bloc) async {
        bloc.add(const SecuritySettingsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AppLockTimeoutSelected(AppLockTimeout.immediately));
      },
      expect: () => const <SecuritySettingsState>[
        SecuritySettingsState(timeout: AppLockTimeout.fiveMinutes),
        SecuritySettingsState(timeout: AppLockTimeout.immediately),
      ],
      verify: (_) => verify(() => appLock.write(AppLockTimeout.immediately)).called(1),
    );
  });

  group('AccountSettingsBloc', () {
    late _MockWatchCurrentAccount watchAccount;
    late _MockUpdateAccountSettings updateSettings;
    const GuardianSettings shorter = GuardianSettings(retentionDays: 30);

    setUp(() {
      watchAccount = _MockWatchCurrentAccount();
      updateSettings = _MockUpdateAccountSettings();
      when(() => watchAccount.current).thenReturn(_account);
    });

    AccountSettingsBloc build() {
      return AccountSettingsBloc(watchAccount: watchAccount, updateSettings: updateSettings);
    }

    blocTest<AccountSettingsBloc, AccountSettingsState>(
      'ajuste aceito avisa o sucesso',
      setUp: () {
        when(() => updateSettings(shorter))
            .thenAnswer((_) async => Ok<GuardianAccount>(_account.copyWith(settings: shorter)));
      },
      build: build,
      act: (AccountSettingsBloc bloc) => bloc.add(const AccountSettingsChanged(shorter)),
      expect: () => const <AccountSettingsState>[
        AccountSettingsState(account: _account, action: ActionRunning()),
        AccountSettingsState(
          account: _account,
          action: ActionSucceeded(message: 'Ajuste salvo.'),
        ),
      ],
    );

    blocTest<AccountSettingsBloc, AccountSettingsState>(
      'sem conexao avisa a falha',
      setUp: () {
        when(() => updateSettings(shorter))
            .thenAnswer((_) async => const Err<GuardianAccount>(_offline));
      },
      build: build,
      act: (AccountSettingsBloc bloc) => bloc.add(const AccountSettingsChanged(shorter)),
      expect: () => const <AccountSettingsState>[
        AccountSettingsState(account: _account, action: ActionRunning()),
        AccountSettingsState(account: _account, action: ActionFailed(_offline)),
      ],
    );
  });

  group('MoreBloc', () {
    blocTest<MoreBloc, MoreState>(
      'mostra a versao do app e acompanha o endereco do servidor',
      build: () {
        final _MockWatchServerAddress watchServerAddress = _MockWatchServerAddress();
        final _MockGetAppVersion getAppVersion = _MockGetAppVersion();
        when(() => watchServerAddress.current).thenReturn('https://servidor.teste');
        when(watchServerAddress.call).thenAnswer(
          (_) => Stream<String>.fromIterable(<String>[
            'https://servidor.teste',
            'https://outro.teste',
          ]),
        );
        when(getAppVersion.call).thenAnswer((_) async => '1.0.0');
        return MoreBloc(watchServerAddress: watchServerAddress, getAppVersion: getAppVersion);
      },
      act: (MoreBloc bloc) => bloc.add(const MoreStarted()),
      wait: const Duration(milliseconds: 10),
      verify: (MoreBloc bloc) {
        expect(
          bloc.state,
          const MoreState(serverAddress: 'https://outro.teste', appVersion: '1.0.0'),
        );
      },
    );

    test('comeca com o endereco atual, antes de qualquer aviso', () {
      final _MockWatchServerAddress watchServerAddress = _MockWatchServerAddress();
      when(() => watchServerAddress.current).thenReturn('');
      final MoreBloc bloc = MoreBloc(
        watchServerAddress: watchServerAddress,
        getAppVersion: _MockGetAppVersion(),
      );
      addTearDown(bloc.close);
      expect(bloc.state, const MoreState(serverAddress: ''));
    });
  });
}
