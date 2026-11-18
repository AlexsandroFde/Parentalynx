part of 'protection_bloc.dart';

sealed class ProtectionEvent extends Equatable {
  const ProtectionEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela de protecao abriu para um aparelho (ou a pessoa pediu para tentar de novo).
final class ProtectionStarted extends ProtectionEvent {
  const ProtectionStarted(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => <Object?>[deviceId];
}

/// Liga ou desliga o bloqueio quando a protecao e desativada no aparelho.
final class ProtectionLockOnTamperChanged extends ProtectionEvent {
  const ProtectionLockOnTamperChanged(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => <Object?>[enabled];
}

/// Liga ou desliga uma trava do sistema (so no modo dispositivo gerenciado).
final class ProtectionSystemLockChanged extends ProtectionEvent {
  const ProtectionSystemLockChanged({required this.lock, required this.enabled});

  final SystemLock lock;
  final bool enabled;

  @override
  List<Object?> get props => <Object?>[lock, enabled];
}

/// Envia o rascunho ao servidor.
final class ProtectionSaveRequested extends ProtectionEvent {
  const ProtectionSaveRequested();
}

/// Descarta as alteracoes locais.
final class ProtectionDiscardRequested extends ProtectionEvent {
  const ProtectionDiscardRequested();
}

/// O servidor informou uma versao nova da politica do aparelho.
final class _ProtectionServerVersionChanged extends ProtectionEvent {
  const _ProtectionServerVersionChanged(this.version);

  final int version;

  @override
  List<Object?> get props => <Object?>[version];
}

/// Refaz as alteracoes recusadas por um conflito sobre a versao atual.
final class ProtectionRejectedChangesRestored extends ProtectionEvent {
  const ProtectionRejectedChangesRestored();
}
