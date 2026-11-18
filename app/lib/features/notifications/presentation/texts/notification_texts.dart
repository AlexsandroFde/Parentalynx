import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../domain/entities/alert_type.dart';

/// Texto unico sobre a entrega dos alertas, usado em mais de uma tela para nao prometer mais
/// do que o app entrega.
const String alertDeliveryNote =
    'Com o app aberto, os alertas chegam na hora. Com o app fechado, o aparelho busca novos '
    'alertas em segundo plano e eles podem levar até cerca de 15 minutos para aparecer.';

/// Para que servem as notificacoes (pedido de permissao e ajuda).
const String notificationRationale =
    'O ParentaLynx avisa quando o limite do dia acaba, quando a criança pede mais tempo e '
    'quando alguma proteção do aparelho é desativada. Com o app fechado, os avisos podem levar '
    'até cerca de 15 minutos para chegar.';

/// Ajuda da central de alertas e das preferencias.
const List<HelpTopic> alertsHelpTopics = <HelpTopic>[
  HelpTopic(
    title: 'De onde vêm os alertas?',
    body:
        'O aparelho da criança informa o servidor quando o limite acaba, quando ela pede mais '
        'tempo, quando tenta abrir um app bloqueado ou quando uma proteção muda. O servidor '
        'gera o alerta para todos os responsáveis da conta.',
  ),
  HelpTopic(title: 'Quanto tempo demoram?', body: alertDeliveryNote),
  HelpTopic(
    title: 'Lido e não lido',
    body:
        'Alertas novos aparecem com a etiqueta "Novo" e o título em destaque. Abrir um alerta '
        'marca como lido. Marcar como lido não apaga nada: o alerta continua na lista.',
  ),
  HelpTopic(
    title: 'Desligar um tipo de aviso',
    body:
        'Nas preferências de notificação você escolhe quais tipos geram notificação. Um tipo '
        'desligado continua aparecendo aqui, só não toca no celular.',
  ),
];

/// Pedidos de tempo aguardando resposta, somando os aparelhos ativos.
int pendingTimeRequestsOf(List<ChildDevice> activeDevices) {
  return activeDevices.fold<int>(
    0,
    (int total, ChildDevice device) => total + device.pendingTimeRequests,
  );
}

/// Rotulo do dia de um alerta na central: `Hoje`, `Ontem`, `seg 16/11` ou `16/11/2025`.
String alertDayLabel(DateTime time, {required DateTime now}) {
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime day = DateTime(time.year, time.month, time.day);
  // Arredonda as horas: dias com mudanca de horario de verao tem 23 ou 25 horas.
  final int gap = (today.difference(day).inHours / 24).round();
  if (gap == 0) {
    return 'Hoje';
  }
  if (gap == 1) {
    return 'Ontem';
  }
  if (time.year != now.year) {
    return '${formatShortDate(time)}/${time.year}';
  }
  return '${weekdayShort(time.weekday)} ${formatShortDate(time)}';
}

/// Quando o alerta chegou, para o detalhe: `hoje às 15:27`, `ontem às 09:10`,
/// `seg 16/11 às 08:00`.
String alertMomentLabel(DateTime time, {required DateTime now}) {
  final String day = alertDayLabel(time, now: now);
  final String lead = day == 'Hoje' || day == 'Ontem' ? day.toLowerCase() : day;
  return '$lead às ${formatClock(time)}';
}

/// Contagem de alertas novos: `1 alerta novo`, `3 alertas novos`.
String unreadAlertsLabel(int unread) {
  return unread == 1 ? '1 alerta novo' : '$unread alertas novos';
}

/// Grupo de tipos de alerta nas preferencias, com a consequencia de desligar.
class AlertPreferenceGroup {
  const AlertPreferenceGroup({required this.title, required this.types, required this.footer});

  final String title;
  final List<AlertType> types;
  final String footer;
}

/// Os tipos de alerta organizados por assunto. Cobre todos os tipos de [AlertType].
const List<AlertPreferenceGroup> alertPreferenceGroups = <AlertPreferenceGroup>[
  AlertPreferenceGroup(
    title: 'Tempo de uso',
    types: <AlertType>[AlertType.timeRequest, AlertType.lowTime, AlertType.limitReached],
    footer:
        'Desligado, o pedido de tempo continua esperando a sua resposta em Alertas, mas você '
        'não recebe o aviso no celular.',
  ),
  AlertPreferenceGroup(
    title: 'Aplicativos',
    types: <AlertType>[AlertType.blockedAppAttempt, AlertType.newAppInstalled],
    footer:
        'Desligados, as tentativas e as instalações continuam registradas em Relatórios, '
        'Eventos do aparelho.',
  ),
  AlertPreferenceGroup(
    title: 'Aparelho e proteção',
    types: <AlertType>[
      AlertType.enforcementFailure,
      AlertType.permissionChanged,
      AlertType.securityEvent,
      AlertType.deviceOffline,
      AlertType.syncStale,
    ],
    footer:
        'Recomendado manter ligados: avisam quando as regras podem ter deixado de valer no '
        'aparelho da criança.',
  ),
  AlertPreferenceGroup(
    title: 'Conta',
    types: <AlertType>[AlertType.policyChanged, AlertType.deviceLinked],
    footer: 'Mudanças feitas por outro responsável ou em outro celular da conta.',
  ),
];
