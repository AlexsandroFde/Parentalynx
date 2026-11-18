import '../../../../core/result/result.dart';
import '../entities/cursor_page.dart';
import '../entities/device_event.dart';
import '../entities/event_group.dart';
import '../repositories/i_reports_repository.dart';

/// Uma pagina dos eventos do aparelho no periodo, filtrados por grupo.
class ListDeviceEvents {
  const ListDeviceEvents(this._repository);

  final IReportsRepository _repository;

  Future<Result<CursorPage<DeviceEvent>>> call(
    String deviceId, {
    required String from,
    required String to,
    EventGroup group = EventGroup.all,
    String? before,
  }) {
    return _repository.events(deviceId, from: from, to: to, types: group.types, before: before);
  }
}
