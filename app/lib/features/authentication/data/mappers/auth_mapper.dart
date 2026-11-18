import '../../../../core/json/json_reader.dart';
import '../../domain/entities/guardian_account.dart';
import '../../domain/entities/guardian_session.dart';
import '../dto/auth_dtos.dart';

/// Converte os objetos do protocolo nas entidades de conta e sessao, aplicando os valores
/// padrao do protocolo para campos ausentes.
abstract final class AuthMapper {
  static const GuardianSettings _defaults = GuardianSettings();

  static GuardianSettings settings(GuardianSettingsDto? dto) {
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

  static GuardianSettingsDto settingsToDto(GuardianSettings settings) {
    return GuardianSettingsDto(
      retentionDays: settings.retentionDays,
      syncStaleMinutes: settings.syncStaleMinutes,
      offlineHours: settings.offlineHours,
      lowTimeMinutes: settings.lowTimeMinutes,
    );
  }

  static GuardianAccount account(GuardianAccountDto dto) {
    return GuardianAccount(
      id: dto.id,
      email: dto.email,
      displayName: dto.displayName ?? '',
      createdAt: dto.createdAt ?? 0,
      settings: settings(dto.settings),
      notificationPrefs: dto.notificationPrefs ?? const <String, bool>{},
    );
  }

  static GuardianSessionInfo session(GuardianSessionDto dto) {
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

  static GuardianProfile profile(ProfileResponseDto dto) {
    return GuardianProfile(account: account(dto.guardian), session: session(dto.session));
  }

  /// A sessao criada precisa trazer o token; sem ele a resposta e invalida.
  static AuthenticatedSession authenticated(AuthResponseDto dto) {
    final String? token = dto.session.token;
    if (token == null || token.isEmpty) {
      throw const JsonFormatException('Sessao criada sem token');
    }
    return AuthenticatedSession(
      account: account(dto.guardian),
      session: session(dto.session),
      token: token,
      recoveryKey: dto.recoveryKey,
    );
  }
}
