/// Textos da tela inicial da crianca, em funcoes puras para poderem ser testados sem a
/// interface. A linguagem e simples e sem tom de castigo.
library;

import '../../../../core/time/formatters.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_sync/domain/entities/device_sync_result.dart';
import '../../domain/entities/agent_status.dart';
import '../../domain/entities/child_lock.dart';

/// Explicacao do bloqueio geral em vigor.
class LockMessage {
  const LockMessage({required this.title, required this.body});

  final String title;
  final String body;
}

String _guardian(AgentStatus status) {
  return status.guardianName.isEmpty ? 'seu responsável' : status.guardianName;
}

/// Mensagem do bloqueio em vigor, ou nulo quando o aparelho esta liberado.
LockMessage? lockMessage(AgentStatus status) {
  if (!status.isLocked) {
    return null;
  }
  final int? releaseAt = status.releaseAtMs;
  final String? release = releaseAt == null ? null : formatReleaseTime(releaseAt, now: status.now);
  switch (status.lock) {
    case ChildLock.none:
      return null;
    case ChildLock.dailyLimit:
      return LockMessage(
        title: 'Seu tempo de hoje acabou',
        body: release == null
            ? 'Você já usou todo o tempo de hoje.'
            : 'Você já usou todo o tempo de hoje. O tempo volta $release.',
      );
    case ChildLock.schedule:
      final String? label = status.activeScheduleLabel;
      return LockMessage(
        title: label == null || label.isEmpty ? 'Hora de pausa' : label,
        body: release == null
            ? 'Agora o aparelho está em pausa.'
            : 'Agora o aparelho está em pausa. Ele volta a liberar $release.',
      );
    case ChildLock.manualLock:
      final String guardian = _guardian(status);
      return LockMessage(
        title: 'Aparelho em pausa',
        body: release == null
            ? 'O aparelho foi pausado por $guardian. Fale com $guardian para liberar.'
            : 'O aparelho foi pausado por $guardian. A pausa vai até $release.',
      );
    case ChildLock.tamperLock:
      return LockMessage(
        title: 'O controle precisa de atenção',
        body:
            'Uma permissão do controle parental foi desligada. Chame ${_guardian(status)} '
            'para arrumar.',
      );
  }
}

/// O que continua funcionando durante um bloqueio.
const String lockedStillWorks = 'Os apps liberados e as ligações continuam funcionando.';

/// Numeros e textos do anel de tempo.
class TimeDisplay {
  const TimeDisplay({
    required this.headline,
    required this.caption,
    required this.detail,
    required this.progress,
    required this.level,
  });

  /// Valor em destaque no centro do anel.
  final String headline;
  final String caption;
  final String detail;

  /// Fracao da cota ja usada, de 0 a 1.
  final double progress;
  final TimeLevel level;
}

/// Quanto da cota ainda resta, para a cor do anel. O valor em texto sempre acompanha.
enum TimeLevel { unlimited, plenty, low, over }

TimeDisplay timeDisplay(AgentStatus status) {
  if (!status.hasQuota) {
    return TimeDisplay(
      headline: 'Sem limite',
      caption: 'de tempo hoje',
      detail: 'Você usou ${formatDurationMs(status.totalUsedMs)} hoje.',
      progress: 0,
      level: TimeLevel.unlimited,
    );
  }
  final int remaining = status.remainingMs;
  final String extra = status.extraMs > 0
      ? ' (com ${formatDurationMs(status.extraMs)} extras)'
      : '';
  final TimeLevel level;
  if (remaining <= 0) {
    level = TimeLevel.over;
  } else if (status.limitMs > 0 && remaining / status.limitMs <= 0.2) {
    level = TimeLevel.low;
  } else {
    level = TimeLevel.plenty;
  }
  return TimeDisplay(
    headline: formatCountdown(remaining),
    caption: remaining <= 0 ? 'o tempo acabou' : 'de tempo restante',
    detail:
        'Você usou ${formatDurationMs(status.quotaUsedMs)} de '
        '${formatDurationMs(status.limitMs)}$extra.',
    progress: status.usedFraction,
    level: level,
  );
}

/// Aviso de regras em pausa ou de uso liberado pelo responsavel, ou nulo quando nao ha.
String? reliefMessage(AgentStatus status) {
  if (status.localOverrideActive) {
    return 'Uso liberado pelo responsável até ${formatClockMs(status.localOverrideUntilMs)}.';
  }
  if (status.suspensionActive) {
    final List<String> parts = <String>[
      for (final SuspensionScope scope in status.suspensionScopes) scope.label.toLowerCase(),
    ];
    final String scope = parts.isEmpty ? 'algumas regras' : _joinList(parts);
    return 'Em pausa até ${formatClockMs(status.suspensionUntilMs)}: $scope.';
  }
  return null;
}

/// Texto simples para um problema de aplicacao das regras.
String issueText(String code) {
  return switch (code) {
    'accessibility_disabled' => 'A acessibilidade do controle está desligada.',
    'usage_access_missing' => 'O acesso ao uso está desligado.',
    'overlay_missing' => 'A permissão de aparecer sobre outros apps está desligada.',
    'notifications_disabled' => 'As notificações do controle estão desligadas.',
    'battery_optimized' => 'A economia de bateria pode desligar o controle.',
    'suspend_failed' => 'Alguns apps não puderam ser bloqueados pelo sistema.',
    'policy_invalid' => 'As regras recebidas não puderam ser lidas.',
    'clock_untrusted' => 'A hora do aparelho não pôde ser conferida.',
    _ => 'O controle encontrou um problema.',
  };
}

/// Resumo dos problemas para a faixa de aviso, ou nulo quando esta tudo certo.
String? attentionMessage(AgentStatus status) {
  final List<String> texts = <String>[
    for (final String code in status.issues) issueText(code),
    if (!status.clockTrusted && !status.issues.contains('clock_untrusted'))
      issueText('clock_untrusted'),
  ];
  if (texts.isEmpty) {
    return null;
  }
  if (texts.length == 1) {
    return '${texts.first} O responsável já foi avisado.';
  }
  return '${texts.first} E mais ${texts.length - 1} '
      '${texts.length - 1 == 1 ? 'aviso' : 'avisos'}. O responsável já foi avisado.';
}

/// Estado de conexao com o servidor.
class ConnectionText {
  const ConnectionText({required this.text, required this.ok});

  final String text;
  final bool ok;
}

ConnectionText connectionText(AgentStatus status) {
  final int? last = status.lastSyncAtMs;
  if (last == null) {
    return const ConnectionText(text: 'Ainda não sincronizou com o responsável.', ok: false);
  }
  final String when = formatRelativeMs(last, now: status.now);
  if (status.lastSyncOk) {
    return ConnectionText(text: 'Regras em dia. Última sincronização: $when.', ok: true);
  }
  return ConnectionText(
    text:
        'Sem conexão com o servidor. Última sincronização: $when. As regras continuam '
        'valendo.',
    ok: false,
  );
}

/// Mensagem para o resultado de "Sincronizar agora".
String syncResultMessage(DeviceSyncResult result) {
  if (result.ok) {
    return 'Tudo sincronizado.';
  }
  return switch (result.errorCode) {
    'network' => 'Sem conexão com o servidor. Tente de novo mais tarde.',
    'device_revoked' => 'O vínculo deste aparelho foi removido pelo responsável.',
    _ => 'Não foi possível sincronizar agora.',
  };
}

/// Aviso depois de registrar um pedido de tempo.
const String timeRequestSentMessage = 'Pedido enviado. Você vê a resposta aqui.';

/// Aviso quando um app sempre liberado nao abriu.
String launchFailedMessage(String label) => 'Não foi possível abrir $label.';

/// Tipo de uma linha do resumo de regras, para a tela escolher o icone.
enum RuleKind { dailyLimit, reset, allowedHours, blockPeriod, blockedApps, newApps, web }

class RuleLine {
  const RuleLine({required this.kind, required this.text});

  final RuleKind kind;
  final String text;
}

/// Resumo das regras que valem hoje, em frases curtas.
List<RuleLine> ruleLines(Policy policy, {required AgentStatus status}) {
  final int weekday = _weekdayOf(status);
  final DailyLimit limit = policy.dailyLimit;
  final List<RuleLine> lines = <RuleLine>[];

  if (limit.enabled) {
    final int extra = policy.overrides.extraMinutesFor(status.day);
    final String extraText = extra > 0 ? ', mais ${formatMinutes(extra)} extras hoje' : '';
    lines.add(
      RuleLine(
        kind: RuleKind.dailyLimit,
        text: 'Tempo por dia: ${formatMinutes(limit.minutesFor(weekday))}$extraText.',
      ),
    );
    if (limit.resetTime != LocalTime.midnight) {
      lines.add(
        RuleLine(kind: RuleKind.reset, text: 'O tempo recomeça todo dia às ${limit.resetTime}.'),
      );
    }
  } else {
    lines.add(const RuleLine(kind: RuleKind.dailyLimit, text: 'Sem limite de tempo por dia.'));
  }

  if (policy.allowedHours.enabled) {
    final List<TimeWindow> windows = policy.allowedHours.windowsFor(weekday);
    lines.add(
      RuleLine(
        kind: RuleKind.allowedHours,
        text: windows.isEmpty
            ? 'Hoje não há horário liberado.'
            : 'Horário liberado hoje: '
                  '${_joinList(<String>[for (final TimeWindow w in windows) 'das ${w.start} às ${w.end}'])}.',
      ),
    );
  }

  for (final BlockPeriod period in policy.blockPeriods) {
    final String? text = _blockPeriodText(period, nowMs: status.nowMs);
    if (text != null) {
      lines.add(RuleLine(kind: RuleKind.blockPeriod, text: text));
    }
  }

  if (status.blockedAppsCount > 0) {
    lines.add(
      RuleLine(
        kind: RuleKind.blockedApps,
        text: status.blockedAppsCount == 1
            ? '1 app bloqueado.'
            : '${status.blockedAppsCount} apps bloqueados.',
      ),
    );
  }
  if (policy.apps.defaultForNewApps == NewAppDefault.blocked) {
    lines.add(
      const RuleLine(
        kind: RuleKind.newApps,
        text: 'Apps novos ficam bloqueados até o responsável liberar.',
      ),
    );
  }
  if (policy.web.managedBrowser) {
    lines.add(
      RuleLine(
        kind: RuleKind.web,
        text: policy.web.mode == WebMode.allowlist
            ? 'No Navegador ParentaLynx só abrem os sites liberados pelo responsável.'
            : 'O Navegador ParentaLynx tem filtro de sites.',
      ),
    );
  }
  return lines;
}

int _weekdayOf(AgentStatus status) {
  try {
    return weekdayOfDay(status.day);
  } on FormatException {
    return status.now.weekday;
  }
}

String? _blockPeriodText(BlockPeriod period, {required int nowMs}) {
  if (!period.enabled) {
    return null;
  }
  final String label = period.label.isEmpty ? 'Pausa' : period.label;
  switch (period.kind) {
    case BlockPeriodKind.weekly:
      if (period.days.isEmpty) {
        return null;
      }
      return '$label: ${daysText(period.days)}, das ${period.start} às ${period.end}.';
    case BlockPeriodKind.once:
      final int? startAt = period.startAt;
      final int? endAt = period.endAt;
      if (startAt == null || endAt == null || endAt <= nowMs) {
        return null;
      }
      final DateTime now = DateTime.fromMillisecondsSinceEpoch(nowMs);
      return '$label: começa ${formatReleaseTime(startAt, now: now)} e vai até '
          '${formatClockMs(endAt)}.';
  }
}

/// Dias da semana em texto: "todos os dias", "de segunda a sexta", "sáb e dom".
String daysText(List<int> days) {
  final List<int> sorted = days.toSet().toList()..sort();
  if (sorted.length == 7) {
    return 'todos os dias';
  }
  if (sorted.length == 5 && sorted.first == 1 && sorted.last == 5) {
    return 'de segunda a sexta';
  }
  if (sorted.length == 2 && sorted.first == 6 && sorted.last == 7) {
    return 'sábado e domingo';
  }
  return _joinList(<String>[for (final int day in sorted) weekdayShort(day)]);
}

String _joinList(List<String> parts) {
  if (parts.isEmpty) {
    return '';
  }
  if (parts.length == 1) {
    return parts.first;
  }
  return '${parts.sublist(0, parts.length - 1).join(', ')} e ${parts.last}';
}
