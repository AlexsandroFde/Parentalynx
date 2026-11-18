import '../../../../core/result/result.dart';
import '../entities/browser_settings.dart';
import '../entities/browser_visit.dart';
import '../entities/navigation_verdict.dart';

/// Filtro de sites e historico do navegador gerenciado.
///
/// A decisao fica no agente nativo, que aplica a politica mesmo com a interface fechada: o
/// navegador so pergunta e obedece.
abstract interface class IWebFilterService {
  /// Configuracao atual do navegador.
  Future<Result<BrowserSettings>> settings();

  /// Decide se a navegacao de pagina principal para [url] pode prosseguir.
  Future<Result<NavigationVerdict>> evaluate(String url);

  /// Registra uma pagina aberta ou barrada no historico enviado ao responsavel.
  Future<Result<void>> recordVisit(BrowserVisit visit);
}
