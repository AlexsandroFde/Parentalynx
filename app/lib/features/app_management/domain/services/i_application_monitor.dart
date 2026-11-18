import 'dart:typed_data';

import '../../../../core/result/result.dart';
import '../entities/allowed_app.dart';
import '../entities/app_usage.dart';

/// Apps deste aparelho vistos pelo agente nativo (modo crianca): uso de hoje, apps sempre
/// liberados, icones e abertura de um app.
///
/// A contagem de uso e o bloqueio sao feitos pelo agente, com ou sem a interface aberta.
abstract interface class IApplicationMonitor {
  Future<Result<List<AppUsage>>> todayUsage();

  /// Apps que continuam disponiveis durante um bloqueio geral.
  Future<Result<List<AllowedApp>>> exceptionApps();

  /// Icone do app em PNG, ou nulo quando nao ha.
  Future<Result<Uint8List?>> appIcon(String packageName);

  /// Abre um app instalado. Falso quando nao foi possivel abrir.
  Future<Result<bool>> launchApp(String packageName);
}
