import 'package:equatable/equatable.dart';

import '../../../device_policy/domain/entities/policy.dart';

/// Regras de horario de um aparelho: horarios permitidos e periodos de bloqueio.
///
/// E a secao da politica editada pelas telas de horarios. Tem igualdade por valor, para que
/// se saiba se mudou no servidor durante a edicao.
final class ScheduleRules extends Equatable {
  const ScheduleRules({required this.allowedHours, required this.blockPeriods});

  final AllowedHours allowedHours;
  final List<BlockPeriod> blockPeriods;

  ScheduleRules copyWith({AllowedHours? allowedHours, List<BlockPeriod>? blockPeriods}) {
    return ScheduleRules(
      allowedHours: allowedHours ?? this.allowedHours,
      blockPeriods: blockPeriods ?? this.blockPeriods,
    );
  }

  @override
  List<Object?> get props => <Object?>[allowedHours, blockPeriods];
}
