import '../../../../core/json/json_reader.dart';

// Objetos de transferencia da vinculacao vista pelo responsavel (protocolo, secao 3.2).
// Espelham o JSON: campos opcionais ficam nulos. Os valores padrao sao aplicados pelo
// `GuardianLinkingMapper`.

/// Resposta de `POST /v1/guardian/pairing-codes`.
final class LinkCodeDto {
  const LinkCodeDto({required this.id, required this.code, required this.expiresAt});

  factory LinkCodeDto.fromJson(JsonMap json) {
    return LinkCodeDto(
      id: json.str('id'),
      code: json.str('code'),
      expiresAt: json.integer('expiresAt'),
    );
  }

  final String id;
  final String code;
  final int expiresAt;
}

/// Codigo ativo em `GET /v1/guardian/pairing-codes/active`, sem o texto.
final class ActiveLinkCodeDto {
  const ActiveLinkCodeDto({required this.id, required this.expiresAt});

  factory ActiveLinkCodeDto.fromJson(JsonMap json) {
    return ActiveLinkCodeDto(id: json.str('id'), expiresAt: json.integer('expiresAt'));
  }

  final String id;
  final int expiresAt;
}

/// Aparelho (`Device`) de um pedido pendente ou da resposta da aprovacao. So os campos que a
/// vinculacao usa.
final class LinkRequestDto {
  const LinkRequestDto({
    required this.id,
    this.deviceName,
    this.childName,
    this.model,
    this.manufacturer,
    this.androidRelease,
    this.relink,
    this.createdAt,
    this.confirmCode,
  });

  factory LinkRequestDto.fromJson(JsonMap json) {
    return LinkRequestDto(
      id: json.str('id'),
      deviceName: json.strOrNull('deviceName'),
      childName: json.strOrNull('childName'),
      model: json.strOrNull('model'),
      manufacturer: json.strOrNull('manufacturer'),
      androidRelease: json.strOrNull('androidRelease'),
      relink: json.boolOr('relink', fallback: false),
      createdAt: json.intOrNull('createdAt'),
      confirmCode: json.strOrNull('confirmCode'),
    );
  }

  final String id;
  final String? deviceName;
  final String? childName;
  final String? model;
  final String? manufacturer;
  final String? androidRelease;
  final bool? relink;
  final int? createdAt;
  final String? confirmCode;
}

/// Resposta de `GET /v1/guardian/pairing-codes/active`.
final class LinkingOverviewDto {
  const LinkingOverviewDto({required this.pending, this.code});

  factory LinkingOverviewDto.fromJson(JsonMap json) {
    final JsonMap? code = json.objOrNull('code');
    return LinkingOverviewDto(
      code: code == null ? null : ActiveLinkCodeDto.fromJson(code),
      pending: json.objList('pending').map(LinkRequestDto.fromJson).toList(),
    );
  }

  final ActiveLinkCodeDto? code;
  final List<LinkRequestDto> pending;
}
