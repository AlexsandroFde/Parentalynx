import 'dart:typed_data';

import '../../../../core/result/result.dart';
import '../../domain/entities/app_entry.dart';
import '../../domain/repositories/i_app_inventory_repository.dart';
import '../datasources/remote/app_inventory_remote_data_source.dart';
import '../mappers/app_entry_mapper.dart';

/// Inventario de apps pela API.
class ApiAppInventoryRepository implements IAppInventoryRepository {
  const ApiAppInventoryRepository(this._remote);

  final AppInventoryRemoteDataSource _remote;

  @override
  Future<Result<DeviceApps>> listApps(String deviceId) {
    return Result.guard(() async => AppEntryMapper.deviceApps(await _remote.listApps(deviceId)));
  }

  @override
  Future<Result<Uint8List?>> fetchIcon(String iconPath) {
    return Result.guard<Uint8List?>(() async {
      final Uint8List bytes = await _remote.fetchIcon(iconPath);
      return bytes.isEmpty ? null : bytes;
    });
  }
}
