import '../../../../core/time/formatters.dart';
import '../../domain/entities/device_event.dart';

/// Textos em portugues dos eventos do aparelho (protocolo, secao 5.3). Funcoes puras.

/// Motivo de bloqueio em texto (motivos da secao 4.3 do protocolo).
String blockReasonLabel(String? reason) {
  return switch (reason) {
    'app_blocked' => 'app bloqueado pelo responsável',
    'daily_limit' => 'limite diário atingido',
    'schedule' => 'fora do horário permitido',
    'manual_lock' => 'aparelho pausado',
    'app_limit' => 'limite do app atingido',
    'new_app' => 'app novo aguardando aprovação',
    'tamper_lock' => 'proteção desativada',
    _ => 'bloqueio',
  };
}

/// Motivo de bloqueio de uma pagina no navegador gerenciado.
String browsingReasonLabel(String? reason) {
  return switch (reason) {
    'domain_blocked' => 'Site bloqueado',
    'category' => 'Categoria bloqueada',
    'safe_dns' => 'Filtro DNS familiar',
    'not_in_allowlist' => 'Fora dos sites autorizados',
    _ => 'Bloqueado',
  };
}

String _permissionLabel(String? permission) {
  return switch (permission) {
    'usageAccess' => 'Acesso ao uso',
    'accessibility' => 'Serviço de acessibilidade',
    'overlay' => 'Sobreposição a outros apps',
    'notifications' => 'Notificações',
    'batteryOptimizationIgnored' => 'Isenção de economia de bateria',
    'deviceAdmin' => 'Administrador do dispositivo',
    'exactAlarms' => 'Alarmes exatos',
    _ => permission ?? 'Permissão',
  };
}

/// Titulo e detalhe de um evento para a lista.
({String title, String? detail}) describeEvent(DeviceEvent event) {
  final String app = event.appName;
  final EventDetails details = event.details;
  switch (event.type) {
    case 'blocked_attempt':
      return (title: 'Tentou abrir $app', detail: 'Motivo: ${blockReasonLabel(details.reason)}.');
    case 'limit_reached':
      final int? used = details.quotaUsedMs;
      return (
        title: 'Limite diário atingido',
        detail: used == null ? null : 'Usou ${formatDurationMs(used)}.',
      );
    case 'low_time':
      final int? remaining = details.remainingMs;
      return (
        title: 'Pouco tempo restante',
        detail: remaining == null ? null : 'Faltavam ${formatDurationMs(remaining)}.',
      );
    case 'app_limit_reached':
      return (title: 'Limite de $app atingido', detail: null);
    case 'lock_started':
      final int? release = details.releaseAt;
      return (
        title: 'Bloqueio iniciado',
        detail:
            'Motivo: ${blockReasonLabel(details.reason)}'
            '${release == null ? '' : ', até ${formatClockMs(release)}'}.',
      );
    case 'lock_ended':
      return (title: 'Bloqueio encerrado', detail: null);
    case 'policy_applied':
      final int? version = details.version;
      return (
        title: 'Regras aplicadas no aparelho',
        detail: version == null ? null : 'Versão $version.',
      );
    case 'policy_apply_failed':
      return (title: 'Falha ao aplicar as regras', detail: details.error);
    case 'enforcement_issue':
      return (title: 'Problema na proteção', detail: details.issue);
    case 'permission_changed':
      final bool granted = details.granted ?? false;
      return (
        title:
            '${_permissionLabel(details.permission)}: '
            '${granted ? 'concedida' : 'revogada'}',
        detail: granted ? null : 'O controle pode ficar degradado.',
      );
    case 'time_request':
      final int? minutes = details.minutes;
      final String? message = details.message;
      return (
        title: minutes == null ? 'Pediu mais tempo' : 'Pediu mais ${formatMinutes(minutes)}',
        detail: message == null || message.isEmpty ? null : '"$message"',
      );
    case 'local_override':
      final int? minutes = details.minutes;
      return (
        title: 'Uso liberado no próprio aparelho',
        detail: minutes == null ? null : 'Por ${formatMinutes(minutes)}, pelo responsável.',
      );
    case 'admin_auth_failed':
      return (title: 'Senha do responsável incorreta no aparelho', detail: null);
    case 'clock_changed':
      return (
        title: details.kind == 'timezone'
            ? 'Fuso horário do aparelho alterado'
            : 'Relógio do aparelho alterado',
        detail: null,
      );
    case 'unlinked_locally':
      return (title: 'Aparelho desvinculado no próprio aparelho', detail: null);
    case 'device_boot':
      return (title: 'Aparelho ligado', detail: null);
    case 'device_shutdown':
      return (title: 'Aparelho desligado', detail: null);
    case 'agent_started':
      return (title: 'Controle parental iniciado', detail: null);
    case 'management_mode_changed':
      return (title: 'Modo de gerenciamento alterado', detail: null);
    case 'app_installed':
      return (title: 'App instalado: $app', detail: null);
    case 'app_removed':
      return (title: 'App removido: $app', detail: null);
    default:
      return (title: event.type, detail: null);
  }
}
