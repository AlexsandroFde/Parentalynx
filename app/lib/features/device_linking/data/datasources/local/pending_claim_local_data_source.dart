import 'dart:convert';

import '../../../../../core/constants/storage_keys.dart';
import '../../../../../core/json/json_reader.dart';
import '../../../../../core/storage/secure_store.dart';
import '../../dto/pairing_claim_dtos.dart';

/// Pedido de vinculo em andamento no armazenamento cifrado.
///
/// A chave fica fora do prefixo `agent.`, reservado ao agente nativo.
class PendingClaimLocalDataSource {
  const PendingClaimLocalDataSource(this._store);

  final SecureStore _store;

  /// Pedido guardado. Texto fora do formato e apagado e vale como "sem pedido".
  Future<PairingClaimDto?> read() async {
    final String? source = await _store.read(StorageKeys.childPendingClaim);
    if (source == null || source.isEmpty) {
      return null;
    }
    try {
      return PairingClaimDto.fromJson(decodeJsonObject(source));
    } on JsonFormatException {
      await _store.delete(StorageKeys.childPendingClaim);
      return null;
    }
  }

  Future<void> write(PairingClaimDto claim) {
    return _store.write(StorageKeys.childPendingClaim, jsonEncode(claim.toJson()));
  }

  Future<void> clear() => _store.delete(StorageKeys.childPendingClaim);
}
