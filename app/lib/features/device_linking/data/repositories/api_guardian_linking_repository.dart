import '../../../../core/result/result.dart';
import '../../domain/entities/link_code.dart';
import '../../domain/entities/link_request.dart';
import '../../domain/entities/linking_overview.dart';
import '../../domain/repositories/i_guardian_linking_repository.dart';
import '../datasources/remote/guardian_linking_remote_data_source.dart';
import '../mappers/guardian_linking_mapper.dart';

/// Vinculacao do responsavel pela API, com o ultimo codigo gerado em memoria.
class ApiGuardianLinkingRepository implements IGuardianLinkingRepository {
  ApiGuardianLinkingRepository(this._remote);

  final GuardianLinkingRemoteDataSource _remote;
  LinkCode? _shownCode;

  @override
  LinkCode? get shownCode => _shownCode;

  @override
  Future<Result<LinkCode>> createCode() async {
    final Result<LinkCode> result = await Result.guard(
      () async => GuardianLinkingMapper.code(await _remote.createCode()),
    );
    if (result case Ok<LinkCode>(:final LinkCode value)) {
      _shownCode = value;
    }
    return result;
  }

  @override
  Future<Result<LinkingOverview>> overview() {
    return Result.guard(() async => GuardianLinkingMapper.overview(await _remote.active()));
  }

  @override
  Future<Result<void>> cancelCode(String codeId) async {
    final Result<void> result = await Result.guard(() => _remote.cancelCode(codeId));
    if (result is Ok<void>) {
      forgetCode(codeId);
    }
    return result;
  }

  @override
  void forgetCode(String codeId) {
    if (_shownCode?.id == codeId) {
      _shownCode = null;
    }
  }

  @override
  Future<Result<LinkRequest>> approve(String requestId, {required String childName}) {
    return Result.guard(
      () async =>
          GuardianLinkingMapper.request(await _remote.approve(requestId, childName: childName)),
    );
  }

  @override
  Future<Result<void>> reject(String requestId) => Result.guard(() => _remote.reject(requestId));
}
