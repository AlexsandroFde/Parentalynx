import 'dart:typed_data';

import '../../../../core/result/result.dart';
import '../repositories/i_app_inventory_repository.dart';

/// Icone de um app do inventario, em PNG.
class GetAppIcon {
  const GetAppIcon(this._repository);

  final IAppInventoryRepository _repository;

  Future<Result<Uint8List?>> call(String iconPath) => _repository.fetchIcon(iconPath);
}
