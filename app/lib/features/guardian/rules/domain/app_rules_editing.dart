import '../../../../shared/domain/policy.dart';

/// Regras puras de edicao das regras por app. Sem Flutter e sem rede, para serem testadas
/// isoladamente.

/// Estado de um app como o responsavel deve enxerga-lo.
enum EffectiveAppState {
  allowed('Permitido'),
  blocked('Bloqueado'),
  exception('Exceção'),

  /// Sem regra, com "bloquear apps novos" ligado: bloqueado ate o responsavel decidir.
  pendingApproval('Aguardando aprovação'),

  /// Funcao essencial do sistema: nunca e bloqueada e nao pode ser configurada.
  essential('Essencial');

  const EffectiveAppState(this.label);

  final String label;

  /// Verdadeiro quando o app nao pode ser aberto.
  bool get isBlocked {
    return this == EffectiveAppState.blocked || this == EffectiveAppState.pendingApproval;
  }
}

/// Estado efetivo de um pacote na politica, seguindo a secao 4.2 do protocolo: pacote sem
/// regra e permitido, exceto quando apps novos ficam bloqueados e o app nao e de sistema.
EffectiveAppState effectiveAppState(
  AppsPolicy apps, {
  required String package,
  required bool system,
  required bool essential,
}) {
  if (essential) {
    return EffectiveAppState.essential;
  }
  final AppRule? rule = apps.rules[package];
  if (rule == null) {
    return apps.defaultForNewApps == NewAppDefault.blocked && !system
        ? EffectiveAppState.pendingApproval
        : EffectiveAppState.allowed;
  }
  return switch (rule.state) {
    AppRuleState.allowed => EffectiveAppState.allowed,
    AppRuleState.blocked => EffectiveAppState.blocked,
    AppRuleState.exception => EffectiveAppState.exception,
  };
}

/// Verdadeiro quando a regra equivale a nao ter regra para esse app.
///
/// Com "bloquear apps novos" ligado, "permitido" deixa de ser o padrao de um app de usuario:
/// a regra explicita e o que registra a aprovacao do responsavel.
bool _isRedundant(AppsPolicy apps, AppRule rule, {required bool system}) {
  if (!rule.isDefault) {
    return false;
  }
  return apps.defaultForNewApps == NewAppDefault.allowed || system;
}

/// Devolve as regras com a regra do pacote trocada. Entradas redundantes nao sao gravadas.
AppsPolicy setAppRule(AppsPolicy apps, String package, AppRule rule, {required bool system}) {
  final Map<String, AppRule> next = <String, AppRule>{...apps.rules};
  if (_isRedundant(apps, rule, system: system)) {
    next.remove(package);
  } else {
    next[package] = rule;
  }
  return apps.copyWith(rules: next);
}

/// App conhecido do aparelho, no minimo necessario para ajustar o padrao de apps novos.
typedef KnownApp = ({String package, bool system, bool essential});

/// Troca o padrao para apps novos sem mudar o que vale para os apps ja instalados.
///
/// Ao ligar o bloqueio, os apps de usuario ja conhecidos e ainda sem regra recebem a regra
/// explicita "permitido": so o que for instalado depois fica aguardando aprovacao. Ao
/// desligar, essas regras explicitas viram redundantes e sao removidas.
AppsPolicy setNewAppDefault(
  AppsPolicy apps,
  NewAppDefault value, {
  required Iterable<KnownApp> knownApps,
}) {
  if (apps.defaultForNewApps == value) {
    return apps;
  }
  final Map<String, AppRule> next = <String, AppRule>{...apps.rules};
  if (value == NewAppDefault.blocked) {
    for (final KnownApp app in knownApps) {
      if (!app.system && !app.essential && !next.containsKey(app.package)) {
        next[app.package] = AppRule.defaultAllowed;
      }
    }
  } else {
    next.removeWhere((String package, AppRule rule) => rule.isDefault);
  }
  return AppsPolicy(defaultForNewApps: value, rules: next);
}

/// Aplica o mesmo estado a varios apps de uma vez (por exemplo todos os jogos listados).
AppsPolicy setStateForMany(AppsPolicy apps, Iterable<KnownApp> targets, AppRuleState state) {
  AppsPolicy result = apps;
  for (final KnownApp app in targets) {
    if (app.essential) {
      continue;
    }
    final AppRule current = result.rules[app.package] ?? AppRule.defaultAllowed;
    result = setAppRule(result, app.package, current.withState(state), system: app.system);
  }
  return result;
}
