part of 'devices_bloc.dart';

/// Aparelhos da conta e o aparelho em foco.
sealed class DevicesState extends Equatable {
  const DevicesState();

  /// Aparelho em foco, quando ha aparelho ativo.
  ChildDevice? get selected => null;

  /// Aparelhos ativos, na ordem de aprovacao.
  List<ChildDevice> get active => const <ChildDevice>[];

  /// Vinculos aguardando a aprovacao do responsavel.
  List<ChildDevice> get pending => const <ChildDevice>[];

  @override
  List<Object?> get props => const <Object?>[];
}

/// Ainda nao comecou a carregar.
final class DevicesInitial extends DevicesState {
  const DevicesInitial();
}

/// Primeira carga em andamento.
final class DevicesLoading extends DevicesState {
  const DevicesLoading();
}

/// A conta ainda nao tem nenhum aparelho.
final class DevicesEmpty extends DevicesState {
  const DevicesEmpty();
}

/// Lista carregada. Atualizacoes em segundo plano mantem este estado: a lista anterior fica na
/// tela ate a nova chegar.
final class DevicesLoaded extends DevicesState {
  const DevicesLoaded({required this.devices, this.selectedId});

  /// Todos os aparelhos: pendentes, ativos e revogados.
  final List<ChildDevice> devices;

  /// Aparelho escolhido pelo responsavel. Nulo (ou fora da lista) usa o primeiro ativo.
  final String? selectedId;

  @override
  List<ChildDevice> get active {
    return devices.where((ChildDevice device) => device.isActive).toList();
  }

  @override
  List<ChildDevice> get pending {
    return devices.where((ChildDevice device) => device.isPending).toList();
  }

  @override
  ChildDevice? get selected {
    final List<ChildDevice> candidates = active;
    for (final ChildDevice device in candidates) {
      if (device.id == selectedId) {
        return device;
      }
    }
    return candidates.isEmpty ? null : candidates.first;
  }

  /// Um aparelho da lista pelo identificador.
  ChildDevice? byId(String deviceId) {
    for (final ChildDevice device in devices) {
      if (device.id == deviceId) {
        return device;
      }
    }
    return null;
  }

  DevicesLoaded copyWith({List<ChildDevice>? devices, String? selectedId}) {
    return DevicesLoaded(
      devices: devices ?? this.devices,
      selectedId: selectedId ?? this.selectedId,
    );
  }

  @override
  List<Object?> get props => <Object?>[devices, selectedId];
}

/// A primeira carga falhou. A tela oferece tentar de novo.
final class DevicesError extends DevicesState {
  const DevicesError(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}
