import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';

/// Travas do sistema que o Android aplica no modo dispositivo gerenciado (Device Owner).
enum SystemLock {
  uninstall,
  safeBoot,
  factoryReset,
  dateTimeChange,
  addUser,
  unknownSources,
  usbDebugging;

  /// So o modo dispositivo gerenciado consegue aplicar as travas do sistema.
  static bool availableIn(DeviceManagementMode mode) {
    return mode == DeviceManagementMode.deviceOwner;
  }

  bool valueIn(ProtectionPolicy protection) {
    return switch (this) {
      SystemLock.uninstall => protection.blockUninstall,
      SystemLock.safeBoot => protection.blockSafeBoot,
      SystemLock.factoryReset => protection.blockFactoryReset,
      SystemLock.dateTimeChange => protection.blockDateTimeChange,
      SystemLock.addUser => protection.blockAddUser,
      SystemLock.unknownSources => protection.blockUnknownSources,
      SystemLock.usbDebugging => protection.blockUsbDebugging,
    };
  }

  ProtectionPolicy apply(ProtectionPolicy protection, bool enabled) {
    return switch (this) {
      SystemLock.uninstall => protection.copyWith(blockUninstall: enabled),
      SystemLock.safeBoot => protection.copyWith(blockSafeBoot: enabled),
      SystemLock.factoryReset => protection.copyWith(blockFactoryReset: enabled),
      SystemLock.dateTimeChange => protection.copyWith(blockDateTimeChange: enabled),
      SystemLock.addUser => protection.copyWith(blockAddUser: enabled),
      SystemLock.unknownSources => protection.copyWith(blockUnknownSources: enabled),
      SystemLock.usbDebugging => protection.copyWith(blockUsbDebugging: enabled),
    };
  }

  /// Quantas travas estao ligadas.
  static int countEnabled(ProtectionPolicy protection) {
    return values.where((SystemLock lock) => lock.valueIn(protection)).length;
  }
}
