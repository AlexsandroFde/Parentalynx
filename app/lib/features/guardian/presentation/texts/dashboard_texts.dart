/// Textos do painel derivados do estado do aparelho. Funcoes puras.
library;

import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../bloc/dashboard/guardian_dashboard_bloc.dart';

/// Aviso do painel: titulo, explicacao, tom e icone.
typedef DashboardNotice = ({String title, String message, Tone tone, IconData icon});

/// Horario de termino curto: "16:30" hoje, "amanha as 02:00" ou "18/11 as 07:00".
String untilText(int epochMs, {required DateTime now}) {
  final String release = formatReleaseTime(epochMs, now: now);
  return release.startsWith('às ') ? release.substring(3) : release;
}

/// Bloqueio informado pelo aparelho: qual regra bloqueou e quando libera.
///
/// Limite, horario e pausa sao combinados (tom de descanso); so o bloqueio por protecao
/// desativada e um problema.
DashboardNotice lockNotice(DeviceSnapshot snapshot, {required DateTime now}) {
  final int? release = snapshot.lockReleaseAt;
  final String freed = release == null ? '' : 'Libera ${formatReleaseTime(release, now: now)}. ';
  return switch (snapshot.lockState) {
    DeviceLockState.dailyLimit => (
      title: 'Limite diário atingido',
      message: '${freed}Até lá, só as exceções funcionam.',
      tone: Tone.rest,
      icon: AppIcons.timeRunningOut,
    ),
    DeviceLockState.schedule => (
      title: 'Fora do horário permitido',
      message: '${freed}Até lá, só as exceções funcionam.',
      tone: Tone.rest,
      icon: AppIcons.bedtime,
    ),
    DeviceLockState.manualLock => (
      title: 'Pausado por você',
      message: release == null
          ? 'Fica pausado até você retomar. Só as exceções funcionam.'
          : '${freed}Até lá, só as exceções funcionam.',
      tone: Tone.rest,
      icon: AppIcons.pause,
    ),
    DeviceLockState.tamperLock => (
      title: 'Bloqueado por proteção desativada',
      message:
          'Uma permissão do controle foi desativada e o aparelho bloqueou tudo. Ele volta ao '
          'normal quando a permissão for reativada.',
      tone: Tone.danger,
      icon: AppIcons.protectionOff,
    ),
    DeviceLockState.none => (
      title: 'Liberado',
      message: 'Nenhum bloqueio geral em vigor.',
      tone: Tone.success,
      icon: AppIcons.unlock,
    ),
  };
}

/// Pausa salva no servidor que o aparelho ainda nao confirmou.
DashboardNotice pausePendingNotice(ChildDevice device, {int? until, required DateTime now}) {
  final String period = until == null ? 'até você retomar' : 'até ${untilText(until, now: now)}';
  return (
    title: 'Pausa aguardando o aparelho',
    message: device.online
        ? 'A pausa ($period) está salva e começa assim que o aparelho de '
              '${device.displayName} receber.'
        : 'O aparelho de ${device.displayName} está sem conexão. A pausa ($period) começa '
              'quando ele voltar a ficar online.',
    tone: Tone.warning,
    icon: AppIcons.pending,
  );
}

/// Suspensao de regras em vigor. [pending] diz se o aparelho ainda nao confirmou.
DashboardNotice suspensionNotice(
  Suspension suspension, {
  required bool pending,
  required DateTime now,
}) {
  final String scopes = suspension.scopes
      .map((SuspensionScope scope) => scope.label.toLowerCase())
      .join(', ');
  return (
    title: 'Regras suspensas até ${untilText(suspension.until, now: now)}',
    message:
        'Sem valer agora: $scopes.${pending ? ' O aparelho ainda não confirmou a suspensão.' : ''}',
    tone: Tone.info,
    icon: AppIcons.unlock,
  );
}

/// Comeco da mensagem de falha de um comando: qual operacao nao foi feita. O resto vem da
/// falha (o motivo e o que fazer).
String commandFailureLead(DashboardCommandKind kind) {
  return switch (kind) {
    DashboardCommandKind.extraTime => 'O tempo extra não foi enviado.',
    DashboardCommandKind.pause => 'A pausa não foi enviada.',
    DashboardCommandKind.resume => 'A pausa não foi encerrada.',
    DashboardCommandKind.suspend => 'As regras não foram suspensas.',
    DashboardCommandKind.endSuspension => 'A suspensão não foi encerrada.',
  };
}

/// Ajuda do painel, em perguntas e respostas.
const List<HelpTopic> dashboardHelpTopics = <HelpTopic>[
  HelpTopic(
    title: 'Como o tempo é contado?',
    body:
        'O aparelho conta o tempo de tela de cada app. "Usado" é o que desconta do limite de '
        'hoje. "Uso total" inclui os apps liberados como exceção, que não descontam. O limite '
        'recomeça todo dia.',
  ),
  HelpTopic(
    title: 'Quando uma mudança passa a valer?',
    body:
        'Tempo extra, pausa e regras ficam salvos na hora, mas só valem quando o aparelho da '
        'criança recebe e confirma. Até lá o painel mostra "Aguardando o aparelho confirmar". '
        'Sem internet, o aparelho continua com as regras anteriores.',
  ),
  HelpTopic(
    title: 'Qual a diferença entre pausar e suspender?',
    body:
        'Pausar bloqueia o aparelho agora, menos as exceções e as chamadas de emergência. '
        'Suspender faz o limite, os horários ou os bloqueios de apps deixarem de valer por um '
        'tempo. Os dois terminam sozinhos no prazo escolhido ou quando você encerrar.',
  ),
  HelpTopic(
    title: 'O aparelho não sincroniza. O que fazer?',
    body:
        'Confira se o aparelho da criança está com internet e se o ParentaLynx está liberado da '
        'economia de bateria. Os detalhes do aparelho mostram as permissões que faltam.',
  ),
];
