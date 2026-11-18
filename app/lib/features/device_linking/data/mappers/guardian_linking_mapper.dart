import '../../domain/entities/link_code.dart';
import '../../domain/entities/link_request.dart';
import '../../domain/entities/linking_overview.dart';
import '../dto/guardian_linking_dtos.dart';

/// Converte os objetos do protocolo da vinculacao nas entidades vistas pelo responsavel.
abstract final class GuardianLinkingMapper {
  static LinkCode code(LinkCodeDto dto) {
    return LinkCode(id: dto.id, code: dto.code, expiresAt: dto.expiresAt);
  }

  static ActiveLinkCode activeCode(ActiveLinkCodeDto dto) {
    return ActiveLinkCode(id: dto.id, expiresAt: dto.expiresAt);
  }

  static LinkRequest request(LinkRequestDto dto) {
    return LinkRequest(
      id: dto.id,
      deviceName: dto.deviceName ?? '',
      childName: dto.childName ?? '',
      model: dto.model ?? '',
      manufacturer: dto.manufacturer ?? '',
      androidRelease: dto.androidRelease ?? '',
      relink: dto.relink ?? false,
      createdAt: dto.createdAt ?? 0,
      confirmCode: dto.confirmCode,
    );
  }

  static LinkingOverview overview(LinkingOverviewDto dto) {
    final ActiveLinkCodeDto? code = dto.code;
    return LinkingOverview(
      activeCode: code == null ? null : activeCode(code),
      requests: dto.pending.map(request).toList(),
    );
  }
}
