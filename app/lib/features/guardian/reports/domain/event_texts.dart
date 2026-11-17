import '../../../../core/time/formatters.dart';
import 'report_models.dart';

/// Textos em portugues dos eventos do aparelho (protocolo, secao 5.3). Funcoes puras.

/// Grupos de filtro da lista de eventos.
enum EventGroup {
  all('Todos', <String>[]),
  blocks('Bloqueios', <String>['blocked_attempt', 'lock_started', 'lock_ended']),
  limit('Limite', <String>['limit_reached', 'low_time', 'app_limit_reached', 'time_request']),
  security('Segurança', <String>[
    'permission_changed',
    'enforcement_issue',
    'policy_apply_failed',
    'admin_auth_failed',
    'clock_changed',
    'local_override',
    'unlinked_locally',
    'management_mode_changed',
  ]),
  apps('Apps', <String>['app_installed', 'app_removed']),
  system('Sistema', <String>['policy_applied', 'device_boot', 'device_shutdown', 'agent_started']);

  const EventGroup(this.label, this.types);

  final String label;

  /// Tipos do grupo. Vazio significa todos.
  final List<String> types;

  static EventGroup of(String type) {
    for (final EventGroup group in values) {
      if (group.types.contains(type)) {
        return group;
      }
    }
    return EventGroup.system;
  }
}

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
  switch (event.type) {
    case 'blocked_attempt':
      return (
        title: 'Tentou abrir $app',
        detail: 'Motivo: ${blockReasonLabel(event.data.strOrNull('reason'))}.',
      );
    case 'limit_reached':
      final int? used = event.data.intOrNull('quotaUsedMs');
      return (
        title: 'Limite diário atingido',
        detail: used == null ? null : 'Usou ${formatDurationMs(used)}.',
      );
    case 'low_time':
      final int? remaining = event.data.intOrNull('remainingMs');
      return (
        title: 'Pouco tempo restante',
        detail: remaining == null ? null : 'Faltavam ${formatDurationMs(remaining)}.',
      );
    case 'app_limit_reached':
      return (title: 'Limite de $app atingido', detail: null);
    case 'lock_started':
      final int? release = event.data.intOrNull('releaseAt');
      return (
        title: 'Bloqueio iniciado',
        detail:
            'Motivo: ${blockReasonLabel(event.data.strOrNull('reason'))}'
            '${release == null ? '' : ', até ${formatClockMs(release)}'}.',
      );
    case 'lock_ended':
      return (title: 'Bloqueio encerrado', detail: null);
    case 'policy_applied':
      final int? version = event.data.intOrNull('version');
      return (
        title: 'Regras aplicadas no aparelho',
        detail: version == null ? null : 'Versão $version.',
      );
    case 'policy_apply_failed':
      return (title: 'Falha ao aplicar as regras', detail: event.data.strOrNull('error'));
    case 'enforcement_issue':
      return (title: 'Problema na proteção', detail: event.data.strOrNull('issue'));
    case 'permission_changed':
      final bool granted = event.data.boolOr('granted', fallback: false);
      return (
        title:
            '${_permissionLabel(event.data.strOrNull('permission'))}: '
            '${granted ? 'concedida' : 'revogada'}',
        detail: granted ? null : 'O controle pode ficar degradado.',
      );
    case 'time_request':
      final int? minutes = event.data.intOrNull('minutes');
      final String? message = event.data.strOrNull('message');
      return (
        title: minutes == null ? 'Pediu mais tempo' : 'Pediu mais ${formatMinutes(minutes)}',
        detail: message == null || message.isEmpty ? null : '"$message"',
      );
    case 'local_override':
      final int? minutes = event.data.intOrNull('minutes');
      return (
        title: 'Uso liberado no próprio aparelho',
        detail: minutes == null ? null : 'Por ${formatMinutes(minutes)}, pelo responsável.',
      );
    case 'admin_auth_failed':
      return (title: 'Senha do responsável incorreta no aparelho', detail: null);
    case 'clock_changed':
      return (
        title: event.data.strOrNull('kind') == 'timezone'
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

/// Intervalo sem uso entre duas sessoes, para a linha do tempo.
class InactivityGap {
  const InactivityGap({required this.start, required this.end});

  final int start;
  final int end;

  int get durationMs => end - start;
}

/// Itens da linha do tempo de um dia: sessoes em ordem e os intervalos sem uso de pelo menos
/// [minGapMs] entre elas.
List<Object> buildTimeline(List<UsageSession> sessions, {int minGapMs = 15 * 60000}) {
  final List<UsageSession> sorted = <UsageSession>[...sessions]
    ..sort((UsageSession a, UsageSession b) => a.start.compareTo(b.start));
  final List<Object> items = <Object>[];
  int? lastEnd;
  for (final UsageSession session in sorted) {
    final int? previousEnd = lastEnd;
    if (previousEnd != null && session.start - previousEnd >= minGapMs) {
      items.add(InactivityGap(start: previousEnd, end: session.start));
    }
    items.add(session);
    lastEnd = previousEnd == null || session.end > previousEnd ? session.end : previousEnd;
  }
  return items;
}
