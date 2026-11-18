import 'package:equatable/equatable.dart';

import '../../../child_device/domain/entities/child_device.dart';

/// Contagens dos aparelhos da conta para a aba Mais.
final class DevicesOverview extends Equatable {
  const DevicesOverview({
    required this.activeDevices,
    required this.pendingLinks,
    required this.pendingTimeRequests,
  });

  /// Resume os aparelhos ativos e os vinculos pendentes.
  factory DevicesOverview.of({
    required List<ChildDevice> active,
    required List<ChildDevice> pending,
  }) {
    return DevicesOverview(
      activeDevices: active.length,
      pendingLinks: pending.length,
      // Pedidos de tempo aguardando resposta, somando os aparelhos ativos.
      pendingTimeRequests: active.fold<int>(
        0,
        (int total, ChildDevice device) => total + device.pendingTimeRequests,
      ),
    );
  }

  static const DevicesOverview empty = DevicesOverview(
    activeDevices: 0,
    pendingLinks: 0,
    pendingTimeRequests: 0,
  );

  final int activeDevices;

  /// Vinculos aguardando a aprovacao do responsavel.
  final int pendingLinks;
  final int pendingTimeRequests;

  @override
  List<Object?> get props => <Object?>[activeDevices, pendingLinks, pendingTimeRequests];
}
