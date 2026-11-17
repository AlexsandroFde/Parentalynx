import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/json/json_reader.dart';
import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_providers.dart';
import '../../../../shared/domain/policy.dart';
import '../domain/child_models.dart';
import 'agent_mappers.dart';
import 'native_guard.dart';

/// Credenciais entregues pelo servidor quando o responsavel aprova a vinculacao.
class LinkCredentials {
  const LinkCredentials({
    required this.serverUrl,
    required this.deviceId,
    required this.deviceToken,
    required this.offlineSecret,
    required this.childName,
    required this.guardianName,
  });

  final String serverUrl;
  final String deviceId;
  final String deviceToken;
  final String offlineSecret;
  final String childName;
  final String guardianName;
}

/// Acesso ao agente nativo de controle parental.
///
/// Depois da vinculacao o modo crianca nao fala com o servidor pelo Dart: tudo passa por aqui.
/// Toda falha da ponte sai como `AppFailure`.
class ChildAgentRepository {
  const ChildAgentRepository(this._api);

  final ChildAgentApi _api;

  /// Grava as credenciais recebidas na aprovacao do vinculo, aplica a politica inicial e liga
  /// o controle.
  Future<void> activate(LinkCredentials credentials, int policyVersion, String policyJson) {
    return guardNative(
      () => _api.activate(
        ChildCredentials(
          serverUrl: credentials.serverUrl,
          deviceId: credentials.deviceId,
          deviceToken: credentials.deviceToken,
          offlineSecret: credentials.offlineSecret,
          childName: credentials.childName,
          guardianName: credentials.guardianName,
        ),
        policyVersion,
        policyJson,
      ),
      fallback: 'Não foi possível ligar o controle neste aparelho.',
    );
  }

  /// Garante que o servico do agente esta rodando.
  Future<void> ensureRunning() => guardNative(_api.ensureRunning);

  Future<ChildStatus> status() async => childStatusFrom(await guardNative(_api.getStatus));

  /// Politica em vigor, ou nulo quando nao ha ou quando o texto nao pode ser lido.
  Future<Policy?> policy() async {
    final String? source = await guardNative(_api.getPolicyJson);
    if (source == null || source.isEmpty) {
      return null;
    }
    try {
      return Policy.fromJson(decodeJsonObject(source));
    } on JsonFormatException {
      return null;
    }
  }

  Future<List<AppUsage>> todayUsage() async {
    final List<UsageEntry> entries = await guardNative(_api.getTodayUsage);
    return entries.map(appUsageFrom).toList();
  }

  /// Apps que continuam disponiveis durante um bloqueio geral.
  Future<List<AllowedApp>> exceptionApps() async {
    final List<NativeAppInfo> apps = await guardNative(_api.getExceptionApps);
    return apps.map(allowedAppFrom).toList();
  }

  /// Icone do app em PNG, ou nulo.
  Future<Uint8List?> appIcon(String packageName) {
    return guardNative(() => _api.getAppIcon(packageName));
  }

  Future<SyncResult> syncNow() async => syncResultFrom(await guardNative(_api.syncNow));

  /// Registra um pedido de tempo adicional. Devolve o identificador do pedido.
  Future<String> submitTimeRequest({int? minutes, String? message}) {
    return guardNative(
      () => _api.submitTimeRequest(minutes, message),
      fallback: 'Não foi possível registrar o pedido. Tente de novo.',
    );
  }

  Future<List<TimeRequest>> timeRequests() async {
    final List<TimeRequestInfo> requests = await guardNative(_api.getTimeRequests);
    return requests.map(timeRequestFrom).toList();
  }

  /// Verifica a senha administrativa no servidor.
  Future<AdminAuth> verifyAdminPassword(String password) async {
    return adminAuthFrom(await guardNative(() => _api.verifyAdminPassword(password)));
  }

  /// Verifica localmente o codigo de acesso offline do responsavel.
  Future<AdminAuth> verifyOfflineCode(String code) async {
    return adminAuthFrom(await guardNative(() => _api.verifyOfflineCode(code)));
  }

  /// Verdadeiro enquanto a ultima autenticacao do responsavel ainda vale.
  Future<bool> isAdminAuthValid() => guardNative(_api.isAdminAuthValid);

  /// Libera o uso por alguns minutos. Exige autenticacao do responsavel valida.
  Future<void> grantLocalOverride(int minutes) {
    return guardNative(() => _api.grantLocalOverride(minutes));
  }

  Future<void> clearLocalOverride() => guardNative(_api.clearLocalOverride);

  /// Desvincula o aparelho. Com [password] e conexao o servidor revoga o vinculo. Sem senha a
  /// desativacao e local.
  Future<bool> unlink(String? password) => guardNative(() => _api.unlink(password));

  Future<void> openManagedBrowser([String? url]) {
    return guardNative(
      () => _api.openManagedBrowser(url),
      fallback: 'Não foi possível abrir o navegador.',
    );
  }

  /// Abre um app instalado. Falso se nao foi possivel abrir.
  Future<bool> launchApp(String packageName) => guardNative(() => _api.launchApp(packageName));
}

final Provider<ChildAgentRepository> childAgentRepositoryProvider = Provider<ChildAgentRepository>(
  (Ref ref) => ChildAgentRepository(ref.watch(childAgentApiProvider)),
);
