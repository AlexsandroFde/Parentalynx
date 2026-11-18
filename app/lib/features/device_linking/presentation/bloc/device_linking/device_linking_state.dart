part of 'device_linking_bloc.dart';

/// Comando da tela de vinculacao, para a tela saber o que acabou de concluir ou falhar.
enum LinkingCommand { generate, cancel, approve, reject }

final class DeviceLinkingState extends Equatable {
  const DeviceLinkingState({
    required this.nowMs,
    this.code,
    this.otherCodeExpiresAt,
    this.requests = const <LinkRequest>[],
    this.approved,
    this.loaded = false,
    this.offline = false,
    this.codeExpired = false,
    this.command,
    this.actingOn,
    this.action = const ActionIdle(),
  });

  /// Hora usada na contagem regressiva, atualizada a cada segundo enquanto ha prazo na tela.
  final int nowMs;

  /// Codigo gerado neste aparelho e ainda valido no servidor, com o texto para mostrar.
  final LinkCode? code;

  /// Ha um codigo ativo no servidor que nao foi gerado aqui. O texto dele nao pode ser
  /// recuperado (o servidor guarda so o hash): resta gerar outro.
  final int? otherCodeExpiresAt;

  /// Pedidos de vinculo aguardando aprovacao.
  final List<LinkRequest> requests;

  /// Aparelho que acabou de ser aprovado, para a tela de sucesso.
  final LinkRequest? approved;

  /// Verdadeiro depois da primeira consulta ao servidor.
  final bool loaded;

  /// O codigo mostrado venceu sem ser usado. A tela explica e oferece gerar outro.
  final bool codeExpired;

  /// A ultima consulta falhou por falta de conexao.
  final bool offline;

  /// Ultimo comando disparado e o pedido a que ele se refere.
  final LinkingCommand? command;
  final String? actingOn;
  final ActionStatus action;

  bool get generating => command == LinkingCommand.generate && action.isRunning;

  bool get cancelling => command == LinkingCommand.cancel && action.isRunning;

  /// Pedido sendo aprovado ou rejeitado agora. Enquanto houver um, os outros ficam inativos.
  String? get busyRequestId {
    final bool deciding = command == LinkingCommand.approve || command == LinkingCommand.reject;
    return deciding && action.isRunning ? actingOn : null;
  }

  /// Tempo que falta para o codigo mostrado vencer.
  Duration get remaining => code?.remainingAt(nowMs) ?? Duration.zero;

  /// Validade do codigo ativo gerado em outro lugar, enquanto ainda vale.
  int? get otherCodeStillValidUntil {
    final int? expiresAt = otherCodeExpiresAt;
    return expiresAt != null && expiresAt > nowMs ? expiresAt : null;
  }

  DeviceLinkingState copyWith({
    int? nowMs,
    LinkCode? Function()? code,
    int? Function()? otherCodeExpiresAt,
    List<LinkRequest>? requests,
    LinkRequest? Function()? approved,
    bool? loaded,
    bool? offline,
    bool? codeExpired,
    LinkingCommand? command,
    String? Function()? actingOn,
    ActionStatus? action,
  }) {
    return DeviceLinkingState(
      nowMs: nowMs ?? this.nowMs,
      code: code == null ? this.code : code(),
      otherCodeExpiresAt: otherCodeExpiresAt == null
          ? this.otherCodeExpiresAt
          : otherCodeExpiresAt(),
      requests: requests ?? this.requests,
      approved: approved == null ? this.approved : approved(),
      loaded: loaded ?? this.loaded,
      offline: offline ?? this.offline,
      codeExpired: codeExpired ?? this.codeExpired,
      command: command ?? this.command,
      actingOn: actingOn == null ? this.actingOn : actingOn(),
      action: action ?? this.action,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    nowMs,
    code,
    otherCodeExpiresAt,
    requests,
    approved,
    loaded,
    offline,
    codeExpired,
    command,
    actingOn,
    action,
  ];
}
