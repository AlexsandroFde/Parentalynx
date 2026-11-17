import '../../../../core/json/json_reader.dart';
import '../../devices/domain/device.dart';

/// Codigo de vinculacao recem-gerado (protocolo, secao 3). O texto do codigo so existe nesta
/// resposta: o servidor guarda apenas o hash.
class PairingCodeInfo {
  const PairingCodeInfo({required this.id, required this.code, required this.expiresAt});

  factory PairingCodeInfo.fromJson(JsonMap json) {
    return PairingCodeInfo(
      id: json.str('id'),
      code: json.str('code'),
      expiresAt: json.integer('expiresAt'),
    );
  }

  final String id;
  final String code;
  final int expiresAt;
}

/// Referencia ao codigo ativo no servidor, sem o texto.
class ActiveCodeRef {
  const ActiveCodeRef({required this.id, required this.expiresAt});

  factory ActiveCodeRef.fromJson(JsonMap json) {
    return ActiveCodeRef(id: json.str('id'), expiresAt: json.integer('expiresAt'));
  }

  final String id;
  final int expiresAt;
}

/// Situacao da vinculacao: codigo ativo (se houver) e pedidos aguardando aprovacao.
class ActivePairing {
  const ActivePairing({required this.pending, this.code});

  factory ActivePairing.fromJson(JsonMap json) {
    final JsonMap? code = json.objOrNull('code');
    return ActivePairing(
      code: code == null ? null : ActiveCodeRef.fromJson(code),
      pending: json.objList('pending').map(Device.fromJson).toList(),
    );
  }

  final ActiveCodeRef? code;
  final List<Device> pending;
}

/// Geracao e acompanhamento de codigos de vinculacao.
abstract interface class PairingRepository {
  /// (E) Gera um codigo novo. O codigo anterior, se houver, deixa de valer.
  Future<PairingCodeInfo> createCode();

  Future<ActivePairing> active();

  Future<void> cancelCode(String codeId);
}
