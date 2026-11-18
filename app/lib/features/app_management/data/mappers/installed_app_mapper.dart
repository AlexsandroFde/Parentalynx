import '../../../../core/platform/native_api.g.dart';
import '../../domain/entities/allowed_app.dart';
import '../../domain/entities/app_usage.dart';

/// Converte os apps informados pelo agente nativo nas entidades do modo crianca.
abstract final class InstalledAppMapper {
  static AppUsage usage(UsageEntry entry) {
    return AppUsage(
      packageName: entry.packageName,
      label: entry.label,
      ms: entry.ms,
      opens: entry.opens,
    );
  }

  static AllowedApp allowed(NativeAppInfo info) {
    return AllowedApp(packageName: info.packageName, label: info.label, category: info.category);
  }
}
