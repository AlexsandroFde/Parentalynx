import 'dart:convert';

import '../../../../core/json/json_reader.dart';
import '../../domain/entities/device_identity.dart';
import '../../domain/entities/pairing_claim.dart';
import '../../domain/entities/pairing_status.dart';
import '../dto/pairing_claim_dtos.dart';

/// Converte o pedido de vinculo do protocolo nas entidades e de volta.
abstract final class PairingClaimMapper {
  static PairingClaim claim(PairingClaimDto dto) {
    return PairingClaim(
      linkId: dto.linkId,
      pollToken: dto.pollToken,
      confirmCode: dto.confirmCode,
      guardianName: dto.guardianName ?? '',
      expiresAt: dto.expiresAt ?? 0,
    );
  }

  static PairingClaimDto claimToDto(PairingClaim claim) {
    return PairingClaimDto(
      linkId: claim.linkId,
      pollToken: claim.pollToken,
      confirmCode: claim.confirmCode,
      guardianName: claim.guardianName,
      expiresAt: claim.expiresAt,
    );
  }

  /// Andamento do pedido. Aprovacao sem credenciais ou sem politica e resposta invalida.
  static PairingStatus status(PairingStatusDto dto) {
    switch (dto.status) {
      case 'approved':
        final PairingCredentialsDto? credentials = dto.credentials;
        final JsonMap? policy = dto.policy;
        if (credentials == null || policy == null) {
          throw const JsonFormatException('Aprovacao sem credenciais ou sem politica');
        }
        return PairingApproved(
          deviceId: credentials.deviceId,
          deviceToken: credentials.deviceToken,
          offlineSecret: credentials.offlineSecret,
          childName: dto.childName ?? '',
          guardianName: dto.guardianName ?? '',
          policyVersion: dto.policyVersion ?? 0,
          initialPolicy: jsonEncode(policy.raw),
        );
      case 'rejected':
        return const PairingRejected();
      case 'expired':
        return const PairingExpired();
      default:
        return const PairingPending();
    }
  }

  static DeviceIdentityDto identityToDto(DeviceIdentity identity) {
    return DeviceIdentityDto(
      name: identity.name,
      model: identity.model,
      manufacturer: identity.manufacturer,
      androidRelease: identity.androidRelease,
      sdkInt: identity.sdkInt,
      appVersion: identity.appVersion,
      timezone: identity.timezone,
      hardwareId: identity.hardwareId,
    );
  }
}
