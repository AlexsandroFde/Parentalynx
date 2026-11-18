import 'package:equatable/equatable.dart';

/// Situacao do vinculo deste aparelho, usada para escolher a tela do modo crianca.
enum LinkPhase {
  /// Ainda consultando o agente nativo.
  unknown,

  /// A consulta ao agente falhou. A tela de entrada oferece tentar de novo.
  failed,

  /// Sem vinculo: tela do codigo.
  unlinked,

  /// Acabou de vincular: passa pela transparencia e pelas permissoes.
  onboarding,

  /// Vinculado e configurado: tela inicial.
  ready;

  /// Verdadeiro quando o agente nativo esta controlando o aparelho.
  bool get isLinked => this == LinkPhase.onboarding || this == LinkPhase.ready;
}

/// Por que o aparelho deixou de estar vinculado, quando a crianca precisa saber.
enum UnlinkReason {
  /// O responsavel removeu o vinculo pelo aparelho dele.
  revokedByGuardian,
}

/// Fase do vinculo e o motivo do ultimo desvinculo.
final class LinkState extends Equatable {
  const LinkState(this.phase, {this.unlinkReason});

  static const LinkState initial = LinkState(LinkPhase.unknown);

  final LinkPhase phase;

  /// So aparece na fase [LinkPhase.unlinked].
  final UnlinkReason? unlinkReason;

  @override
  List<Object?> get props => <Object?>[phase, unlinkReason];
}
