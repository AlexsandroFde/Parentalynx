import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';
import '../domain/pairing.dart';

class ApiPairingRepository implements PairingRepository {
  const ApiPairingRepository(this._api);

  final ApiClient _api;

  @override
  Future<PairingCodeInfo> createCode() async {
    return PairingCodeInfo.fromJson(await _api.post('/v1/guardian/pairing-codes'));
  }

  @override
  Future<ActivePairing> active() async {
    return ActivePairing.fromJson(await _api.get('/v1/guardian/pairing-codes/active'));
  }

  @override
  Future<void> cancelCode(String codeId) async {
    await _api.delete('/v1/guardian/pairing-codes/${Uri.encodeComponent(codeId)}');
  }
}

final Provider<PairingRepository> pairingRepositoryProvider = Provider<PairingRepository>(
  (Ref ref) => ApiPairingRepository(ref.watch(apiClientProvider)),
);
