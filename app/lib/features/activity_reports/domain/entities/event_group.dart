/// Grupos de filtro da lista de eventos do aparelho.
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

  /// Grupo de um tipo de evento. Tipos desconhecidos (de versoes mais novas) caem em Sistema.
  static EventGroup of(String type) {
    for (final EventGroup group in values) {
      if (group.types.contains(type)) {
        return group;
      }
    }
    return EventGroup.system;
  }
}
