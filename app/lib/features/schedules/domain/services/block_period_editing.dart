import '../../../device_policy/domain/entities/policy.dart';

/// Edicao da lista de periodos de bloqueio. Funcoes puras.
abstract final class BlockPeriodEditing {
  /// Quantos periodos a politica aceita.
  static const int maxPeriods = 50;

  static bool canAdd(List<BlockPeriod> periods) => periods.length < maxPeriods;

  /// Troca o periodo de mesmo identificador, ou acrescenta no fim quando e novo.
  static List<BlockPeriod> upsert(List<BlockPeriod> periods, BlockPeriod period) {
    final bool known = periods.any((BlockPeriod item) => item.id == period.id);
    if (!known) {
      return canAdd(periods) ? <BlockPeriod>[...periods, period] : periods;
    }
    return <BlockPeriod>[
      for (final BlockPeriod item in periods) item.id == period.id ? period : item,
    ];
  }

  static List<BlockPeriod> remove(List<BlockPeriod> periods, String periodId) {
    return periods.where((BlockPeriod item) => item.id != periodId).toList();
  }

  static List<BlockPeriod> setEnabled(List<BlockPeriod> periods, String periodId, bool enabled) {
    return <BlockPeriod>[
      for (final BlockPeriod item in periods)
        item.id == periodId ? item.withEnabled(enabled) : item,
    ];
  }

  /// Verdadeiro quando o periodo pontual ja terminou.
  static bool hasEnded(BlockPeriod period, int nowMs) {
    return period.kind == BlockPeriodKind.once && (period.endAt ?? 0) < nowMs;
  }

  /// Inicio sugerido de um periodo pontual novo: a proxima hora cheia, mais [hoursAhead].
  static DateTime suggestedInstant(DateTime now, {int hoursAhead = 0}) {
    return DateTime(now.year, now.month, now.day, now.hour + 1 + hoursAhead);
  }
}
