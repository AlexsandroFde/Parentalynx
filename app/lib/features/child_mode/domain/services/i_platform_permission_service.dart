import '../../../../core/result/result.dart';
import '../entities/permission_facts.dart';

/// Permissoes especiais do Android de que o controle depende e as telas do sistema em que
/// cada uma e concedida.
abstract interface class IPlatformPermissionService {
  Future<Result<PermissionFacts>> permissions();

  Future<Result<void>> openUsageAccessSettings();

  Future<Result<void>> openAccessibilitySettings();

  Future<Result<void>> openOverlaySettings();

  Future<Result<void>> requestIgnoreBatteryOptimizations();

  Future<Result<void>> openExactAlarmSettings();

  Future<Result<void>> openNotificationSettings();

  /// Mostra o dialogo do sistema. Verdadeiro se a permissao ficou concedida.
  Future<Result<bool>> requestNotificationPermission();

  /// Tela de informacoes do app (configuracoes restritas, inicio automatico).
  Future<Result<void>> openAppDetailsSettings();

  /// Falso quando nao ha tela de inicio automatico conhecida para o fabricante.
  Future<Result<bool>> openManufacturerAutostartSettings();
}
