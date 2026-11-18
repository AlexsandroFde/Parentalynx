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
  return pendingLinks > 0
      ? '$pendingLinks pedido(s) aguardando aprovação'
      : 'Gerar código para o aparelho da criança';
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

/// Quando, de qual aparelho e de qual endereco veio a alteracao.
String auditSubtitle(AuditEntry entry, {required DateTime now}) {
  return <String>[formatRelativeMs(entry.at, now: now), ?entry.deviceName, ?entry.ip].join(' · ');
}

/// Prazo do alerta "aparelho offline": horas ate 47, dias a partir de 48.
String offlineHoursLabel(int hours) => hours < 48 ? '$hours horas' : '${hours ~/ 24} dias';

String retentionDaysLabel(int days) => '$days dias';
