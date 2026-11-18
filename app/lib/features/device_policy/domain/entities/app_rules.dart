import 'package:equatable/equatable.dart';

/// Estado de autorizacao de um app.
enum AppRuleState {
  /// Pode ser usado conforme as regras gerais.
  allowed('Permitido'),

  /// Nao pode ser aberto.
  blocked('Bloqueado'),

  /// Continua disponivel mesmo durante um bloqueio geral.
  exception('Exceção');

  const AppRuleState(this.label);

  final String label;
}

/// Regra de um app (protocolo, secao 4.2, `apps.rules`).
final class AppRule extends Equatable {
  const AppRule({required this.state, this.countsTowardLimit = false, this.dailyLimitMinutes});

  /// Regra de um pacote sem configuracao explicita.
  static const AppRule defaultAllowed = AppRule(state: AppRuleState.allowed);

  final AppRuleState state;

  /// So tem efeito em excecoes: se o tempo no app desconta da cota geral.
  final bool countsTowardLimit;

  /// Limite proprio do app em minutos por dia, ou nulo.
  final int? dailyLimitMinutes;

  /// Verdadeiro quando a regra equivale a nao ter regra. Usado para nao gravar entradas
  /// redundantes.
  bool get isDefault => state == AppRuleState.allowed && dailyLimitMinutes == null;

  /// Troca o estado mantendo so o que faz sentido no estado novo: contar na cota so vale
  /// para excecoes e app bloqueado nao tem limite proprio.
  AppRule withState(AppRuleState value) {
    return AppRule(
      state: value,
      countsTowardLimit: value == AppRuleState.exception && countsTowardLimit,
      dailyLimitMinutes: value == AppRuleState.blocked ? null : dailyLimitMinutes,
    );
  }

  AppRule withCountsTowardLimit(bool value) {
    return AppRule(state: state, countsTowardLimit: value, dailyLimitMinutes: dailyLimitMinutes);
  }

  AppRule withDailyLimit(int? minutes) {
    return AppRule(state: state, countsTowardLimit: countsTowardLimit, dailyLimitMinutes: minutes);
  }

  @override
  List<Object?> get props => <Object?>[state, countsTowardLimit, dailyLimitMinutes];
}

enum NewAppDefault { allowed, blocked }

/// Regras de aplicativos (protocolo, secao 4.2, `apps`).
final class AppsPolicy extends Equatable {
  const AppsPolicy({
    this.defaultForNewApps = NewAppDefault.allowed,
    this.rules = const <String, AppRule>{},
  });

  final NewAppDefault defaultForNewApps;

  /// Regras por nome de pacote.
  final Map<String, AppRule> rules;

  /// Regra explicita do pacote, ou "permitido" quando nao ha.
  AppRule ruleFor(String package) => rules[package] ?? AppRule.defaultAllowed;

  int get blockedCount {
    return rules.values.where((AppRule rule) => rule.state == AppRuleState.blocked).length;
  }

  int get exceptionCount {
    return rules.values.where((AppRule rule) => rule.state == AppRuleState.exception).length;
  }

  /// Devolve a politica com a regra do pacote trocada. Regra padrao remove a entrada.
  AppsPolicy withRule(String package, AppRule rule) {
    final Map<String, AppRule> next = <String, AppRule>{...rules};
    if (rule.isDefault) {
      next.remove(package);
    } else {
      next[package] = rule;
    }
    return AppsPolicy(defaultForNewApps: defaultForNewApps, rules: next);
  }

  AppsPolicy copyWith({NewAppDefault? defaultForNewApps, Map<String, AppRule>? rules}) {
    return AppsPolicy(
      defaultForNewApps: defaultForNewApps ?? this.defaultForNewApps,
      rules: rules ?? this.rules,
    );
  }

  @override
  List<Object?> get props => <Object?>[defaultForNewApps, rules];
}
