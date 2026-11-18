import '../../../../core/result/result.dart';
import '../entities/child_device.dart';

/// Aparelhos vinculados a conta do responsavel (protocolo, secao 4).
///
/// Guarda a ultima lista em memoria e e a fonte unica de verdade dos aparelhos: o painel, as
/// regras, os relatorios e a vinculacao observam [watchDevices] e ficam coerentes sem
/// conversar entre si. Quem altera um aparelho no servidor atualiza a lista aqui.
abstract interface class IChildDeviceRepository {
  /// Ultima lista carregada, ou nulo antes da primeira carga.
  List<ChildDevice>? get cachedDevices;

  /// Lista atual (quando ja carregada) seguida das mudancas.
  Stream<List<ChildDevice>> watchDevices();

  /// Busca a lista no servidor e avisa quem observa. Em falha, a lista anterior continua.
  Future<Result<List<ChildDevice>>> refresh();

  /// Troca um aparelho na lista sem ir ao servidor (resposta de aprovar ou renomear).
  void upsert(ChildDevice device);

  /// (E) Troca o nome da crianca.
  Future<Result<ChildDevice>> rename(String deviceId, {required String childName});

  /// (E) Revoga o vinculo. O aparelho desativa o controle na proxima sincronizacao.
  Future<Result<void>> revoke(String deviceId);

  /// (E) Apaga o aparelho e todo o historico.
  Future<Result<void>> delete(String deviceId);

  /// (E) Apaga so o historico do aparelho.
  Future<Result<void>> deleteData(String deviceId);

  /// (E) Segredo do codigo de acesso offline, em Base32.
  Future<Result<String>> offlineSecret(String deviceId);

  /// (E) Todos os dados guardados do aparelho, em texto JSON formatado.
  Future<Result<String>> exportData(String deviceId);
}
