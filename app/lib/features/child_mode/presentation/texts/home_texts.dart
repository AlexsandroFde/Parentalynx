/// Textos da tela inicial da crianca, em funcoes puras para poderem ser testados sem a
/// interface. A linguagem e simples e sem tom de castigo: cada restricao diz o motivo e quando
/// acaba.
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

/// Nome do responsavel no comeco de uma frase.
String _guardianTitle(AgentStatus status) {
  return status.guardianName.isEmpty ? 'Seu responsável' : status.guardianName;
}

/// Mensagem do bloqueio em vigor, ou nulo quando o aparelho esta liberado.
///
/// Diz o motivo e quando acaba ("Hora de dormir. O aparelho volta amanha as 07:00.").
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
        body: release == null ? 'Amanhã tem tempo de novo.' : 'O tempo volta $release.',
      );
    case ChildLock.schedule:
      final String? label = status.activeScheduleLabel;
      return LockMessage(
        title: label == null || label.isEmpty ? 'Hora de descansar' : label,
        body: release == null
            ? 'O aparelho volta quando a pausa acabar.'
            : 'O aparelho volta $release.',
      );
    case ChildLock.manualLock:
      final String guardian = _guardian(status);
      return LockMessage(
        title: 'Aparelho em pausa',
        body: release == null
            ? '${_guardianTitle(status)} pausou o aparelho por enquanto. Se precisar usar, fale '
                  'com $guardian.'
            : '${_guardianTitle(status)} pausou o aparelho. Ele volta $release.',
      );
    case ChildLock.tamperLock:
      return LockMessage(
        title: 'O controle precisa de atenção',
        body:
            'Uma permissão do controle foi desligada. Ligue de novo para liberar os apps, ou '
            'peça ajuda a ${_guardian(status)}.',
      );
  }
}

/// O que continua funcionando durante um bloqueio.
const String lockedStillWorks =
    'Os apps sempre liberados e as ligações de emergência continuam funcionando.';

/// Numeros e textos do tempo de hoje.
class TimeDisplay {
  const TimeDisplay({
    required this.parts,
    required this.caption,
    required this.detail,
    required this.spoken,
    required this.progress,
    required this.level,
  });

  /// Valor em destaque, em partes de numero e unidade (`1` `h`, `20` `min`).
  final List<(String, String)> parts;
  final String caption;
  final String detail;

  /// Frase completa para o leitor de tela.
  final String spoken;

  /// Fracao da cota ja usada, de 0 a 1.
  final double progress;
  final TimeLevel level;

  /// Valor em destaque em texto corrido: `1h 20min`.
  String get headline => parts.map(((String, String) part) => '${part.$1}${part.$2}').join(' ');
}

/// Quanto da cota ainda resta, para a cor do anel. O valor em texto sempre acompanha.
enum TimeLevel { unlimited, plenty, low, over }

/// Minutos que restam, arredondados para cima: o tempo so chega a zero quando acaba de fato.
int _remainingMinutes(int ms) => ms <= 0 ? 0 : (ms + 59999) ~/ 60000;

/// Partes de uma duracao em minutos para o numero em destaque.
List<(String, String)> durationParts(int minutes) {
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  return <(String, String)>[
    if (hours > 0) ('$hours', 'h'),
    if (rest > 0 || hours == 0) ('$rest', 'min'),
  ];
}

/// Duracao por extenso, para o leitor de tela: `1 hora e 20 minutos`.
String spokenMinutes(int minutes) {
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  final List<String> words = <String>[
    if (hours > 0) hours == 1 ? '1 hora' : '$hours horas',
    if (rest > 0 || hours == 0) rest == 1 ? '1 minuto' : '$rest minutos',
  ];
  return words.join(' e ');
}

TimeDisplay timeDisplay(AgentStatus status) {
  if (!status.hasQuota) {
    final String used = formatDurationMs(status.totalUsedMs);
    return TimeDisplay(
      parts: const <(String, String)>[('Sem limite', '')],
      caption: 'de tempo hoje',
      detail: 'Você usou $used hoje.',
      spoken: 'Sem limite de tempo hoje. Você usou $used.',
      progress: 0,
      level: TimeLevel.unlimited,
    );
  }
  final int remaining = status.remainingMs;
  final int minutes = _remainingMinutes(remaining);
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
    parts: durationParts(minutes),
    caption: 'para usar hoje',
    detail:
        'Você usou ${formatDurationMs(status.quotaUsedMs)} de '
        '${formatDurationMs(status.limitMs)}$extra.',
    spoken: remaining <= 0
        ? 'O tempo de hoje acabou.'
        : 'Restam ${spokenMinutes(minutes)} para usar hoje, de '
              '${spokenMinutes(status.limitMs ~/ 60000)}.',
    progress: status.usedFraction,
    level: level,
  );
}

/// Dica gentil quando o tempo esta acabando.
const String lowTimeHint = 'Falta pouco: um bom momento para terminar o que está fazendo.';

/// Quando o tempo do dia recomeca.
String resetText(AgentStatus status) {
  return 'O tempo recomeça ${formatReleaseTime(status.nextResetAtMs, now: status.now)}.';
}

/// Regras liberadas pelo responsavel por um tempo (liberacao no aparelho ou suspensao).
class ReliefMessage {
  const ReliefMessage({required this.title, required this.body});

  final String title;
  final String body;
}

/// Aviso de uso liberado ou de regras suspensas pelo responsavel, ou nulo quando nao ha.
ReliefMessage? reliefMessage(AgentStatus status) {
  if (status.localOverrideActive) {
    return ReliefMessage(
      title: 'Uso liberado até ${formatClockMs(status.localOverrideUntilMs)}',
      body: '${_guardianTitle(status)} liberou o aparelho por um tempo.',
    );
  }
  if (status.suspensionActive) {
    final List<String> parts = <String>[
      for (final SuspensionScope scope in status.suspensionScopes)
        switch (scope) {
          SuspensionScope.dailyLimit => 'o limite de tempo',
          SuspensionScope.schedules => 'os horários de pausa',
          SuspensionScope.appBlocks => 'os apps bloqueados',
        },
    ];
    final String scope = parts.isEmpty ? 'algumas regras' : _joinList(parts);
    return ReliefMessage(
      title: 'Regras liberadas até ${formatClockMs(status.suspensionUntilMs)}',
      body: '${_guardianTitle(status)} liberou $scope.',
    );
  }
  return null;
}

/// Proxima pausa programada, quando o aparelho esta liberado e ha uma.
String? nextPauseText(AgentStatus status) {
  final int? at = status.nextBlockAtMs;
  if (at == null || status.isLocked) {
    return null;
  }
  final String? label = status.nextBlockLabel;
  final String name = label == null || label.isEmpty ? 'A próxima pausa' : label;
  return '$name começa ${formatReleaseTime(at, now: status.now)}.';
}

/// Codigos de problema que se resolvem ligando uma permissao do controle.
const Set<String> _permissionIssues = <String>{
  'accessibility_disabled',
  'usage_access_missing',
  'overlay_missing',
  'notifications_disabled',
  'battery_optimized',
};

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
    'clock_untrusted' =>
      'A hora do aparelho não pôde ser conferida. Deixe a data e a hora automáticas.',
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

/// Verdadeiro quando algum problema se resolve na tela de permissoes.
bool attentionNeedsPermissions(AgentStatus status) {
  return status.issues.any(_permissionIssues.contains);
}

/// Estado das regras entre o aparelho e o responsavel.
class ConnectionText {
  const ConnectionText({required this.title, required this.detail, required this.ok});

  final String title;
  final String detail;
  final bool ok;
}

ConnectionText connectionText(AgentStatus status) {
  final int? last = status.lastSyncAtMs;
  if (last == null) {
    return const ConnectionText(
      title: 'As regras ainda não chegaram',
      detail: 'Elas chegam quando o aparelho tiver internet.',
      ok: false,
    );
  }
  final String when = formatRelativeMs(last, now: status.now);
  if (status.lastSyncOk) {
    return ConnectionText(title: 'Regras em dia', detail: 'Atualizadas $when.', ok: true);
  }
  return ConnectionText(
    title: 'Sem internet agora',
    detail: 'As regras continuam valendo. Última atualização: $when.',
    ok: false,
  );
}

/// Mensagem para o resultado de "Atualizar agora".
String syncResultMessage(DeviceSyncResult result) {
  if (result.ok) {
    return 'Pronto: as regras estão em dia.';
  }
  return switch (result.errorCode) {
    'network' => 'Sem internet agora. As regras de antes continuam valendo.',
    'device_revoked' => 'O vínculo deste aparelho foi removido pelo responsável.',
    _ => 'Não foi possível atualizar agora. Tente de novo.',
  };
}

/// Aviso depois de registrar um pedido de tempo.
const String timeRequestSentMessage = 'Pedido enviado. Você vê a resposta aqui.';

/// Aviso quando um app sempre liberado nao abriu.
String launchFailedMessage(String label) => 'Não foi possível abrir $label. Tente de novo.';

/// Tipo de uma linha do resumo de regras, para a tela escolher o icone e o tom.
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
