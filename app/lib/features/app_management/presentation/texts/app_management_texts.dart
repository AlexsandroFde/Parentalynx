import '../../../device_policy/domain/entities/policy.dart';

/// Resumo das regras por app para a visao geral das regras.
String appsSummary(AppsPolicy apps) {
  final int blocked = apps.blockedCount;
  final int exceptions = apps.exceptionCount;
  final int withLimit = apps.rules.values
      .where((AppRule rule) => rule.dailyLimitMinutes != null)
      .length;
  final List<String> parts = <String>[
    if (blocked > 0) '$blocked ${blocked == 1 ? 'bloqueado' : 'bloqueados'}',
    if (exceptions > 0) '$exceptions ${exceptions == 1 ? 'exceção' : 'exceções'}',
    if (withLimit > 0) '$withLimit com limite próprio',
  ];
  final String rules = parts.isEmpty ? 'Nenhuma regra por app' : parts.join(', ');
  return apps.defaultForNewApps == NewAppDefault.blocked
      ? '$rules. Apps novos aguardam aprovação'
      : rules;
}

/// Resumo do que continua disponivel durante um bloqueio geral.
String exceptionsSummary(AppsPolicy apps) {
  final int exceptions = apps.exceptionCount;
  if (exceptions == 0) {
    return 'Emergência e funções do sistema sempre disponíveis';
  }
  return 'Emergência, sistema e $exceptions '
      '${exceptions == 1 ? 'app liberado' : 'apps liberados'}';
}
