import '../../../../core/json/json_reader.dart';
import '../../auth/domain/guardian_account.dart';

/// Registro de auditoria administrativa (protocolo, secao 2.5).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.action,
    required this.summary,
    this.deviceName,
    this.targetType,
    this.ip,
  });

  factory AuditEntry.fromJson(JsonMap json) {
    return AuditEntry(
      id: json.integer('id'),
      at: json.intOr('at', fallback: 0),
      action: json.strOrNull('action') ?? '',
      summary: json.strOrNull('summary') ?? '',
      deviceName: json.strOrNull('deviceName'),
      targetType: json.strOrNull('targetType'),
      ip: json.strOrNull('ip'),
    );
  }

  final int id;
  final int at;

  /// Codigo da acao, por exemplo `policy.update` ou `auth.login`.
  final String action;

  /// Descricao pronta em portugues.
  final String summary;

  /// Aparelho do responsavel que fez a alteracao.
  final String? deviceName;
  final String? targetType;
  final String? ip;
}

class AuditPage {
  const AuditPage({required this.entries, this.nextBefore});

  factory AuditPage.fromJson(JsonMap json) {
    return AuditPage(
      entries: json.objList('entries').map(AuditEntry.fromJson).toList(),
      nextBefore: json.intOrNull('nextBefore'),
    );
  }

  final List<AuditEntry> entries;

  /// Cursor da pagina seguinte, ou nulo quando nao ha mais registros.
  final int? nextBefore;
}

/// Gestao da conta: perfil, senha, chave de recuperacao, sessoes, auditoria e exclusao.
abstract interface class AccountRepository {
  /// (E) Altera o nome de exibicao ou os ajustes da conta.
  Future<GuardianAccount> updateProfile({String? displayName, GuardianSettings? settings});

  /// Troca a senha. As outras sessoes da conta sao encerradas.
  Future<void> changePassword({required String currentPassword, required String newPassword});

  /// Gera uma nova chave de recuperacao. A anterior deixa de valer.
  Future<String> regenerateRecoveryKey(String password);

  Future<List<GuardianSessionInfo>> listSessions();

  /// (E) Encerra a sessao de outro aparelho.
  Future<void> revokeSession(String sessionId);

  /// Apaga a conta e todos os dados.
  Future<void> deleteAccount(String password);

  Future<AuditPage> audit({int? before, int limit = 30});
}
