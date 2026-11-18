import '../../../../core/utils/observable_value.dart';
import '../../domain/entities/guardian_account.dart';
import '../../domain/entities/guardian_session.dart';
import '../../domain/repositories/i_current_account_repository.dart';
import '../../domain/repositories/i_session_repository.dart';
import '../datasources/local/session_local_data_source.dart';

/// Sessao do responsavel neste aparelho: credenciais gravadas e situacao em memoria.
///
/// Implementa as duas visoes da sessao: a completa ([ISessionRepository]) e a estreita, so
/// da conta ([ICurrentAccountRepository]). As duas sao a mesma instancia no conteiner de
/// dependencias, entao todos enxergam o mesmo estado.
class GuardianSessionStore implements ISessionRepository, ICurrentAccountRepository {
  GuardianSessionStore(this._local)
    // Com token gravado, a abertura a frio sempre comeca bloqueada.
    : _state = ObservableValue<GuardianSessionState>.seeded(
        _local.hasToken ? const SessionLocked() : const SessionSignedOut(),
      );

  final SessionLocalDataSource _local;
  final ObservableValue<GuardianSessionState> _state;

  @override
  GuardianSessionState get current => _state.value;

  @override
  Stream<GuardianSessionState> watch() => _state.stream;

  @override
  Stream<void> get rejections => _local.rejections;

  @override
  Future<void> open(AuthenticatedSession session) async {
    await _local.save(
      token: session.token,
      email: session.account.email,
      sessionId: session.session.id,
    );
    _state.add(
      SessionOpen(
        account: session.account,
        session: session.session,
        pendingRecoveryKey: session.recoveryKey,
      ),
    );
  }

  @override
  void unlock(GuardianProfile profile) {
    _state.add(SessionOpen(account: profile.account, session: profile.session));
  }

  @override
  void lock() {
    final GuardianSessionState state = current;
    if (state is SessionOpen) {
      _state.add(SessionLocked(account: state.account));
    }
  }

  @override
  void clearPendingRecoveryKey() {
    final GuardianSessionState state = current;
    if (state is SessionOpen) {
      _state.add(SessionOpen(account: state.account, session: state.session));
    }
  }

  @override
  Future<void> close(SessionEndReason reason) async {
    // O estado muda primeiro, para o roteador sair do painel antes das limpezas assincronas.
    _state.add(SessionSignedOut(reason: reason));
    await _local.clear();
  }

  @override
  Future<String?> storedEmail() => _local.storedEmail();

  @override
  GuardianAccount? get currentAccount {
    final GuardianSessionState state = current;
    return state is SessionOpen ? state.account : null;
  }

  @override
  Stream<GuardianAccount?> watchAccount() {
    return watch()
        .map((GuardianSessionState state) => state is SessionOpen ? state.account : null)
        .distinct();
  }

  @override
  void replaceAccount(GuardianAccount account) {
    final GuardianSessionState state = current;
    if (state is SessionOpen) {
      _state.add(state.withAccount(account));
    }
  }
}
