import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/json/json_reader.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/platform/native_providers.dart';
import '../../../../core/security/pairing_code.dart';
import '../../../../core/storage/secure_store.dart';
import '../../agent/domain/child_models.dart';
import '../domain/pairing.dart';

/// Implementacao de [PairingRepository] sobre a API (protocolo, secao 3.2).
class ApiPairingRepository implements PairingRepository {
  const ApiPairingRepository(this._api);

  final ApiClient _api;

  @override
  Future<PairingClaim> claim({required String code, required DeviceIdentity device}) async {
    final JsonMap json = await _api.post(
      '/v1/pairing/claim',
      auth: ApiAuth.none,
      body: <String, Object?>{'code': PairingCode.normalize(code), 'device': device.toJson()},
    );
    return PairingClaim.fromJson(json);
  }

  @override
  Future<PairingStatus> status(String pollToken) async {
    final JsonMap json;
    try {
      json = await _api.get('/v1/pairing/status', auth: ApiAuth.none, bearer: pollToken);
    } on ApiFailure catch (failure) {
      // O token de consulta deixa de valer depois da entrega ou do vencimento do pedido.
      if (failure.status == 401 || failure.status == 404 || failure.code == 'code_expired') {
        return const PairingExpired();
      }
      rethrow;
    }
    switch (json.strOrNull('status')) {
      case 'approved':
        final JsonMap credentials = json.obj('credentials');
        return PairingApproved(
          deviceId: credentials.str('deviceId'),
          deviceToken: credentials.str('deviceToken'),
          offlineSecret: credentials.str('offlineSecret'),
          childName: json.strOrNull('childName') ?? '',
          guardianName: json.strOrNull('guardianName') ?? '',
          policyVersion: json.intOr('policyVersion', fallback: 0),
          policyJson: jsonEncode(json.obj('policy').raw),
        );
      case 'rejected':
        return const PairingRejected();
      case 'expired':
        return const PairingExpired();
      default:
        return const PairingPending();
    }
  }
}

final Provider<PairingRepository> pairingRepositoryProvider = Provider<PairingRepository>(
  (Ref ref) => ApiPairingRepository(ref.watch(apiClientProvider)),
);

/// Guarda o pedido em andamento no armazenamento cifrado.
class SecurePendingClaimStore implements PendingClaimStore {
  const SecurePendingClaimStore(this._store);

  /// Chave fora do prefixo `agent.`, reservado ao agente nativo.
  static const String key = 'child.pending_claim';

  final SecureStore _store;

  @override
  Future<PairingClaim?> read() async {
    final String? source = await _store.read(key);
    if (source == null || source.isEmpty) {
      return null;
    }
    try {
      return PairingClaim.fromJson(decodeJsonObject(source));
    } on JsonFormatException {
      await _store.delete(key);
      return null;
    }
  }

  @override
  Future<void> write(PairingClaim claim) => _store.write(key, jsonEncode(claim.toJson()));

  @override
  Future<void> clear() => _store.delete(key);
}

final Provider<PendingClaimStore> pendingClaimStoreProvider = Provider<PendingClaimStore>(
  (Ref ref) => SecurePendingClaimStore(ref.watch(secureStoreProvider)),
);
