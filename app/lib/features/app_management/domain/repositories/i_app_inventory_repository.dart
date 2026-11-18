import 'dart:typed_data';

import '../../../../core/result/result.dart';
import '../entities/app_entry.dart';

/// Inventario de apps dos aparelhos (protocolo, secao 5.1), visto pelo responsavel.
abstract interface class IAppInventoryRepository {
  /// Apps instalados em um aparelho, com o uso de hoje e da semana e o estado na politica.
  Future<Result<DeviceApps>> listApps(String deviceId);

  /// Icone de um app em PNG, pelo caminho informado no inventario. Nulo quando nao ha.
  Future<Result<Uint8List?>> fetchIcon(String iconPath);
}
