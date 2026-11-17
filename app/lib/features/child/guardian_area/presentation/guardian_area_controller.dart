import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/platform/native_providers.dart';
import '../../agent/data/child_agent_repository.dart';
import '../../agent/data/child_device_repository.dart';
import '../../agent/domain/child_models.dart';
import '../../agent/presentation/child_session.dart';
import '../domain/admin_auth_texts.dart';

/// Estado da area do responsavel no aparelho da crianca.
class GuardianAreaState {
  const GuardianAreaState({
    this.unlocked = false,
    this.verifying = false,
    this.codeMode = false,
    this.error,
  });

  /// Verdadeiro depois que o responsavel se autenticou nesta visita.
  final bool unlocked;
  final bool verifying;

  /// Verdadeiro quando a tela pede o codigo de acesso offline em vez da senha.
  final bool codeMode;
  final String? error;
}

final guardianAreaControllerProvider =
    NotifierProvider.autoDispose<GuardianAreaController, GuardianAreaState>(
      GuardianAreaController.new,
    );

/// Autenticacao do responsavel e operacoes administrativas neste aparelho.
///
/// Cada visita a area exige uma nova autenticacao, mesmo que a anterior ainda valha no lado
/// nativo: assim, depois que o responsavel sai, ninguem entra de novo sem a senha.
class GuardianAreaController extends Notifier<GuardianAreaState> {
  /// Senha usada nesta visita. Fica so em memoria e serve para o servidor revogar o vinculo.
  String? _password;

  @override
  GuardianAreaState build() {
    ref.onDispose(() => _password = null);
    return const GuardianAreaState();
  }

  /// Alterna entre pedir a senha e pedir o codigo de acesso offline.
  void setCodeMode({required bool enabled}) {
    if (!state.unlocked && !state.verifying) {
      state = GuardianAreaState(codeMode: enabled);
    }
  }

  Future<void> verifyPassword(String password) async {
    if (state.verifying || state.unlocked) {
      return;
    }
    if (password.isEmpty) {
      state = const GuardianAreaState(error: 'Digite a senha administrativa.');
      return;
    }
    final ChildAgentRepository agent = ref.read(childAgentRepositoryProvider);
    state = const GuardianAreaState(verifying: true);
    try {
      final AdminAuth result = await agent.verifyAdminPassword(password);
      if (!ref.mounted) {
        return;
      }
      if (result.status == AdminAuthStatus.ok) {
        _password = password;
        state = const GuardianAreaState(unlocked: true);
      } else {
        state = GuardianAreaState(
          // Sem conexao a senha nao pode ser conferida: oferece o codigo offline.
          codeMode: result.status == AdminAuthStatus.offline,
          error: adminAuthMessage(result, viaCode: false),
        );
      }
    } on AppFailure catch (failure) {
      if (ref.mounted) {
        state = GuardianAreaState(error: failure.message);
      }
    }
  }

  Future<void> verifyOfflineCode(String code) async {
    if (state.verifying || state.unlocked) {
      return;
    }
    final String digits = normalizeOfflineCode(code);
    if (digits.length != offlineCodeLength) {
      state = const GuardianAreaState(codeMode: true, error: 'O código tem 8 números.');
      return;
    }
    final ChildAgentRepository agent = ref.read(childAgentRepositoryProvider);
    state = const GuardianAreaState(codeMode: true, verifying: true);
    try {
      final AdminAuth result = await agent.verifyOfflineCode(digits);
      if (!ref.mounted) {
        return;
      }
      if (result.status == AdminAuthStatus.ok) {
        _password = null;
        state = const GuardianAreaState(unlocked: true, codeMode: true);
      } else {
        state = GuardianAreaState(codeMode: true, error: adminAuthMessage(result, viaCode: true));
      }
    } on AppFailure catch (failure) {
      if (ref.mounted) {
        state = GuardianAreaState(codeMode: true, error: failure.message);
      }
    }
  }

  /// Encerra a visita do responsavel.
  void lock() {
    _password = null;
    state = GuardianAreaState(codeMode: state.codeMode);
  }

  /// Libera o uso do aparelho por alguns minutos.
  Future<void> grantOverride(int minutes) {
    return _protected(() => ref.read(childAgentRepositoryProvider).grantLocalOverride(minutes));
  }

  Future<void> clearOverride() {
    return _protected(() => ref.read(childAgentRepositoryProvider).clearLocalOverride());
  }

  Future<void> requestDeviceAdmin() {
    return ref.read(childDeviceRepositoryProvider).requestDeviceAdmin();
  }

  Future<void> removeDeviceAdmin() {
    return _protected(() => ref.read(childDeviceRepositoryProvider).removeDeviceAdmin());
  }

  /// Abre mao do modo Device Owner. Devolve falso se o sistema nao aceitou.
  Future<bool> releaseDeviceOwner() {
    return _protected(() => ref.read(childDeviceRepositoryProvider).releaseDeviceOwner());
  }

  /// Desvincula este aparelho e volta a escolha de modo. Devolve falso se nao foi possivel.
  Future<bool> unlink() async {
    final ChildLinkController link = ref.read(childLinkProvider.notifier);
    final AppModeController mode = ref.read(appModeProvider.notifier);
    final String? password = _password;
    final bool done = await _protected(
      () => ref.read(childAgentRepositoryProvider).unlink(password),
    );
    if (!done) {
      return false;
    }
    _password = null;
    // Marca o aparelho como sem vinculo (o roteador sai desta tela) e so entao troca o modo.
    // Se a troca de modo falhar, a pessoa fica na tela do codigo, que tambem deixa voltar a
    // escolha de modo.
    link.markUnlinked();
    await mode.setMode(AppMode.unset);
    return true;
  }

  /// Executa uma operacao protegida. Se ela falhar porque a autenticacao venceu no lado
  /// nativo, volta a pedir a senha.
  Future<T> _protected<T>(Future<T> Function() operation) async {
    final ChildAgentRepository agent = ref.read(childAgentRepositoryProvider);
    try {
      return await operation();
    } on AppFailure {
      bool stillValid = true;
      try {
        stillValid = await agent.isAdminAuthValid();
      } on AppFailure {
        stillValid = true;
      }
      if (!stillValid && ref.mounted) {
        _password = null;
        state = GuardianAreaState(
          codeMode: state.codeMode,
          error: 'O acesso do responsável venceu. Entre de novo para continuar.',
        );
      }
      rethrow;
    }
  }
}
