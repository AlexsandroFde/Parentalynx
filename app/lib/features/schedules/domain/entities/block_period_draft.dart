import 'package:equatable/equatable.dart';

import '../../../device_policy/domain/entities/policy.dart';

/// Periodo de bloqueio como a pessoa o preencheu, antes de virar regra.
///
/// [id] e nulo para um periodo novo: o identificador e gerado ao gravar no rascunho.
final class BlockPeriodDraft extends Equatable {
  const BlockPeriodDraft({
    required this.label,
    required this.kind,
    required this.days,
    required this.start,
    required this.end,
    required this.startAt,
    required this.endAt,
    this.id,
    this.enabled = true,
  });

  final String? id;
  final String label;
  final BlockPeriodKind kind;

  /// Dias da semana ISO em que o periodo semanal comeca.
  final Set<int> days;
  final LocalTime start;
  final LocalTime end;

  /// Inicio e fim do periodo pontual.
  final DateTime startAt;
  final DateTime endAt;
  final bool enabled;

  /// O que falta corrigir para o periodo poder ser gravado, ou nulo quando esta pronto.
  String? get problem {
    if (label.trim().isEmpty) {
      return 'Dê um nome ao período, por exemplo "Hora de dormir".';
    }
    if (kind == BlockPeriodKind.weekly) {
      if (days.isEmpty) {
        return 'Escolha pelo menos um dia da semana.';
      }
      if (start == end) {
        return 'O início e o fim não podem ser iguais.';
      }
      return null;
    }
    if (!endAt.isAfter(startAt)) {
      return 'O fim precisa ser depois do início.';
    }
    return null;
  }

  /// Como [problem], conferindo tambem se um periodo pontual ja terminou em [now] (ele nao
  /// bloquearia nada).
  String? problemAt(DateTime now) {
    final String? base = problem;
    if (base != null) {
      return base;
    }
    if (kind == BlockPeriodKind.once && !endAt.isAfter(now)) {
      return 'Esse período já terminou. Escolha um fim depois de agora.';
    }
    return null;
  }

  /// Regra pronta para a politica. So chame quando [problem] for nulo.
  BlockPeriod toPeriod(String periodId) {
    final String name = label.trim();
    if (kind == BlockPeriodKind.weekly) {
      return BlockPeriod.weekly(
        id: periodId,
        label: name,
        days: days.toList()..sort(),
        start: start,
        end: end,
        enabled: enabled,
      );
    }
    return BlockPeriod.once(
      id: periodId,
      label: name,
      startAt: startAt.millisecondsSinceEpoch,
      endAt: endAt.millisecondsSinceEpoch,
      enabled: enabled,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, label, kind, days, start, end, startAt, endAt, enabled];
}
