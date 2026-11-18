import '../../../../core/result/result.dart';
import '../entities/app_usage.dart';
import '../services/i_application_monitor.dart';

/// Uso de hoje por app neste aparelho, do mais usado para o menos usado.
class GetTodayAppUsage {
  const GetTodayAppUsage(this._monitor);

  final IApplicationMonitor _monitor;

  Future<Result<List<AppUsage>>> call() async {
    final Result<List<AppUsage>> usage = await _monitor.todayUsage();
    return usage.map(
      (List<AppUsage> list) =>
          <AppUsage>[...list]..sort((AppUsage a, AppUsage b) => b.ms.compareTo(a.ms)),
    );
  }
}
