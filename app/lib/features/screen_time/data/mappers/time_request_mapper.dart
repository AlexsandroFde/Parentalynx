import '../../domain/entities/time_request.dart';
import '../dto/time_request_dto.dart';

/// Converte os pedidos de tempo do protocolo nas entidades.
abstract final class TimeRequestMapper {
  static TimeRequest request(TimeRequestDto dto) {
    return TimeRequest(
      id: dto.id,
      deviceId: dto.deviceId ?? '',
      childName: dto.childName ?? '',
      createdAt: dto.createdAt ?? 0,
      minutes: dto.minutes,
      message: dto.message,
      status: status(dto.status),
      grantedMinutes: dto.grantedMinutes,
      resolvedAt: dto.resolvedAt,
    );
  }

  /// Situacao pelo codigo do protocolo. Codigo desconhecido vale "aguardando".
  static TimeRequestStatus status(String? code) {
    return switch (code) {
      'approved' => TimeRequestStatus.approved,
      'denied' => TimeRequestStatus.denied,
      'expired' => TimeRequestStatus.expired,
      _ => TimeRequestStatus.pending,
    };
  }

  static String statusCode(TimeRequestStatus status) {
    return switch (status) {
      TimeRequestStatus.pending => 'pending',
      TimeRequestStatus.approved => 'approved',
      TimeRequestStatus.denied => 'denied',
      TimeRequestStatus.expired => 'expired',
    };
  }
}
