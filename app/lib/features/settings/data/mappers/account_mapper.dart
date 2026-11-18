import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/domain/entities/guardian_session.dart';
import '../../domain/entities/audit_entry.dart';
import '../dto/account_dtos.dart';

/// Converte os objetos do protocolo da gestao da conta nas entidades, aplicando os valores
/// padrao do protocolo para campos ausentes.
abstract final class AccountMapper {
  static const GuardianSettings _defaults = GuardianSettings();

  static GuardianSettings settings(AccountSettingsDto? dto) {
    if (dto == null) {
      return _defaults;
    }
    return GuardianSettings(
      retentionDays: dto.retentionDays ?? _defaults.retentionDays,
      syncStaleMinutes: dto.syncStaleMinutes ?? _defaults.syncStaleMinutes,
      offlineHours: dto.offlineHours ?? _defaults.offlineHours,
      lowTimeMinutes: dto.lowTimeMinutes ?? _defaults.lowTimeMinutes,
    );
  }

  static AccountSettingsDto settingsToDto(GuardianSettings settings) {
    return AccountSettingsDto(
      retentionDays: settings.retentionDays,
      syncStaleMinutes: settings.syncStaleMinutes,
      offlineHours: settings.offlineHours,
      lowTimeMinutes: settings.lowTimeMinutes,
    );
  }

  static GuardianAccount account(AccountDto dto) {
    return GuardianAccount(
      id: dto.id,
      email: dto.email,
      displayName: dto.displayName ?? '',
      createdAt: dto.createdAt ?? 0,
      settings: settings(dto.settings),
      notificationPrefs: dto.notificationPrefs ?? const <String, bool>{},
    );
  }

  static GuardianSessionInfo session(AccountSessionDto dto) {
    return GuardianSessionInfo(
      id: dto.id,
      deviceName: dto.deviceName ?? '',
      createdAt: dto.createdAt ?? 0,
      lastSeenAt: dto.lastSeenAt ?? 0,
      expiresAt: dto.expiresAt ?? 0,
      elevatedUntil: dto.elevatedUntil ?? 0,
      current: dto.current ?? false,
    );
  }

  static AuditEntry auditEntry(AuditEntryDto dto) {
    return AuditEntry(
      id: dto.id,
      at: dto.at ?? 0,
      action: dto.action ?? '',
      summary: dto.summary ?? '',
      deviceName: dto.deviceName,
      targetType: dto.targetType,
      ip: dto.ip,
    );
  }

  static AuditLogPage auditPage(AuditPageDto dto) {
    return AuditLogPage(entries: dto.entries.map(auditEntry).toList(), nextBefore: dto.nextBefore);
  }
}
