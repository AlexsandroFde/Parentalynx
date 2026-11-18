import 'dart:typed_data';

import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/allowed_app.dart';
import '../../domain/entities/app_usage.dart';
import '../../domain/services/i_application_monitor.dart';
import '../mappers/installed_app_mapper.dart';

/// Apps deste aparelho pela ponte com o agente nativo ([ChildAgentApi]).
class NativeApplicationMonitor implements IApplicationMonitor {
  const NativeApplicationMonitor(this._api);

  final ChildAgentApi _api;

  @override
  Future<Result<List<AppUsage>>> todayUsage() async {
    final Result<List<UsageEntry>> entries = await callNative<List<UsageEntry>>(_api.getTodayUsage);
    return entries.map((List<UsageEntry> list) => list.map(InstalledAppMapper.usage).toList());
  }

  @override
  Future<Result<List<AllowedApp>>> exceptionApps() async {
    final Result<List<NativeAppInfo>> apps = await callNative<List<NativeAppInfo>>(
      _api.getExceptionApps,
    );
    return apps.map((List<NativeAppInfo> list) => list.map(InstalledAppMapper.allowed).toList());
  }

  @override
  Future<Result<Uint8List?>> appIcon(String packageName) {
    return callNative<Uint8List?>(() => _api.getAppIcon(packageName));
  }

  @override
  Future<Result<bool>> launchApp(String packageName) {
    return callNative<bool>(() => _api.launchApp(packageName));
  }
}
