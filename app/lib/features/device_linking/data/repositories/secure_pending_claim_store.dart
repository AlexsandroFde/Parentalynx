import '../../../../core/result/result.dart';
import '../../domain/entities/pairing_claim.dart';
import '../../domain/repositories/i_pending_claim_store.dart';
import '../datasources/local/pending_claim_local_data_source.dart';
import '../dto/pairing_claim_dtos.dart';
import '../mappers/pairing_claim_mapper.dart';

/// Pedido em andamento guardado no armazenamento cifrado.
class SecurePendingClaimStore implements IPendingClaimStore {
  const SecurePendingClaimStore(this._local);

  final PendingClaimLocalDataSource _local;

  @override
  Future<Result<PairingClaim?>> read() {
    return Result.guard<PairingClaim?>(() async {
      final PairingClaimDto? dto = await _local.read();
      return dto == null ? null : PairingClaimMapper.claim(dto);
    });
  }

  @override
  Future<Result<void>> write(PairingClaim claim) {
    return Result.guard<void>(() => _local.write(PairingClaimMapper.claimToDto(claim)));
  }

  @override
  Future<Result<void>> clear() => Result.guard<void>(_local.clear);
}
