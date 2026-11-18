import '../../../device_policy/domain/entities/policy.dart';

/// Regras de edicao dos avisos de pouco tempo do limite diario.
extension DailyLimitWarnings on DailyLimit {
  /// Opcoes de aviso para a crianca, em minutos restantes.
  static const List<int> options = <int>[30, 15, 10, 5, 1];

  /// Quantos avisos podem estar ligados ao mesmo tempo.
  static const int maxWarnings = 4;

  /// Verdadeiro quando o aviso de [minutes] pode ser ligado (ou ja esta ligado).
  bool canEnableWarning(int minutes) {
    return warnAtMinutes.contains(minutes) || warnAtMinutes.length < maxWarnings;
  }

  /// Liga ou desliga um aviso. A lista fica sem repeticao, do maior tempo para o menor.
  DailyLimit withWarning(int minutes, {required bool enabled}) {
    if (enabled && !canEnableWarning(minutes)) {
      return this;
    }
    final Set<int> next = <int>{...warnAtMinutes};
    if (enabled) {
      next.add(minutes);
    } else {
      next.remove(minutes);
    }
    final List<int> sorted = next.toList()..sort((int a, int b) => b.compareTo(a));
    return copyWith(warnAtMinutes: sorted);
  }
}
