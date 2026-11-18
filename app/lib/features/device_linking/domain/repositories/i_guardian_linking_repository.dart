import '../../../../core/result/result.dart';
import '../entities/link_code.dart';
import '../entities/link_request.dart';
import '../entities/linking_overview.dart';

/// Vinculacao vista pelo responsavel: codigos e pedidos de vinculo (protocolo, secao 3).
///
/// Guarda em memoria o ultimo codigo gerado, enquanto o app estiver aberto: o servidor guarda
/// so o hash, entao o texto so pode ser mostrado de novo se ficar aqui. Assim o codigo continua
/// na tela quando a pessoa sai da pagina e volta.
abstract interface class IGuardianLinkingRepository {
  /// Codigo gerado nesta abertura do app e ainda nao descartado.
  LinkCode? get shownCode;

  /// (E) Gera um codigo novo, que passa a ser o mostrado. O anterior deixa de valer.
  Future<Result<LinkCode>> createCode();

  /// Codigo ativo no servidor e pedidos aguardando aprovacao.
  Future<Result<LinkingOverview>> overview();

  /// Cancela o codigo no servidor. Com sucesso, ele deixa de ser o mostrado.
  Future<Result<void>> cancelCode(String codeId);

  /// Deixa de mostrar o codigo (venceu ou foi usado), sem falar com o servidor.
  void forgetCode(String codeId);

  /// (E) Aprova o pedido dando nome a crianca. Devolve o aparelho vinculado, que pode ter o
  /// identificador do cadastro antigo quando o aparelho ja era conhecido da conta.
  Future<Result<LinkRequest>> approve(String requestId, {required String childName});

  /// Rejeita o pedido.
  Future<Result<void>> reject(String requestId);
}
