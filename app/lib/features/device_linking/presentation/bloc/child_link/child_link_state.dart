part of 'child_link_bloc.dart';

/// Situacao do vinculo vista pela interface do modo crianca.
final class ChildLinkState extends Equatable {
  const ChildLinkState({required this.phase, this.unlinkReason});

  factory ChildLinkState.from(LinkState link) {
    return ChildLinkState(phase: link.phase, unlinkReason: link.unlinkReason);
  }

  final LinkPhase phase;
  final UnlinkReason? unlinkReason;

  /// Aviso para a tela do codigo, quando o vinculo foi desfeito pelo responsavel.
  String? get notice => unlinkNotice(unlinkReason);

  @override
  List<Object?> get props => <Object?>[phase, unlinkReason];
}
