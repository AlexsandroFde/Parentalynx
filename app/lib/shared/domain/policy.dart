import 'package:collection/collection.dart';

import '../../core/json/json_reader.dart';
import '../../core/time/formatters.dart';

/// Modelo da politica de controle parental (protocolo, secao 4.2).
///
/// Todas as classes sao imutaveis. A leitura e tolerante: secao ausente assume o padrao, para
/// que um app antigo consiga ler uma politica gravada por uma versao mais nova.

const DeepCollectionEquality _deepEquality = DeepCollectionEquality();

/// Igualdade por valor baseada na forma JSON.
mixin JsonEquality {
  Map<String, Object?> toJson();

  @override
  bool operator ==(Object other) {
    return other is JsonEquality &&
        other.runtimeType == runtimeType &&
        _deepEquality.equals(other.toJson(), toJson());
  }

  @override
  int get hashCode => _deepEquality.hash(toJson());
}

/// Horario local `HH:mm`. Em fim de janela aceita `24:00`.
class LocalTime implements Comparable<LocalTime> {
  const LocalTime(this.hour, this.minute);

  factory LocalTime.parse(String text) {
    final List<String> parts = text.split(':');
    if (parts.length != 2) {
      throw JsonFormatException('Horario invalido: $text');
    }
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || minute < 0 || minute > 59) {
      throw JsonFormatException('Horario invalido: $text');
    }
    if (hour > 24 || (hour == 24 && minute != 0)) {
      throw JsonFormatException('Horario invalido: $text');
    }
    return LocalTime(hour, minute);
  }

  factory LocalTime.fromMinutes(int minutesOfDay) {
    return LocalTime(minutesOfDay ~/ 60, minutesOfDay % 60);
  }

  static const LocalTime midnight = LocalTime(0, 0);
  static const LocalTime endOfDay = LocalTime(24, 0);

  final int hour;
  final int minute;

  int get minutesOfDay => hour * 60 + minute;

  @override
  int compareTo(LocalTime other) => minutesOfDay.compareTo(other.minutesOfDay);

  @override
  bool operator ==(Object other) => other is LocalTime && other.minutesOfDay == minutesOfDay;

  @override
  int get hashCode => minutesOfDay.hashCode;

  @override
  String toString() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

class DailyLimit with JsonEquality {
  const DailyLimit({
    required this.enabled,
    required this.minutes,
    this.perWeekday = const <int, int>{},
    this.resetTime = LocalTime.midnight,
    this.warnAtMinutes = const <int>[15, 5],
  });

  factory DailyLimit.fromJson(JsonMap json) {
    final JsonMap? weekdays = json.objOrNull('perWeekday');
    return DailyLimit(
      enabled: json.boolOr('enabled', fallback: false),
      minutes: json.intOr('minutes', fallback: 120),
      perWeekday: <int, int>{
        if (weekdays != null)
          for (final String key in weekdays.keys)
            if (int.tryParse(key) != null) int.parse(key): weekdays.integer(key),
      },
      resetTime: LocalTime.parse(json.strOrNull('resetTime') ?? '00:00'),
      warnAtMinutes: json.has('warnAtMinutes') ? json.intList('warnAtMinutes') : const <int>[15, 5],
    );
  }

  static const DailyLimit disabled = DailyLimit(enabled: false, minutes: 120);

  final bool enabled;

  /// Minutos por dia, de 0 a 1440.
  final int minutes;

  /// Sobreposicao por dia da semana ISO (1 = segunda).
  final Map<int, int> perWeekday;
  final LocalTime resetTime;
  final List<int> warnAtMinutes;

  /// Limite do dia da semana informado, sem tempo extra.
  int minutesFor(int isoWeekday) => perWeekday[isoWeekday] ?? minutes;

  bool get sameEveryDay => perWeekday.isEmpty;

  DailyLimit copyWith({
    bool? enabled,
    int? minutes,
    Map<int, int>? perWeekday,
    LocalTime? resetTime,
    List<int>? warnAtMinutes,
  }) {
    return DailyLimit(
      enabled: enabled ?? this.enabled,
      minutes: minutes ?? this.minutes,
      perWeekday: perWeekday ?? this.perWeekday,
      resetTime: resetTime ?? this.resetTime,
      warnAtMinutes: warnAtMinutes ?? this.warnAtMinutes,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'enabled': enabled,
      'minutes': minutes,
      if (perWeekday.isNotEmpty)
        'perWeekday': <String, Object?>{
          for (final MapEntry<int, int> entry in perWeekday.entries) '${entry.key}': entry.value,
        },
      'resetTime': resetTime.toString(),
      'warnAtMinutes': warnAtMinutes,
    };
  }
}

/// Janela de uso permitido em alguns dias da semana.
class TimeWindow with JsonEquality {
  const TimeWindow({required this.days, required this.start, required this.end});

  factory TimeWindow.fromJson(JsonMap json) {
    return TimeWindow(
      days: json.intList('days'),
      start: LocalTime.parse(json.str('start')),
      end: LocalTime.parse(json.str('end')),
    );
  }

  final List<int> days;
  final LocalTime start;
  final LocalTime end;

  TimeWindow copyWith({List<int>? days, LocalTime? start, LocalTime? end}) {
    return TimeWindow(days: days ?? this.days, start: start ?? this.start, end: end ?? this.end);
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'days': days, 'start': start.toString(), 'end': end.toString()};
  }
}

class AllowedHours with JsonEquality {
  const AllowedHours({required this.enabled, this.windows = const <TimeWindow>[]});

  factory AllowedHours.fromJson(JsonMap json) {
    return AllowedHours(
      enabled: json.boolOr('enabled', fallback: false),
      windows: json.objList('windows').map(TimeWindow.fromJson).toList(),
    );
  }

  static const AllowedHours disabled = AllowedHours(enabled: false);

  final bool enabled;
  final List<TimeWindow> windows;

  /// Janelas que valem para o dia da semana informado.
  List<TimeWindow> windowsFor(int isoWeekday) {
    return windows.where((TimeWindow window) => window.days.contains(isoWeekday)).toList();
  }

  AllowedHours copyWith({bool? enabled, List<TimeWindow>? windows}) {
    return AllowedHours(enabled: enabled ?? this.enabled, windows: windows ?? this.windows);
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'enabled': enabled,
      'windows': windows.map((TimeWindow window) => window.toJson()).toList(),
    };
  }
}

enum BlockPeriodKind { weekly, once }

/// Periodo de bloqueio recorrente (semanal) ou pontual.
class BlockPeriod with JsonEquality {
  const BlockPeriod.weekly({
    required this.id,
    required this.label,
    required this.days,
    required LocalTime this.start,
    required LocalTime this.end,
    this.enabled = true,
  }) : kind = BlockPeriodKind.weekly,
       startAt = null,
       endAt = null;

  const BlockPeriod.once({
    required this.id,
    required this.label,
    required int this.startAt,
    required int this.endAt,
    this.enabled = true,
  }) : kind = BlockPeriodKind.once,
       days = const <int>[],
       start = null,
       end = null;

  factory BlockPeriod.fromJson(JsonMap json) {
    final String kind = json.strOrNull('kind') ?? 'weekly';
    if (kind == 'once') {
      return BlockPeriod.once(
        id: json.str('id'),
        label: json.strOrNull('label') ?? '',
        startAt: json.integer('startAt'),
        endAt: json.integer('endAt'),
        enabled: json.boolOr('enabled', fallback: true),
      );
    }
    return BlockPeriod.weekly(
      id: json.str('id'),
      label: json.strOrNull('label') ?? '',
      days: json.intList('days'),
      start: LocalTime.parse(json.str('start')),
      end: LocalTime.parse(json.str('end')),
      enabled: json.boolOr('enabled', fallback: true),
    );
  }

  final String id;
  final String label;
  final bool enabled;
  final BlockPeriodKind kind;

  /// Dias em que o periodo semanal comeca.
  final List<int> days;
  final LocalTime? start;
  final LocalTime? end;
  final int? startAt;
  final int? endAt;

  /// Verdadeiro quando o periodo semanal atravessa a meia-noite.
  bool get crossesMidnight {
    final LocalTime? startTime = start;
    final LocalTime? endTime = end;
    return startTime != null && endTime != null && startTime.compareTo(endTime) > 0;
  }

  BlockPeriod withEnabled(bool value) {
    return switch (kind) {
      BlockPeriodKind.weekly => BlockPeriod.weekly(
        id: id,
        label: label,
        days: days,
        start: start!,
        end: end!,
        enabled: value,
      ),
      BlockPeriodKind.once => BlockPeriod.once(
        id: id,
        label: label,
        startAt: startAt!,
        endAt: endAt!,
        enabled: value,
      ),
    };
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'label': label,
      'enabled': enabled,
      'kind': kind.name,
      if (kind == BlockPeriodKind.weekly) ...<String, Object?>{
        'days': days,
        'start': start.toString(),
        'end': end.toString(),
      },
      if (kind == BlockPeriodKind.once) ...<String, Object?>{'startAt': startAt, 'endAt': endAt},
    };
  }
}

/// Estado de autorizacao de um app.
enum AppRuleState {
  /// Pode ser usado conforme as regras gerais.
  allowed,

  /// Nao pode ser aberto.
  blocked,

  /// Continua disponivel mesmo durante um bloqueio geral.
  exception;

  static AppRuleState parse(String value) {
    return switch (value) {
      'blocked' => AppRuleState.blocked,
      'exception' => AppRuleState.exception,
      _ => AppRuleState.allowed,
    };
  }

  String get label {
    return switch (this) {
      AppRuleState.allowed => 'Permitido',
      AppRuleState.blocked => 'Bloqueado',
      AppRuleState.exception => 'Exceção',
    };
  }
}

class AppRule with JsonEquality {
  const AppRule({required this.state, this.countsTowardLimit = false, this.dailyLimitMinutes});

  factory AppRule.fromJson(JsonMap json) {
    return AppRule(
      state: AppRuleState.parse(json.strOrNull('state') ?? 'allowed'),
      countsTowardLimit: json.boolOr('countsTowardLimit', fallback: false),
      dailyLimitMinutes: json.intOrNull('dailyLimitMinutes'),
    );
  }

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
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'state': state.name,
      if (state == AppRuleState.exception) 'countsTowardLimit': countsTowardLimit,
      if (dailyLimitMinutes != null) 'dailyLimitMinutes': dailyLimitMinutes,
    };
  }
}

enum NewAppDefault { allowed, blocked }

class AppsPolicy with JsonEquality {
  const AppsPolicy({
    this.defaultForNewApps = NewAppDefault.allowed,
    this.rules = const <String, AppRule>{},
  });

  factory AppsPolicy.fromJson(JsonMap json) {
    final JsonMap? rules = json.objOrNull('rules');
    return AppsPolicy(
      defaultForNewApps: json.strOrNull('defaultForNewApps') == 'blocked'
          ? NewAppDefault.blocked
          : NewAppDefault.allowed,
      rules: <String, AppRule>{
        if (rules != null)
          for (final String package in rules.keys) package: AppRule.fromJson(rules.obj(package)),
      },
    );
  }

  final NewAppDefault defaultForNewApps;
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
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'defaultForNewApps': defaultForNewApps.name,
      'rules': <String, Object?>{
        for (final MapEntry<String, AppRule> entry in rules.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }
}

enum WebMode { blocklist, allowlist }

/// Categorias de sites que o navegador gerenciado sabe bloquear.
enum WebCategory {
  adult('adult', 'Conteúdo adulto'),
  gambling('gambling', 'Apostas e jogos de azar'),
  social('social', 'Redes sociais'),
  video('video', 'Vídeo e streaming'),
  games('games', 'Jogos');

  const WebCategory(this.code, this.label);

  final String code;
  final String label;

  static WebCategory? fromCode(String code) {
    for (final WebCategory category in values) {
      if (category.code == code) {
        return category;
      }
    }
    return null;
  }
}

class WebPolicy with JsonEquality {
  const WebPolicy({
    this.managedBrowser = true,
    this.logHistory = true,
    this.safeDns = true,
    this.safeSearch = true,
    this.mode = WebMode.blocklist,
    this.blockedDomains = const <String>[],
    this.allowedDomains = const <String>[],
    this.blockedCategories = const <String>['adult', 'gambling'],
  });

  factory WebPolicy.fromJson(JsonMap json) {
    return WebPolicy(
      managedBrowser: json.boolOr('managedBrowser', fallback: true),
      logHistory: json.boolOr('logHistory', fallback: true),
      safeDns: json.boolOr('safeDns', fallback: true),
      safeSearch: json.boolOr('safeSearch', fallback: true),
      mode: json.strOrNull('mode') == 'allowlist' ? WebMode.allowlist : WebMode.blocklist,
      blockedDomains: json.strList('blockedDomains'),
      allowedDomains: json.strList('allowedDomains'),
      blockedCategories: json.strList('blockedCategories'),
    );
  }

  final bool managedBrowser;
  final bool logHistory;
  final bool safeDns;
  final bool safeSearch;
  final WebMode mode;
  final List<String> blockedDomains;
  final List<String> allowedDomains;
  final List<String> blockedCategories;

  WebPolicy copyWith({
    bool? managedBrowser,
    bool? logHistory,
    bool? safeDns,
    bool? safeSearch,
    WebMode? mode,
    List<String>? blockedDomains,
    List<String>? allowedDomains,
    List<String>? blockedCategories,
  }) {
    return WebPolicy(
      managedBrowser: managedBrowser ?? this.managedBrowser,
      logHistory: logHistory ?? this.logHistory,
      safeDns: safeDns ?? this.safeDns,
      safeSearch: safeSearch ?? this.safeSearch,
      mode: mode ?? this.mode,
      blockedDomains: blockedDomains ?? this.blockedDomains,
      allowedDomains: allowedDomains ?? this.allowedDomains,
      blockedCategories: blockedCategories ?? this.blockedCategories,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'managedBrowser': managedBrowser,
      'logHistory': logHistory,
      'safeDns': safeDns,
      'safeSearch': safeSearch,
      'mode': mode.name,
      'blockedDomains': blockedDomains,
      'allowedDomains': allowedDomains,
      'blockedCategories': blockedCategories,
    };
  }

  /// Limpa um dominio digitado: sem esquema, caminho, `www.` e em minusculas. Devolve nulo se
  /// o resultado nao parece um dominio.
  static String? normalizeDomain(String input) {
    String value = input.trim().toLowerCase();
    value = value.replaceFirst(RegExp(r'^[a-z][a-z0-9+.-]*://'), '');
    value = value.split('/').first.split('?').first.split('#').first;
    value = value.split('@').last.split(':').first;
    if (value.startsWith('www.')) {
      value = value.substring(4);
    }
    final RegExp pattern = RegExp(r'^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$');
    return pattern.hasMatch(value) ? value : null;
  }
}

class ProtectionPolicy with JsonEquality {
  const ProtectionPolicy({
    this.lockOnTamper = false,
    this.blockUninstall = true,
    this.blockSafeBoot = true,
    this.blockFactoryReset = true,
    this.blockDateTimeChange = true,
    this.blockAddUser = true,
    this.blockUnknownSources = false,
    this.blockUsbDebugging = false,
  });

  factory ProtectionPolicy.fromJson(JsonMap json) {
    return ProtectionPolicy(
      lockOnTamper: json.boolOr('lockOnTamper', fallback: false),
      blockUninstall: json.boolOr('blockUninstall', fallback: true),
      blockSafeBoot: json.boolOr('blockSafeBoot', fallback: true),
      blockFactoryReset: json.boolOr('blockFactoryReset', fallback: true),
      blockDateTimeChange: json.boolOr('blockDateTimeChange', fallback: true),
      blockAddUser: json.boolOr('blockAddUser', fallback: true),
      blockUnknownSources: json.boolOr('blockUnknownSources', fallback: false),
      blockUsbDebugging: json.boolOr('blockUsbDebugging', fallback: false),
    );
  }

  final bool lockOnTamper;

  // As chaves abaixo so tem efeito no modo Device Owner.
  final bool blockUninstall;
  final bool blockSafeBoot;
  final bool blockFactoryReset;
  final bool blockDateTimeChange;
  final bool blockAddUser;
  final bool blockUnknownSources;
  final bool blockUsbDebugging;

  ProtectionPolicy copyWith({
    bool? lockOnTamper,
    bool? blockUninstall,
    bool? blockSafeBoot,
    bool? blockFactoryReset,
    bool? blockDateTimeChange,
    bool? blockAddUser,
    bool? blockUnknownSources,
    bool? blockUsbDebugging,
  }) {
    return ProtectionPolicy(
      lockOnTamper: lockOnTamper ?? this.lockOnTamper,
      blockUninstall: blockUninstall ?? this.blockUninstall,
      blockSafeBoot: blockSafeBoot ?? this.blockSafeBoot,
      blockFactoryReset: blockFactoryReset ?? this.blockFactoryReset,
      blockDateTimeChange: blockDateTimeChange ?? this.blockDateTimeChange,
      blockAddUser: blockAddUser ?? this.blockAddUser,
      blockUnknownSources: blockUnknownSources ?? this.blockUnknownSources,
      blockUsbDebugging: blockUsbDebugging ?? this.blockUsbDebugging,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'lockOnTamper': lockOnTamper,
      'blockUninstall': blockUninstall,
      'blockSafeBoot': blockSafeBoot,
      'blockFactoryReset': blockFactoryReset,
      'blockDateTimeChange': blockDateTimeChange,
      'blockAddUser': blockAddUser,
      'blockUnknownSources': blockUnknownSources,
      'blockUsbDebugging': blockUsbDebugging,
    };
  }
}

class ExtraTimeGrant with JsonEquality {
  const ExtraTimeGrant({
    required this.id,
    required this.day,
    required this.minutes,
    required this.grantedAt,
  });

  factory ExtraTimeGrant.fromJson(JsonMap json) {
    return ExtraTimeGrant(
      id: json.str('id'),
      day: json.str('day'),
      minutes: json.integer('minutes'),
      grantedAt: json.intOr('grantedAt', fallback: 0),
    );
  }

  final String id;
  final String day;
  final int minutes;
  final int grantedAt;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'id': id, 'day': day, 'minutes': minutes, 'grantedAt': grantedAt};
  }
}

class ManualLock with JsonEquality {
  const ManualLock({required this.active, this.until, this.setAt});

  factory ManualLock.fromJson(JsonMap json) {
    return ManualLock(
      active: json.boolOr('active', fallback: false),
      until: json.intOrNull('until'),
      setAt: json.intOrNull('setAt'),
    );
  }

  static const ManualLock inactive = ManualLock(active: false);

  final bool active;

  /// Instante de liberacao automatica, ou nulo para "ate desbloquear".
  final int? until;
  final int? setAt;

  bool isActiveAt(int nowMs) {
    final int? limit = until;
    return active && (limit == null || limit > nowMs);
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'active': active, 'until': until, 'setAt': setAt};
  }
}

/// Escopos que uma suspensao temporaria de regras pode cobrir.
enum SuspensionScope {
  dailyLimit('dailyLimit', 'Limite de tempo'),
  schedules('schedules', 'Horários e períodos de bloqueio'),
  appBlocks('appBlocks', 'Apps bloqueados');

  const SuspensionScope(this.code, this.label);

  final String code;
  final String label;

  static SuspensionScope? fromCode(String code) {
    for (final SuspensionScope scope in values) {
      if (scope.code == code) {
        return scope;
      }
    }
    return null;
  }
}

class Suspension with JsonEquality {
  const Suspension({required this.until, this.scopes = const <SuspensionScope>[], this.setAt});

  factory Suspension.fromJson(JsonMap json) {
    return Suspension(
      until: json.intOr('until', fallback: 0),
      scopes: json
          .strList('scopes')
          .map(SuspensionScope.fromCode)
          .whereType<SuspensionScope>()
          .toList(),
      setAt: json.intOrNull('setAt'),
    );
  }

  static const Suspension none = Suspension(until: 0);

  final int until;
  final List<SuspensionScope> scopes;
  final int? setAt;

  bool isActiveAt(int nowMs) => until > nowMs && scopes.isNotEmpty;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'until': until,
      'scopes': scopes.map((SuspensionScope scope) => scope.code).toList(),
      'setAt': setAt,
    };
  }
}

/// Comandos temporarios do responsavel. Alterados so pelas rotas de comando do servidor.
class PolicyOverrides with JsonEquality {
  const PolicyOverrides({
    this.extraTime = const <ExtraTimeGrant>[],
    this.manualLock = ManualLock.inactive,
    this.suspension = Suspension.none,
  });

  factory PolicyOverrides.fromJson(JsonMap json) {
    final JsonMap? lock = json.objOrNull('manualLock');
    final JsonMap? suspension = json.objOrNull('suspension');
    return PolicyOverrides(
      extraTime: json.objList('extraTime').map(ExtraTimeGrant.fromJson).toList(),
      manualLock: lock == null ? ManualLock.inactive : ManualLock.fromJson(lock),
      suspension: suspension == null ? Suspension.none : Suspension.fromJson(suspension),
    );
  }

  final List<ExtraTimeGrant> extraTime;
  final ManualLock manualLock;
  final Suspension suspension;

  /// Minutos extras concedidos para o dia da cota informado.
  int extraMinutesFor(String day) {
    return extraTime
        .where((ExtraTimeGrant grant) => grant.day == day)
        .fold<int>(0, (int total, ExtraTimeGrant grant) => total + grant.minutes);
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'extraTime': extraTime.map((ExtraTimeGrant grant) => grant.toJson()).toList(),
      'manualLock': manualLock.toJson(),
      'suspension': suspension.toJson(),
    };
  }
}

class Policy with JsonEquality {
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

  factory Policy.fromJson(JsonMap json) {
    final JsonMap? dailyLimit = json.objOrNull('dailyLimit');
    final JsonMap? allowedHours = json.objOrNull('allowedHours');
    final JsonMap? apps = json.objOrNull('apps');
    final JsonMap? web = json.objOrNull('web');
    final JsonMap? protection = json.objOrNull('protection');
    final JsonMap? overrides = json.objOrNull('overrides');
    return Policy(
      schema: json.intOr('schema', fallback: 1),
      timezone: json.strOrNull('timezone') ?? 'UTC',
      dailyLimit: dailyLimit == null ? DailyLimit.disabled : DailyLimit.fromJson(dailyLimit),
      allowedHours: allowedHours == null
          ? AllowedHours.disabled
          : AllowedHours.fromJson(allowedHours),
      blockPeriods: json.objList('blockPeriods').map(BlockPeriod.fromJson).toList(),
      apps: apps == null ? const AppsPolicy() : AppsPolicy.fromJson(apps),
      web: web == null ? const WebPolicy() : WebPolicy.fromJson(web),
      protection: protection == null
          ? const ProtectionPolicy()
          : ProtectionPolicy.fromJson(protection),
      overrides: overrides == null ? const PolicyOverrides() : PolicyOverrides.fromJson(overrides),
    );
  }

  final int schema;
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
  Map<String, Object?> toJson() => toJsonWith(includeOverrides: true);

  /// Forma JSON da politica. O envio para `PUT policy` omite `overrides`, que so mudam pelas
  /// rotas de comando.
  Map<String, Object?> toJsonWith({required bool includeOverrides}) {
    return <String, Object?>{
      'schema': schema,
      'timezone': timezone,
      'dailyLimit': dailyLimit.toJson(),
      'allowedHours': allowedHours.toJson(),
      'blockPeriods': blockPeriods.map((BlockPeriod period) => period.toJson()).toList(),
      'apps': apps.toJson(),
      'web': web.toJson(),
      'protection': protection.toJson(),
      if (includeOverrides) 'overrides': overrides.toJson(),
    };
  }
}
