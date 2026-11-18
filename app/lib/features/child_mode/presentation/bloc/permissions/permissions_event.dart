part of 'permissions_bloc.dart';

sealed class PermissionsEvent extends Equatable {
  const PermissionsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Ler as permissoes do zero (abertura da tela e "Tentar de novo").
final class PermissionsLoadRequested extends PermissionsEvent {
  const PermissionsLoadRequested();
}

/// Reler as permissoes, mantendo a tela (o app voltou das configuracoes do sistema).
final class PermissionsRefreshRequested extends PermissionsEvent {
  const PermissionsRefreshRequested();
}

/// A pessoa tocou no botao de um passo: abre a tela do sistema daquela permissao.
final class PermissionsStepOpened extends PermissionsEvent {
  const PermissionsStepOpened(this.kind);

  final PermissionKind kind;

  @override
  List<Object?> get props => <Object?>[kind];
}

/// Abrir as informacoes do app (configuracoes restritas).
final class PermissionsAppDetailsOpened extends PermissionsEvent {
  const PermissionsAppDetailsOpened();
}

/// A configuracao inicial terminou ("Concluir" ou "Continuar mesmo assim" confirmado).
final class PermissionsSetupFinished extends PermissionsEvent {
  const PermissionsSetupFinished();
}
