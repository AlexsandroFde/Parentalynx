import 'package:equatable/equatable.dart';

import '../../../device_policy/domain/entities/policy.dart';

/// Comandos do responsavel em vigor agora em um aparelho: pausa, suspensao de regras e tempo
/// extra de hoje.
final class ActiveCommands extends Equatable {
  const ActiveCommands({this.paused = false, this.suspension, this.extraMinutesToday = 0});

  /// Nenhum comando em vigor (ou politica ainda nao carregada).
  static const ActiveCommands none = ActiveCommands();

  /// Comandos da [policy] que valem no instante [nowMs], no dia da cota [today].
  factory ActiveCommands.of(Policy policy, {required int nowMs, required String today}) {
    final Suspension suspension = policy.overrides.suspension;
    return ActiveCommands(
      paused: policy.overrides.manualLock.isActiveAt(nowMs),
      suspension: suspension.isActiveAt(nowMs) ? suspension : null,
      extraMinutesToday: policy.overrides.extraMinutesFor(today),
    );
  }

  /// O aparelho esta pausado pelo responsavel.
  final bool paused;

  /// Suspensao de regras em vigor, ou nulo.
  final Suspension? suspension;

  /// Minutos extras ja concedidos para hoje.
  final int extraMinutesToday;

  bool get suspended => suspension != null;

  @override
  List<Object?> get props => <Object?>[paused, suspension, extraMinutesToday];
}
