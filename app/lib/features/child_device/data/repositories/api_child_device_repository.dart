import '../../../../core/result/result.dart';
import '../../../../core/utils/observable_value.dart';
import '../../domain/entities/child_device.dart';
import '../../domain/repositories/i_child_device_repository.dart';
import '../datasources/remote/child_device_remote_data_source.dart';
import '../dto/child_device_dto.dart';
import '../mappers/child_device_mapper.dart';

/// Aparelhos da conta pela API, com a ultima lista em memoria.
class ApiChildDeviceRepository implements IChildDeviceRepository {
  ApiChildDeviceRepository(this._remote);

  final ChildDeviceRemoteDataSource _remote;
  final ObservableValue<List<ChildDevice>> _devices = ObservableValue<List<ChildDevice>>();

  @override
  List<ChildDevice>? get cachedDevices => _devices.valueOrNull;

  @override
  Stream<List<ChildDevice>> watchDevices() => _devices.stream;

  @override
  Future<Result<List<ChildDevice>>> refresh() async {
    final Result<List<ChildDevice>> result = await Result.guard(() async {
      final List<ChildDeviceDto> dtos = await _remote.list();
      return dtos.map(ChildDeviceMapper.device).toList();
    });
    if (result case Ok<List<ChildDevice>>(:final List<ChildDevice> value)) {
      _devices.add(List<ChildDevice>.unmodifiable(value));
    }
    return result;
  }

  @override
  void upsert(ChildDevice device) {
    final List<ChildDevice>? current = _devices.valueOrNull;
    if (current == null) {
      return;
    }
    final bool known = current.any((ChildDevice item) => item.id == device.id);
    _devices.add(
      List<ChildDevice>.unmodifiable(<ChildDevice>[
        for (final ChildDevice item in current) item.id == device.id ? device : item,
        if (!known) device,
      ]),
    );
  }

  @override
  Future<Result<ChildDevice>> rename(String deviceId, {required String childName}) {
    return Result.guard(() async {
      return ChildDeviceMapper.device(await _remote.rename(deviceId, childName: childName));
    });
  }

  @override
  Future<Result<void>> revoke(String deviceId) => Result.guard(() => _remote.revoke(deviceId));

  @override
  Future<Result<void>> delete(String deviceId) => Result.guard(() => _remote.delete(deviceId));

  @override
  Future<Result<void>> deleteData(String deviceId) {
    return Result.guard(() => _remote.deleteData(deviceId));
  }

  @override
  Future<Result<String>> offlineSecret(String deviceId) {
    return Result.guard(() => _remote.offlineSecret(deviceId));
  }

  @override
  Future<Result<String>> exportData(String deviceId) {
    return Result.guard(() => _remote.exportData(deviceId));
  }
}
