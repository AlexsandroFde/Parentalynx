import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/device_identity.dart';
import '../../domain/entities/pairing_claim.dart';
import '../../domain/entities/pairing_status.dart';
import '../../domain/repositories/i_pairing_claim_repository.dart';
import '../datasources/remote/pairing_claim_remote_data_source.dart';
import '../dto/pairing_claim_dtos.dart';
import '../mappers/pairing_claim_mapper.dart';

/// Implementacao de [IPairingClaimRepository] sobre a API.
class ApiPairingClaimRepository implements IPairingClaimRepository {
  const ApiPairingClaimRepository(this._remote);

  final PairingClaimRemoteDataSource _remote;

  @override
  Future<Result<PairingClaim>> claim({required String code, required DeviceIdentity device}) {
    return Result.guard(() async {
      final PairingClaimDto dto = await _remote.claim(
        code: code,
        device: PairingClaimMapper.identityToDto(device),
      );
      return PairingClaimMapper.claim(dto);
    });
  }

  @override
  Future<Result<PairingStatus>> status(String pollToken) async {
    final Result<PairingStatus> result = await Result.guard(
      () async => PairingClaimMapper.status(await _remote.status(pollToken)),
    );
    // O token de consulta deixa de valer depois da entrega ou do vencimento do pedido.
    if (result case Err<PairingStatus>(failure: final ApiFailure failure)) {
      if (failure.status == 401 || failure.status == 404 || failure.code == 'code_expired') {
        return const Ok<PairingStatus>(PairingExpired());
      }
    }
    return result;
  }
}
