part of 'guardian_area_bloc.dart';

/// Operacao administrativa em andamento.
enum GuardianOperation {
  grantOverride,
  clearOverride,
  requestDeviceAdmin,
  removeDeviceAdmin,
  releaseOwnership,
  unlink,
}

sealed class GuardianAreaState extends Equatable {
  const GuardianAreaState({required this.codeMode});

  /// Verdadeiro quando a autenticacao e pelo codigo de acesso offline em vez da senha.
  final bool codeMode;
}

/// Pedindo a senha ou o codigo de acesso offline.
final class GuardianAreaLocked extends GuardianAreaState {
  const GuardianAreaLocked({super.codeMode = false, this.verifying = false, this.error});

  final bool verifying;
  final String? error;

  @override
  List<Object?> get props => <Object?>[codeMode, verifying, error];
}

/// O responsavel se autenticou nesta visita: operacoes administrativas liberadas.
final class GuardianAreaUnlocked extends GuardianAreaState {
  const GuardianAreaUnlocked({
    super.codeMode = false,
    this.running,
    this.action = const ActionIdle(),
  });

  /// Operacao em andamento. Enquanto ha uma, os outros botoes ficam desabilitados.
  final GuardianOperation? running;

  /// Resultado da ultima operacao, para a tela avisar.
  final ActionStatus action;

  bool get isBusy => running != null;

  @override
  List<Object?> get props => <Object?>[codeMode, running, action];
}
