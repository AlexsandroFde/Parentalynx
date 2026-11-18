import '../../../../core/result/result.dart';
import '../entities/browsing_entry.dart';
import '../entities/cursor_page.dart';
import '../repositories/i_reports_repository.dart';

/// Uma pagina do historico do navegador gerenciado no periodo.
///
/// So existe historico do navegador ParentaLynx: paginas abertas em outros navegadores ou apps
/// nao sao registradas.
class ListBrowsingHistory {
  const ListBrowsingHistory(this._repository);

  final IReportsRepository _repository;

  Future<Result<CursorPage<BrowsingEntry>>> call(
    String deviceId, {
    required String from,
    required String to,
    String? before,
  }) {
    return _repository.browsing(deviceId, from: from, to: to, before: before);
  }
}
