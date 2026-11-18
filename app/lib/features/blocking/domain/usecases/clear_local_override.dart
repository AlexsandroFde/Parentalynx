import '../../../../core/result/result.dart';
import '../services/i_application_blocking_service.dart';

/// Encerra a liberacao local antes do tempo: as regras voltam a valer na hora.
class ClearLocalOverride {
  const ClearLocalOverride(this._service);

  final IApplicationBlockingService _service;

  Future<Result<void>> call() => _service.clearLocalOverride();
}
