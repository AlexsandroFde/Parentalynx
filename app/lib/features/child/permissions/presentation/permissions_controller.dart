import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../agent/data/child_device_repository.dart';
import '../../agent/domain/child_models.dart';
import '../../shared/no_retry.dart';
import '../domain/permission_steps.dart';

/// Estado das permissoes para a tela.
class PermissionsView {
  const PermissionsView({required this.facts, required this.manufacturer});

  final PermissionFacts facts;
  final String manufacturer;

  List<PermissionStep> get steps => buildPermissionSteps(facts, manufacturer: manufacturer);

  ManagementLevel get management => facts.management;

  bool get requiredGranted => requiredPermissionsGranted(steps);
}

/// O que aconteceu ao tentar abrir a tela de uma permissao.
enum PermissionActionResult {
  /// A tela do sistema foi aberta. O estado e reconsultado quando o app voltar.
  opened,

  /// A permissao foi concedida na hora (dialogo do sistema).
  granted,

  /// Nao ha tela conhecida para este fabricante. Foi aberta a tela de informacoes do app.
  fallbackToAppDetails,
}

final permissionsControllerProvider =
    AsyncNotifierProvider.autoDispose<PermissionsController, PermissionsView>(
      PermissionsController.new,
      retry: noRetry,
    );

class PermissionsController extends AsyncNotifier<PermissionsView> {
  @override
  Future<PermissionsView> build() async {
    final ChildDeviceRepository device = ref.read(childDeviceRepositoryProvider);
    final PermissionFacts facts = await device.permissions();
    String manufacturer = '';
    try {
      manufacturer = (await device.deviceInfo()).manufacturer;
    } on AppFailure {
      // Sem o fabricante, so o passo de inicio automatico deixa de aparecer.
    }
    return PermissionsView(facts: facts, manufacturer: manufacturer);
  }

  /// Reconsulta o estado das permissoes (ao voltar das configuracoes do sistema).
  Future<void> refresh() async {
    final PermissionsView? current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    try {
      final PermissionFacts facts = await ref.read(childDeviceRepositoryProvider).permissions();
      if (ref.mounted) {
        state = AsyncData<PermissionsView>(
          PermissionsView(facts: facts, manufacturer: current.manufacturer),
        );
      }
    } on AppFailure {
      // Mantem o estado anterior. A proxima volta ao app tenta de novo.
    }
  }

  /// Abre a tela do sistema (ou o dialogo) da permissao escolhida.
  Future<PermissionActionResult> open(PermissionKind kind) async {
    final ChildDeviceRepository device = ref.read(childDeviceRepositoryProvider);
    switch (kind) {
      case PermissionKind.usageAccess:
        await device.openUsageAccessSettings();
      case PermissionKind.accessibility:
        await device.openAccessibilitySettings();
      case PermissionKind.notifications:
        final bool granted = await device.requestNotificationPermission();
        if (granted) {
          await refresh();
          return PermissionActionResult.granted;
        }
        // Depois de uma recusa o sistema nao mostra mais o dialogo: abre as configuracoes.
        await device.openNotificationSettings();
      case PermissionKind.batteryOptimization:
        await device.requestIgnoreBatteryOptimizations();
      case PermissionKind.overlay:
        await device.openOverlaySettings();
      case PermissionKind.exactAlarms:
        await device.openExactAlarmSettings();
      case PermissionKind.deviceAdmin:
        await device.requestDeviceAdmin();
      case PermissionKind.autostart:
        final bool opened = await device.openManufacturerAutostartSettings();
        if (!opened) {
          await device.openAppDetailsSettings();
          return PermissionActionResult.fallbackToAppDetails;
        }
    }
    return PermissionActionResult.opened;
  }

  /// Abre a tela de informacoes do app, onde se liberam as "configuracoes restritas".
  Future<void> openAppDetails() => ref.read(childDeviceRepositoryProvider).openAppDetailsSettings();
}
