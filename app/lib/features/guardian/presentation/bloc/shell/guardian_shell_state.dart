part of 'guardian_shell_bloc.dart';

final class GuardianShellState extends Equatable {
  const GuardianShellState({this.pendingAction});

  /// Acao pedida por quem abriu o app (notificacao), ainda nao tratada.
  final LaunchAction? pendingAction;

  /// A casca deve abrir a aba Alertas.
  bool get opensAlerts => pendingAction == LaunchAction.alerts;

  @override
  List<Object?> get props => <Object?>[pendingAction];
}
