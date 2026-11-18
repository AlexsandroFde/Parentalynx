import 'package:equatable/equatable.dart';

/// Dados deste aparelho enviados no pedido de vinculo (`DeviceInfo` do protocolo).
final class DeviceIdentity extends Equatable {
  const DeviceIdentity({
    required this.name,
    required this.model,
    required this.manufacturer,
    required this.androidRelease,
    required this.sdkInt,
    required this.appVersion,
    required this.timezone,
    required this.hardwareId,
  });

  /// Nome amigavel do aparelho.
  final String name;
  final String model;
  final String manufacturer;
  final String androidRelease;
  final int sdkInt;
  final String appVersion;

  /// Identificador IANA do fuso do aparelho.
  final String timezone;

  /// SHA-256 em hexadecimal do identificador do aparelho para este app.
  final String hardwareId;

  DeviceIdentity withName(String value) {
    return DeviceIdentity(
      name: value,
      model: model,
      manufacturer: manufacturer,
      androidRelease: androidRelease,
      sdkInt: sdkInt,
      appVersion: appVersion,
      timezone: timezone,
      hardwareId: hardwareId,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    name,
    model,
    manufacturer,
    androidRelease,
    sdkInt,
    appVersion,
    timezone,
    hardwareId,
  ];
}
