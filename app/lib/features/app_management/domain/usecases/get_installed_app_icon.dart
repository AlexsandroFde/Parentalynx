import 'dart:typed_data';

import '../../../../core/result/result.dart';
import '../services/i_application_monitor.dart';

/// Icone de um app instalado neste aparelho, em PNG.
class GetInstalledAppIcon {
  const GetInstalledAppIcon(this._monitor);

  final IApplicationMonitor _monitor;

  Future<Result<Uint8List?>> call(String packageName) => _monitor.appIcon(packageName);
}
