import '../../../../core/result/result.dart';
import '../entities/allowed_app.dart';
import '../services/i_application_monitor.dart';

/// Apps que a crianca pode abrir mesmo com o tempo esgotado ou em horario de pausa.
class GetAlwaysAllowedApps {
  const GetAlwaysAllowedApps(this._monitor);

  final IApplicationMonitor _monitor;

  Future<Result<List<AllowedApp>>> call() => _monitor.exceptionApps();
}
