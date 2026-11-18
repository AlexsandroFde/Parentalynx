import '../../../../core/json/json_reader.dart';

// Objetos de transferencia da politica no formato do protocolo (secao 4.2).
//
// Espelham o JSON: campos ausentes ficam nulos e codigos chegam como texto. A leitura nao
// aplica padroes; quem aplica e o `PolicyMapper`, para que um app antigo consiga ler uma
// politica gravada por uma versao mais nova (secao ausente assume o padrao).

final class DailyLimitDto {
  const DailyLimitDto({
    this.enabled,
    this.minutes,
    this.perWeekday,
    this.resetTime,
    this.warnAtMinutes,
  });

  factory DailyLimitDto.fromJson(JsonMap json) {
    final JsonMap? weekdays = json.objOrNull('perWeekday');
    return DailyLimitDto(
      enabled: _flag(json, 'enabled'),
      minutes: json.intOrNull('minutes'),
      perWeekday: weekdays == null
          ? null
          : <String, int>{for (final String key in weekdays.keys) key: weekdays.integer(key)},
      resetTime: json.strOrNull('resetTime'),
      warnAtMinutes: json.has('warnAtMinutes') ? json.intList('warnAtMinutes') : null,
    );
  }

  final bool? enabled;
  final int? minutes;

  /// Dia da semana ISO como texto (`"1"` = segunda) para minutos.
  final Map<String, int>? perWeekday;
  final String? resetTime;
  final List<int>? warnAtMinutes;

  Map<String, Object?> toJson() {
    final Map<String, int>? weekdays = perWeekday;
    return <String, Object?>{
      'enabled': enabled,
      'minutes': minutes,
      if (weekdays != null && weekdays.isNotEmpty) 'perWeekday': weekdays,
      'resetTime': resetTime,
      'warnAtMinutes': warnAtMinutes,
    };
  }
}

final class TimeWindowDto {
  const TimeWindowDto({required this.days, required this.start, required this.end});

  factory TimeWindowDto.fromJson(JsonMap json) {
    return TimeWindowDto(
      days: json.intList('days'),
      start: json.str('start'),
      end: json.str('end'),
    );
  }

  final List<int> days;
  final String start;
  final String end;

  Map<String, Object?> toJson() => <String, Object?>{'days': days, 'start': start, 'end': end};
}

final class AllowedHoursDto {
  const AllowedHoursDto({this.enabled, this.windows = const <TimeWindowDto>[]});

  factory AllowedHoursDto.fromJson(JsonMap json) {
    return AllowedHoursDto(
      enabled: _flag(json, 'enabled'),
      windows: json.objList('windows').map(TimeWindowDto.fromJson).toList(),
    );
  }

  final bool? enabled;
  final List<TimeWindowDto> windows;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'enabled': enabled,
      'windows': windows.map((TimeWindowDto window) => window.toJson()).toList(),
    };
  }
}

final class BlockPeriodDto {
  const BlockPeriodDto({
    required this.id,
    this.label,
    this.enabled,
    this.kind,
    this.days,
    this.start,
    this.end,
    this.startAt,
    this.endAt,
  });

  factory BlockPeriodDto.fromJson(JsonMap json) {
    return BlockPeriodDto(
      id: json.str('id'),
      label: json.strOrNull('label'),
      enabled: _flag(json, 'enabled'),
      kind: json.strOrNull('kind'),
      days: json.has('days') ? json.intList('days') : null,
      start: json.strOrNull('start'),
      end: json.strOrNull('end'),
      startAt: json.intOrNull('startAt'),
      endAt: json.intOrNull('endAt'),
    );
  }

  final String id;
  final String? label;
  final bool? enabled;

  /// `weekly` ou `once`.
  final String? kind;
  final List<int>? days;
  final String? start;
  final String? end;
  final int? startAt;
  final int? endAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'label': label,
      'enabled': enabled,
      'kind': kind,
      if (kind == 'weekly') ...<String, Object?>{'days': days, 'start': start, 'end': end},
      if (kind == 'once') ...<String, Object?>{'startAt': startAt, 'endAt': endAt},
    };
  }
}

final class AppRuleDto {
  const AppRuleDto({this.state, this.countsTowardLimit, this.dailyLimitMinutes});

  factory AppRuleDto.fromJson(JsonMap json) {
    return AppRuleDto(
      state: json.strOrNull('state'),
      countsTowardLimit: _flag(json, 'countsTowardLimit'),
      dailyLimitMinutes: json.intOrNull('dailyLimitMinutes'),
    );
  }

  /// `allowed`, `blocked` ou `exception`.
  final String? state;
  final bool? countsTowardLimit;
  final int? dailyLimitMinutes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'state': state,
      'countsTowardLimit': ?countsTowardLimit,
      'dailyLimitMinutes': ?dailyLimitMinutes,
    };
  }
}

final class AppsPolicyDto {
  const AppsPolicyDto({this.defaultForNewApps, this.rules = const <String, AppRuleDto>{}});

  factory AppsPolicyDto.fromJson(JsonMap json) {
    final JsonMap? rules = json.objOrNull('rules');
    return AppsPolicyDto(
      defaultForNewApps: json.strOrNull('defaultForNewApps'),
      rules: <String, AppRuleDto>{
        if (rules != null)
          for (final String package in rules.keys) package: AppRuleDto.fromJson(rules.obj(package)),
      },
    );
  }

  final String? defaultForNewApps;
  final Map<String, AppRuleDto> rules;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'defaultForNewApps': defaultForNewApps,
      'rules': <String, Object?>{
        for (final MapEntry<String, AppRuleDto> entry in rules.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }
}

final class WebPolicyDto {
  const WebPolicyDto({
    this.managedBrowser,
    this.logHistory,
    this.safeDns,
    this.safeSearch,
    this.mode,
    this.blockedDomains = const <String>[],
    this.allowedDomains = const <String>[],
    this.blockedCategories = const <String>[],
  });

  factory WebPolicyDto.fromJson(JsonMap json) {
    return WebPolicyDto(
      managedBrowser: _flag(json, 'managedBrowser'),
      logHistory: _flag(json, 'logHistory'),
      safeDns: _flag(json, 'safeDns'),
      safeSearch: _flag(json, 'safeSearch'),
      mode: json.strOrNull('mode'),
      blockedDomains: json.strList('blockedDomains'),
      allowedDomains: json.strList('allowedDomains'),
      blockedCategories: json.strList('blockedCategories'),
    );
  }

  final bool? managedBrowser;
  final bool? logHistory;
  final bool? safeDns;
  final bool? safeSearch;

  /// `blocklist` ou `allowlist`.
  final String? mode;
  final List<String> blockedDomains;
  final List<String> allowedDomains;
  final List<String> blockedCategories;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'managedBrowser': managedBrowser,
      'logHistory': logHistory,
      'safeDns': safeDns,
      'safeSearch': safeSearch,
      'mode': mode,
      'blockedDomains': blockedDomains,
      'allowedDomains': allowedDomains,
      'blockedCategories': blockedCategories,
    };
  }
}

final class ProtectionPolicyDto {
  const ProtectionPolicyDto({
    this.lockOnTamper,
    this.blockUninstall,
    this.blockSafeBoot,
    this.blockFactoryReset,
    this.blockDateTimeChange,
    this.blockAddUser,
    this.blockUnknownSources,
    this.blockUsbDebugging,
  });

  factory ProtectionPolicyDto.fromJson(JsonMap json) {
    return ProtectionPolicyDto(
      lockOnTamper: _flag(json, 'lockOnTamper'),
      blockUninstall: _flag(json, 'blockUninstall'),
      blockSafeBoot: _flag(json, 'blockSafeBoot'),
      blockFactoryReset: _flag(json, 'blockFactoryReset'),
      blockDateTimeChange: _flag(json, 'blockDateTimeChange'),
      blockAddUser: _flag(json, 'blockAddUser'),
      blockUnknownSources: _flag(json, 'blockUnknownSources'),
      blockUsbDebugging: _flag(json, 'blockUsbDebugging'),
    );
  }

  final bool? lockOnTamper;
  final bool? blockUninstall;
  final bool? blockSafeBoot;
  final bool? blockFactoryReset;
  final bool? blockDateTimeChange;
  final bool? blockAddUser;
  final bool? blockUnknownSources;
  final bool? blockUsbDebugging;

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

final class ExtraTimeGrantDto {
  const ExtraTimeGrantDto({
    required this.id,
    required this.day,
    required this.minutes,
    this.grantedAt,
  });

  factory ExtraTimeGrantDto.fromJson(JsonMap json) {
    return ExtraTimeGrantDto(
      id: json.str('id'),
      day: json.str('day'),
      minutes: json.integer('minutes'),
      grantedAt: json.intOrNull('grantedAt'),
    );
  }

  final String id;
  final String day;
  final int minutes;
  final int? grantedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{'id': id, 'day': day, 'minutes': minutes, 'grantedAt': grantedAt};
  }
}

final class ManualLockDto {
  const ManualLockDto({this.active, this.until, this.setAt});

  factory ManualLockDto.fromJson(JsonMap json) {
    return ManualLockDto(
      active: _flag(json, 'active'),
      until: json.intOrNull('until'),
      setAt: json.intOrNull('setAt'),
    );
  }

  final bool? active;
  final int? until;
  final int? setAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{'active': active, 'until': until, 'setAt': setAt};
  }
}

final class SuspensionDto {
  const SuspensionDto({this.until, this.scopes = const <String>[], this.setAt});

  factory SuspensionDto.fromJson(JsonMap json) {
    return SuspensionDto(
      until: json.intOrNull('until'),
      scopes: json.strList('scopes'),
      setAt: json.intOrNull('setAt'),
    );
  }

  final int? until;
  final List<String> scopes;
  final int? setAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{'until': until, 'scopes': scopes, 'setAt': setAt};
  }
}

final class PolicyOverridesDto {
  const PolicyOverridesDto({
    this.extraTime = const <ExtraTimeGrantDto>[],
    this.manualLock,
    this.suspension,
  });

  factory PolicyOverridesDto.fromJson(JsonMap json) {
    final JsonMap? lock = json.objOrNull('manualLock');
    final JsonMap? suspension = json.objOrNull('suspension');
    return PolicyOverridesDto(
      extraTime: json.objList('extraTime').map(ExtraTimeGrantDto.fromJson).toList(),
      manualLock: lock == null ? null : ManualLockDto.fromJson(lock),
      suspension: suspension == null ? null : SuspensionDto.fromJson(suspension),
    );
  }

  final List<ExtraTimeGrantDto> extraTime;
  final ManualLockDto? manualLock;
  final SuspensionDto? suspension;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'extraTime': extraTime.map((ExtraTimeGrantDto grant) => grant.toJson()).toList(),
      'manualLock': manualLock?.toJson(),
      'suspension': suspension?.toJson(),
    };
  }
}

final class PolicyDto {
  const PolicyDto({
    this.schema,
    this.timezone,
    this.dailyLimit,
    this.allowedHours,
    this.blockPeriods = const <BlockPeriodDto>[],
    this.apps,
    this.web,
    this.protection,
    this.overrides,
  });

  factory PolicyDto.fromJson(JsonMap json) {
    final JsonMap? dailyLimit = json.objOrNull('dailyLimit');
    final JsonMap? allowedHours = json.objOrNull('allowedHours');
    final JsonMap? apps = json.objOrNull('apps');
    final JsonMap? web = json.objOrNull('web');
    final JsonMap? protection = json.objOrNull('protection');
    final JsonMap? overrides = json.objOrNull('overrides');
    return PolicyDto(
      schema: json.intOrNull('schema'),
      timezone: json.strOrNull('timezone'),
      dailyLimit: dailyLimit == null ? null : DailyLimitDto.fromJson(dailyLimit),
      allowedHours: allowedHours == null ? null : AllowedHoursDto.fromJson(allowedHours),
      blockPeriods: json.objList('blockPeriods').map(BlockPeriodDto.fromJson).toList(),
      apps: apps == null ? null : AppsPolicyDto.fromJson(apps),
      web: web == null ? null : WebPolicyDto.fromJson(web),
      protection: protection == null ? null : ProtectionPolicyDto.fromJson(protection),
      overrides: overrides == null ? null : PolicyOverridesDto.fromJson(overrides),
    );
  }

  final int? schema;
  final String? timezone;
  final DailyLimitDto? dailyLimit;
  final AllowedHoursDto? allowedHours;
  final List<BlockPeriodDto> blockPeriods;
  final AppsPolicyDto? apps;
  final WebPolicyDto? web;
  final ProtectionPolicyDto? protection;
  final PolicyOverridesDto? overrides;

  /// Forma JSON. O envio para `PUT policy` omite `overrides`, que so mudam pelas rotas de
  /// comando.
  Map<String, Object?> toJson({bool includeOverrides = true}) {
    return <String, Object?>{
      'schema': schema,
      'timezone': timezone,
      'dailyLimit': dailyLimit?.toJson(),
      'allowedHours': allowedHours?.toJson(),
      'blockPeriods': blockPeriods.map((BlockPeriodDto period) => period.toJson()).toList(),
      'apps': apps?.toJson(),
      'web': web?.toJson(),
      'protection': protection?.toJson(),
      if (includeOverrides) 'overrides': overrides?.toJson(),
    };
  }
}

/// Politica com a versao do servidor (`policyVersion` e `policy` na mesma resposta).
final class VersionedPolicyDto {
  const VersionedPolicyDto({required this.version, required this.policy});

  factory VersionedPolicyDto.fromJson(JsonMap json) {
    return VersionedPolicyDto(
      version: json.integer('policyVersion'),
      policy: PolicyDto.fromJson(json.obj('policy')),
    );
  }

  final int version;
  final PolicyDto policy;
}

bool? _flag(JsonMap json, String key) => json.has(key) ? json.boolean(key) : null;
