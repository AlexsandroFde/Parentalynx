import '../../../../core/json/json_reader.dart';
import '../../domain/entities/policy.dart';
import '../../domain/entities/versioned_policy.dart';
import '../dto/policy_dto.dart';

/// Converte a politica do protocolo nas entidades e de volta.
///
/// Leitura tolerante: secao ausente assume o padrao do protocolo. Horario fora do formato
/// vira [JsonFormatException], tratada como resposta inesperada do servidor.
abstract final class PolicyMapper {
  // Leitura.

  static VersionedPolicy versioned(VersionedPolicyDto dto) {
    return VersionedPolicy(version: dto.version, policy: policy(dto.policy));
  }

  static Policy policy(PolicyDto dto) {
    final DailyLimitDto? dailyLimit = dto.dailyLimit;
    final AllowedHoursDto? allowedHours = dto.allowedHours;
    final AppsPolicyDto? apps = dto.apps;
    final WebPolicyDto? web = dto.web;
    final ProtectionPolicyDto? protection = dto.protection;
    final PolicyOverridesDto? overrides = dto.overrides;
    return Policy(
      schema: dto.schema ?? 1,
      timezone: dto.timezone ?? 'UTC',
      dailyLimit: dailyLimit == null ? DailyLimit.disabled : _dailyLimit(dailyLimit),
      allowedHours: allowedHours == null ? AllowedHours.disabled : _allowedHours(allowedHours),
      blockPeriods: dto.blockPeriods.map(_blockPeriod).toList(),
      apps: apps == null ? const AppsPolicy() : _apps(apps),
      web: web == null ? const WebPolicy() : _web(web),
      protection: protection == null ? const ProtectionPolicy() : _protection(protection),
      overrides: overrides == null ? const PolicyOverrides() : _overrides(overrides),
    );
  }

  static DailyLimit _dailyLimit(DailyLimitDto dto) {
    final Map<String, int> weekdays = dto.perWeekday ?? const <String, int>{};
    return DailyLimit(
      enabled: dto.enabled ?? false,
      minutes: dto.minutes ?? DailyLimit.defaultMinutes,
      perWeekday: <int, int>{
        for (final MapEntry<String, int> entry in weekdays.entries)
          if (int.tryParse(entry.key) case final int day) day: entry.value,
      },
      resetTime: _time(dto.resetTime ?? '00:00'),
      warnAtMinutes: dto.warnAtMinutes ?? DailyLimit.defaultWarnings,
    );
  }

  static AllowedHours _allowedHours(AllowedHoursDto dto) {
    return AllowedHours(
      enabled: dto.enabled ?? false,
      windows: dto.windows
          .map(
            (TimeWindowDto window) =>
                TimeWindow(days: window.days, start: _time(window.start), end: _time(window.end)),
          )
          .toList(),
    );
  }

  static BlockPeriod _blockPeriod(BlockPeriodDto dto) {
    if (dto.kind == 'once') {
      return BlockPeriod.once(
        id: dto.id,
        label: dto.label ?? '',
        startAt: _required(dto.startAt, 'startAt'),
        endAt: _required(dto.endAt, 'endAt'),
        enabled: dto.enabled ?? true,
      );
    }
    return BlockPeriod.weekly(
      id: dto.id,
      label: dto.label ?? '',
      days: dto.days ?? const <int>[],
      start: _time(_required(dto.start, 'start')),
      end: _time(_required(dto.end, 'end')),
      enabled: dto.enabled ?? true,
    );
  }

  static AppsPolicy _apps(AppsPolicyDto dto) {
    return AppsPolicy(
      defaultForNewApps: dto.defaultForNewApps == 'blocked'
          ? NewAppDefault.blocked
          : NewAppDefault.allowed,
      rules: <String, AppRule>{
        for (final MapEntry<String, AppRuleDto> entry in dto.rules.entries)
          entry.key: AppRule(
            state: appRuleState(entry.value.state),
            countsTowardLimit: entry.value.countsTowardLimit ?? false,
            dailyLimitMinutes: entry.value.dailyLimitMinutes,
          ),
      },
    );
  }

  static WebPolicy _web(WebPolicyDto dto) {
    return WebPolicy(
      managedBrowser: dto.managedBrowser ?? true,
      logHistory: dto.logHistory ?? true,
      safeDns: dto.safeDns ?? true,
      safeSearch: dto.safeSearch ?? true,
      mode: dto.mode == 'allowlist' ? WebMode.allowlist : WebMode.blocklist,
      blockedDomains: dto.blockedDomains,
      allowedDomains: dto.allowedDomains,
      blockedCategories: dto.blockedCategories,
    );
  }

  static ProtectionPolicy _protection(ProtectionPolicyDto dto) {
    return ProtectionPolicy(
      lockOnTamper: dto.lockOnTamper ?? false,
      blockUninstall: dto.blockUninstall ?? true,
      blockSafeBoot: dto.blockSafeBoot ?? true,
      blockFactoryReset: dto.blockFactoryReset ?? true,
      blockDateTimeChange: dto.blockDateTimeChange ?? true,
      blockAddUser: dto.blockAddUser ?? true,
      blockUnknownSources: dto.blockUnknownSources ?? false,
      blockUsbDebugging: dto.blockUsbDebugging ?? false,
    );
  }

  static PolicyOverrides _overrides(PolicyOverridesDto dto) {
    final ManualLockDto? lock = dto.manualLock;
    final SuspensionDto? suspension = dto.suspension;
    return PolicyOverrides(
      extraTime: dto.extraTime
          .map(
            (ExtraTimeGrantDto grant) => ExtraTimeGrant(
              id: grant.id,
              day: grant.day,
              minutes: grant.minutes,
              grantedAt: grant.grantedAt ?? 0,
            ),
          )
          .toList(),
      manualLock: lock == null
          ? ManualLock.inactive
          : ManualLock(active: lock.active ?? false, until: lock.until, setAt: lock.setAt),
      suspension: suspension == null
          ? Suspension.none
          : Suspension(
              until: suspension.until ?? 0,
              scopes: suspension.scopes.map(suspensionScope).whereType<SuspensionScope>().toList(),
              setAt: suspension.setAt,
            ),
    );
  }

  /// Estado de regra de app pelo codigo do protocolo. Codigo desconhecido vale "permitido".
  static AppRuleState appRuleState(String? code) {
    return switch (code) {
      'blocked' => AppRuleState.blocked,
      'exception' => AppRuleState.exception,
      _ => AppRuleState.allowed,
    };
  }

  /// Escopo de suspensao pelo codigo do protocolo. Codigo desconhecido e ignorado.
  static SuspensionScope? suspensionScope(String code) {
    return switch (code) {
      'dailyLimit' => SuspensionScope.dailyLimit,
      'schedules' => SuspensionScope.schedules,
      'appBlocks' => SuspensionScope.appBlocks,
      _ => null,
    };
  }

  static String suspensionScopeCode(SuspensionScope scope) {
    return switch (scope) {
      SuspensionScope.dailyLimit => 'dailyLimit',
      SuspensionScope.schedules => 'schedules',
      SuspensionScope.appBlocks => 'appBlocks',
    };
  }

  static LocalTime _time(String text) {
    try {
      return LocalTime.parse(text);
    } on FormatException catch (error) {
      throw JsonFormatException(error.message);
    }
  }

  static T _required<T extends Object>(T? value, String field) {
    if (value == null) {
      throw JsonFormatException('Campo obrigatorio ausente: $field');
    }
    return value;
  }

  // Escrita.

  static PolicyDto toDto(Policy policy) {
    return PolicyDto(
      schema: policy.schema,
      timezone: policy.timezone,
      dailyLimit: _dailyLimitDto(policy.dailyLimit),
      allowedHours: AllowedHoursDto(
        enabled: policy.allowedHours.enabled,
        windows: policy.allowedHours.windows
            .map(
              (TimeWindow window) => TimeWindowDto(
                days: window.days,
                start: window.start.toString(),
                end: window.end.toString(),
              ),
            )
            .toList(),
      ),
      blockPeriods: policy.blockPeriods.map(_blockPeriodDto).toList(),
      apps: AppsPolicyDto(
        defaultForNewApps: policy.apps.defaultForNewApps.name,
        rules: <String, AppRuleDto>{
          for (final MapEntry<String, AppRule> entry in policy.apps.rules.entries)
            entry.key: AppRuleDto(
              state: entry.value.state.name,
              countsTowardLimit: entry.value.state == AppRuleState.exception
                  ? entry.value.countsTowardLimit
                  : null,
              dailyLimitMinutes: entry.value.dailyLimitMinutes,
            ),
        },
      ),
      web: WebPolicyDto(
        managedBrowser: policy.web.managedBrowser,
        logHistory: policy.web.logHistory,
        safeDns: policy.web.safeDns,
        safeSearch: policy.web.safeSearch,
        mode: policy.web.mode.name,
        blockedDomains: policy.web.blockedDomains,
        allowedDomains: policy.web.allowedDomains,
        blockedCategories: policy.web.blockedCategories,
      ),
      protection: ProtectionPolicyDto(
        lockOnTamper: policy.protection.lockOnTamper,
        blockUninstall: policy.protection.blockUninstall,
        blockSafeBoot: policy.protection.blockSafeBoot,
        blockFactoryReset: policy.protection.blockFactoryReset,
        blockDateTimeChange: policy.protection.blockDateTimeChange,
        blockAddUser: policy.protection.blockAddUser,
        blockUnknownSources: policy.protection.blockUnknownSources,
        blockUsbDebugging: policy.protection.blockUsbDebugging,
      ),
      overrides: PolicyOverridesDto(
        extraTime: policy.overrides.extraTime
            .map(
              (ExtraTimeGrant grant) => ExtraTimeGrantDto(
                id: grant.id,
                day: grant.day,
                minutes: grant.minutes,
                grantedAt: grant.grantedAt,
              ),
            )
            .toList(),
        manualLock: ManualLockDto(
          active: policy.overrides.manualLock.active,
          until: policy.overrides.manualLock.until,
          setAt: policy.overrides.manualLock.setAt,
        ),
        suspension: SuspensionDto(
          until: policy.overrides.suspension.until,
          scopes: policy.overrides.suspension.scopes.map(suspensionScopeCode).toList(),
          setAt: policy.overrides.suspension.setAt,
        ),
      ),
    );
  }

  static DailyLimitDto _dailyLimitDto(DailyLimit limit) {
    return DailyLimitDto(
      enabled: limit.enabled,
      minutes: limit.minutes,
      perWeekday: <String, int>{
        for (final MapEntry<int, int> entry in limit.perWeekday.entries)
          '${entry.key}': entry.value,
      },
      resetTime: limit.resetTime.toString(),
      warnAtMinutes: limit.warnAtMinutes,
    );
  }

  static BlockPeriodDto _blockPeriodDto(BlockPeriod period) {
    return BlockPeriodDto(
      id: period.id,
      label: period.label,
      enabled: period.enabled,
      kind: period.kind.name,
      days: period.days,
      start: period.start?.toString(),
      end: period.end?.toString(),
      startAt: period.startAt,
      endAt: period.endAt,
    );
  }
}
