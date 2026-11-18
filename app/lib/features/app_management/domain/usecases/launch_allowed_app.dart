import '../../../../core/result/result.dart';
import '../entities/allowed_app.dart';
import '../services/i_application_monitor.dart';

/// Abre um app sempre liberado. Devolve falso quando o sistema nao conseguiu abrir.
class LaunchAllowedApp {
  const LaunchAllowedApp(this._monitor);

  final IApplicationMonitor _monitor;

  Future<Result<bool>> call(AllowedApp app) => _monitor.launchApp(app.packageName);
}
