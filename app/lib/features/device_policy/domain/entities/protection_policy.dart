import 'package:equatable/equatable.dart';

/// Protecoes contra desativacao do controle (protocolo, secao 4.2, `protection`).
final class ProtectionPolicy extends Equatable {
  const ProtectionPolicy({
    this.lockOnTamper = false,
    this.blockUninstall = true,
    this.blockSafeBoot = true,
    this.blockFactoryReset = true,
    this.blockDateTimeChange = true,
    this.blockAddUser = true,
    this.blockUnknownSources = false,
    this.blockUsbDebugging = false,
  });

  final bool lockOnTamper;

  // As chaves abaixo so tem efeito no modo Device Owner.
  final bool blockUninstall;
  final bool blockSafeBoot;
  final bool blockFactoryReset;
  final bool blockDateTimeChange;
  final bool blockAddUser;
  final bool blockUnknownSources;
  final bool blockUsbDebugging;

  ProtectionPolicy copyWith({
    bool? lockOnTamper,
    bool? blockUninstall,
    bool? blockSafeBoot,
    bool? blockFactoryReset,
    bool? blockDateTimeChange,
    bool? blockAddUser,
    bool? blockUnknownSources,
    bool? blockUsbDebugging,
  }) {
    return ProtectionPolicy(
      lockOnTamper: lockOnTamper ?? this.lockOnTamper,
      blockUninstall: blockUninstall ?? this.blockUninstall,
      blockSafeBoot: blockSafeBoot ?? this.blockSafeBoot,
      blockFactoryReset: blockFactoryReset ?? this.blockFactoryReset,
      blockDateTimeChange: blockDateTimeChange ?? this.blockDateTimeChange,
      blockAddUser: blockAddUser ?? this.blockAddUser,
      blockUnknownSources: blockUnknownSources ?? this.blockUnknownSources,
      blockUsbDebugging: blockUsbDebugging ?? this.blockUsbDebugging,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    lockOnTamper,
    blockUninstall,
    blockSafeBoot,
    blockFactoryReset,
    blockDateTimeChange,
    blockAddUser,
    blockUnknownSources,
    blockUsbDebugging,
  ];
}
