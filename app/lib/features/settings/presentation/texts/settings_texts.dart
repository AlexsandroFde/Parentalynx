import '../../../../core/time/formatters.dart';
import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/domain/entities/guardian_session.dart';
import '../../domain/entities/audit_entry.dart';

/// Textos das telas da aba Mais.

/// Nome mostrado no cabecalho da conta.
String accountTitle(GuardianAccount account) {
  return account.displayName.isEmpty ? 'Responsável' : account.displayName;
}

String pendingLinksLabel(int pendingLinks) {
  return switch (pendingLinks) {
    0 => 'Gerar o código para o aparelho da criança',
    1 => '1 pedido aguardando aprovação',
    _ => '$pendingLinks pedidos aguardando aprovação',
  };
}

String activeDevicesLabel(int count) {
  return switch (count) {
    0 => 'Nenhum aparelho ativo',
    1 => '1 aparelho ativo',
    _ => '$count aparelhos ativos',
  };
}

String pendingTimeRequestsLabel(int count) {
  return count > 0 ? '$count aguardando resposta' : 'Nenhum pedido aguardando';
}

String serverAddressLabel(String address) => address.isEmpty ? 'Não configurado' : address;

String appVersionLabel(String? version) {
  return version == null ? 'Controle parental' : 'Versão $version';
}

/// Nome da sessao na lista de sessoes conectadas.
String sessionTitle(GuardianSessionInfo session) {
  return session.deviceName.isEmpty ? 'Aparelho sem nome' : session.deviceName;
}

/// Nome da sessao no pedido de confirmacao para encerrar.
String sessionNameForRevoke(GuardianSessionInfo session) {
  return session.deviceName.isEmpty ? 'este aparelho' : session.deviceName;
}

String sessionSubtitle(GuardianSessionInfo session, {required DateTime now}) {
  return session.current
      ? 'Este aparelho'
      : 'Último acesso ${formatRelativeMs(session.lastSeenAt, now: now)}';
}

/// Assunto de um registro de alteracoes, a partir do codigo da acao (`policy.update`).
enum AuditTopic { access, rules, devices, account, other }

AuditTopic auditTopicOf(AuditEntry entry) {
  final String action = entry.action;
  if (action.startsWith('auth') || action.startsWith('session')) {
    return AuditTopic.access;
  }
  if (action.startsWith('policy') || action.startsWith('time_request')) {
    return AuditTopic.rules;
  }
  if (action.startsWith('pairing') || action.startsWith('device')) {
    return AuditTopic.devices;
  }
  if (action.startsWith('guardian') || action.startsWith('prefs')) {
    return AuditTopic.account;
  }
  return AuditTopic.other;
}

/// Tentativa recusada (senha errada, chave de recuperacao errada): merece destaque.
bool auditIsFailure(AuditEntry entry) => entry.action.endsWith('_failed');

/// Titulo do registro: a descricao do servidor ou, sem ela, o assunto em palavras comuns (o
/// codigo interno da acao nunca aparece).
String auditTitle(AuditEntry entry) {
  if (entry.summary.isNotEmpty) {
    return entry.summary;
  }
  if (auditIsFailure(entry)) {
    return 'Tentativa recusada';
  }
  return switch (auditTopicOf(entry)) {
    AuditTopic.access => 'Acesso à conta',
    AuditTopic.rules => 'Regras alteradas',
    AuditTopic.devices => 'Aparelhos e vínculos',
    AuditTopic.account => 'Dados da conta',
    AuditTopic.other => 'Alteração na conta',
  };
}

/// Quando, de qual aparelho e de qual endereco de internet veio a alteracao.
String auditSubtitle(AuditEntry entry, {required DateTime now}) {
  return <String>[
    formatRelativeMs(entry.at, now: now),
    ?entry.deviceName,
    if (entry.ip case final String ip) 'IP $ip',
  ].join(' · ');
}

/// Prazo do alerta "aparelho offline": horas ate 47, dias a partir de 48.
String offlineHoursLabel(int hours) => hours < 48 ? '$hours horas' : '${hours ~/ 24} dias';

String retentionDaysLabel(int days) => '$days dias';
