import '../../../device_policy/domain/entities/policy.dart';
import '../../domain/entities/app_entry.dart';
import '../dto/app_entry_dto.dart';

/// Converte o inventario do protocolo nas entidades, aplicando os valores padrao.
abstract final class AppEntryMapper {
  static DeviceApps deviceApps(DeviceAppsDto dto) {
    return DeviceApps(day: dto.day ?? '', apps: dto.apps.map(entry).toList());
  }

  static AppEntry entry(AppEntryDto dto) {
    final String? label = dto.label;
    return AppEntry(
      package: dto.package,
      label: label == null || label.trim().isEmpty ? dto.package : label,
      category: AppCategory.parse(dto.category),
      system: dto.system ?? false,
      launchable: dto.launchable ?? true,
      essential: dto.essential ?? false,
      versionName: dto.versionName,
      installedAt: dto.installedAt,
      iconPath: dto.iconUrl,
      state: switch (dto.state) {
        'blocked' => AppRuleState.blocked,
        'exception' => AppRuleState.exception,
        _ => AppRuleState.allowed,
      },
      countsTowardLimit: dto.countsTowardLimit ?? false,
      dailyLimitMinutes: dto.dailyLimitMinutes,
      todayMs: dto.todayMs ?? 0,
      weekMs: dto.weekMs ?? 0,
      removed: dto.removed ?? false,
    );
  }
}
