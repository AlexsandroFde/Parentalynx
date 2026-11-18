import '../../../../core/json/json_reader.dart';

/// App do inventario no formato do protocolo (secao 5.1).
final class AppEntryDto {
  const AppEntryDto({
    required this.package,
    this.label,
    this.category,
    this.system,
    this.launchable,
    this.essential,
    this.versionName,
    this.installedAt,
    this.iconUrl,
    this.state,
    this.countsTowardLimit,
    this.dailyLimitMinutes,
    this.todayMs,
    this.weekMs,
    this.removed,
  });

  factory AppEntryDto.fromJson(JsonMap json) {
    bool? flag(String key) => json.has(key) ? json.boolean(key) : null;
    return AppEntryDto(
      package: json.str('package'),
      label: json.strOrNull('label'),
      category: json.strOrNull('category'),
      system: flag('system'),
      launchable: flag('launchable'),
      essential: flag('essential'),
      versionName: json.strOrNull('versionName'),
      installedAt: json.intOrNull('installedAt'),
      iconUrl: json.strOrNull('iconUrl'),
      state: json.strOrNull('state'),
      countsTowardLimit: flag('countsTowardLimit'),
      dailyLimitMinutes: json.intOrNull('dailyLimitMinutes'),
      todayMs: json.intOrNull('todayMs'),
      weekMs: json.intOrNull('weekMs'),
      removed: flag('removed'),
    );
  }

  final String package;
  final String? label;
  final String? category;
  final bool? system;
  final bool? launchable;
  final bool? essential;
  final String? versionName;
  final int? installedAt;

  /// Caminho relativo e autenticado do icone.
  final String? iconUrl;
  final String? state;
  final bool? countsTowardLimit;
  final int? dailyLimitMinutes;
  final int? todayMs;
  final int? weekMs;
  final bool? removed;
}

/// Resposta de `GET /v1/guardian/devices/:id/apps`.
final class DeviceAppsDto {
  const DeviceAppsDto({this.day, this.apps = const <AppEntryDto>[]});

  factory DeviceAppsDto.fromJson(JsonMap json) {
    return DeviceAppsDto(
      day: json.strOrNull('day'),
      apps: json.objList('apps').map(AppEntryDto.fromJson).toList(),
    );
  }

  final String? day;
  final List<AppEntryDto> apps;
}
