import '../../../../core/json/json_reader.dart';

// Objetos de transferencia do pedido de vinculo feito por este aparelho (protocolo, secao
// 3.2). Espelham o JSON; o `PairingClaimMapper` converte nas entidades.

/// Pedido aceito pelo servidor. Tambem e a forma guardada no armazenamento seguro.
final class PairingClaimDto {
  const PairingClaimDto({
    required this.linkId,
    required this.pollToken,
    required this.confirmCode,
    this.guardianName,
    this.expiresAt,
  });

  factory PairingClaimDto.fromJson(JsonMap json) {
    return PairingClaimDto(
      linkId: json.str('linkId'),
      pollToken: json.str('pollToken'),
      confirmCode: json.str('confirmCode'),
      guardianName: json.strOrNull('guardianName'),
      expiresAt: json.intOrNull('expiresAt'),
    );
  }

  final String linkId;
  final String pollToken;
  final String confirmCode;
  final String? guardianName;
  final int? expiresAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'linkId': linkId,
      'pollToken': pollToken,
      'confirmCode': confirmCode,
      'guardianName': guardianName,
      'expiresAt': expiresAt,
    };
  }
}

/// Credenciais entregues na aprovacao.
final class PairingCredentialsDto {
  const PairingCredentialsDto({
    required this.deviceId,
    required this.deviceToken,
    required this.offlineSecret,
  });

  factory PairingCredentialsDto.fromJson(JsonMap json) {
    return PairingCredentialsDto(
      deviceId: json.str('deviceId'),
      deviceToken: json.str('deviceToken'),
      offlineSecret: json.str('offlineSecret'),
    );
  }

  final String deviceId;
  final String deviceToken;
  final String offlineSecret;
}

/// Resposta de `GET /v1/pairing/status`.
final class PairingStatusDto {
  const PairingStatusDto({
    this.status,
    this.credentials,
    this.childName,
    this.guardianName,
    this.policyVersion,
    this.policy,
  });

  factory PairingStatusDto.fromJson(JsonMap json) {
    final JsonMap? credentials = json.objOrNull('credentials');
    return PairingStatusDto(
      status: json.strOrNull('status'),
      credentials: credentials == null ? null : PairingCredentialsDto.fromJson(credentials),
      childName: json.strOrNull('childName'),
      guardianName: json.strOrNull('guardianName'),
      policyVersion: json.intOrNull('policyVersion'),
      policy: json.objOrNull('policy'),
    );
  }

  /// `pending`, `approved`, `rejected` ou `expired`.
  final String? status;
  final PairingCredentialsDto? credentials;
  final String? childName;
  final String? guardianName;
  final int? policyVersion;

  /// Politica inicial, repassada ao agente como veio.
  final JsonMap? policy;
}

/// `DeviceInfo` enviado no pedido de vinculo.
final class DeviceIdentityDto {
  const DeviceIdentityDto({
    required this.name,
    required this.model,
    required this.manufacturer,
    required this.androidRelease,
    required this.sdkInt,
    required this.appVersion,
    required this.timezone,
    required this.hardwareId,
  });

  final String name;
  final String model;
  final String manufacturer;
  final String androidRelease;
  final int sdkInt;
  final String appVersion;
  final String timezone;
  final String hardwareId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'model': model,
      'manufacturer': manufacturer,
      'androidRelease': androidRelease,
      'sdkInt': sdkInt,
      'appVersion': appVersion,
      'timezone': timezone,
      'hardwareId': hardwareId,
    };
  }
}
