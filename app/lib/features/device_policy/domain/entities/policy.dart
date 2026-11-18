import 'package:equatable/equatable.dart';

import '../../../../core/time/formatters.dart';
import 'app_rules.dart';
import 'daily_limit.dart';
import 'policy_overrides.dart';
import 'protection_policy.dart';
import 'schedule_rules.dart';
import 'web_policy.dart';

export 'app_rules.dart';
export 'daily_limit.dart';
export 'local_time.dart';
export 'policy_overrides.dart';
export 'protection_policy.dart';
export 'schedule_rules.dart';
export 'web_policy.dart';

/// Politica de controle parental de um aparelho (protocolo, secao 4.2).
///
/// E um documento versionado: o responsavel edita as secoes, o servidor incrementa a versao e
/// o aparelho converge para a versao mais recente e confirma a versao aplicada. Todas as
/// classes sao imutaveis.
final class Policy extends Equatable {
  const Policy({
    required this.timezone,
    this.schema = 1,
    this.dailyLimit = DailyLimit.disabled,
    this.allowedHours = AllowedHours.disabled,
    this.blockPeriods = const <BlockPeriod>[],
    this.apps = const AppsPolicy(),
    this.web = const WebPolicy(),
    this.protection = const ProtectionPolicy(),
    this.overrides = const PolicyOverrides(),
  });

  final int schema;

  /// Fuso da politica. O dia da cota segue este fuso, nao o do aparelho.
  final String timezone;
  final DailyLimit dailyLimit;
  final AllowedHours allowedHours;
  final List<BlockPeriod> blockPeriods;
  final AppsPolicy apps;
  final WebPolicy web;
  final ProtectionPolicy protection;
  final PolicyOverrides overrides;

  /// Limite efetivo do dia da cota em minutos (dia da semana mais tempo extra), ou nulo se o
  /// limite esta desligado.
  int? effectiveLimitMinutes(String day) {
    if (!dailyLimit.enabled) {
      return null;
    }
    return dailyLimit.minutesFor(weekdayOfDay(day)) + overrides.extraMinutesFor(day);
  }

  /// A mesma politica sem os comandos temporarios, que so mudam pelas rotas de comando.
  Policy get editable => copyWith(overrides: const PolicyOverrides());

  /// Verdadeiro quando as regras editaveis das duas politicas sao iguais (os comandos
  /// temporarios sao ignorados).
  bool sameRulesAs(Policy other) => editable == other.editable;

  Policy copyWith({
    String? timezone,
    DailyLimit? dailyLimit,
    AllowedHours? allowedHours,
    List<BlockPeriod>? blockPeriods,
    AppsPolicy? apps,
    WebPolicy? web,
    ProtectionPolicy? protection,
    PolicyOverrides? overrides,
  }) {
    return Policy(
      schema: schema,
      timezone: timezone ?? this.timezone,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      allowedHours: allowedHours ?? this.allowedHours,
      blockPeriods: blockPeriods ?? this.blockPeriods,
      apps: apps ?? this.apps,
      web: web ?? this.web,
      protection: protection ?? this.protection,
      overrides: overrides ?? this.overrides,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    schema,
    timezone,
    dailyLimit,
    allowedHours,
    blockPeriods,
    apps,
    web,
    protection,
    overrides,
  ];
}
