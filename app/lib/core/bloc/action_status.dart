import 'package:equatable/equatable.dart';

import '../errors/app_failure.dart';

/// Andamento de um comando disparado pela interface (salvar, aprovar, bloquear...).
///
/// Fica dentro do estado da tela. A pagina reage as transicoes com `BlocListener`
/// (`listenWhen: (a, b) => a.action != b.action`) para mostrar avisos uma unica vez. Como todo
/// comando passa por [ActionRunning], dois sucessos seguidos sempre geram duas transicoes.
sealed class ActionStatus extends Equatable {
  const ActionStatus();

  bool get isRunning => this is ActionRunning;
}

/// Nenhum comando em andamento.
final class ActionIdle extends ActionStatus {
  const ActionIdle();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Comando em andamento. A tela desabilita os controles que repetiriam o comando.
final class ActionRunning extends ActionStatus {
  const ActionRunning();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Comando concluido. [message] e o aviso de sucesso, quando ha um.
final class ActionSucceeded extends ActionStatus {
  const ActionSucceeded({this.message});

  final String? message;

  @override
  List<Object?> get props => <Object?>[message];
}

/// Comando recusado ou sem conexao. A tela mostra a mensagem da falha.
///
/// Cancelamento pela pessoa (fechar o pedido de senha) nao vira [ActionFailed]: volta para
/// [ActionIdle], sem aviso.
final class ActionFailed extends ActionStatus {
  const ActionFailed(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}

/// Converte uma falha no andamento correspondente, tratando o cancelamento como silencioso.
ActionStatus actionStatusForFailure(AppFailure failure) {
  return failure is CancelledFailure ? const ActionIdle() : ActionFailed(failure);
}
