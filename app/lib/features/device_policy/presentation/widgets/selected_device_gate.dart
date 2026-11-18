import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';

/// Monta uma pagina de regras para o aparelho em foco.
///
/// Enquanto a lista de aparelhos carrega, mostra o carregamento (e nao "nenhum aparelho"); se a
/// lista falhar, oferece tentar de novo; sem aparelho vinculado, explica e leva a vinculacao.
///
/// O BLoC da pagina deve ser criado dentro de [builder] com uma chave pelo identificador do
/// aparelho, para recomecar quando o responsavel escolhe outro aparelho.
class SelectedDeviceGate extends StatelessWidget {
  const SelectedDeviceGate({required this.title, required this.builder, super.key});

  final String title;
  final Widget Function(BuildContext context, ChildDevice device) builder;

  @override
  Widget build(BuildContext context) {
    final DevicesState devices = context.watch<DevicesBloc>().state;
    final ChildDevice? device = devices.selected;
    if (device != null) {
      return builder(context, device);
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StateSwitcher(
        child: switch (devices) {
          DevicesInitial() || DevicesLoading() => const KeyedSubtree(
            key: ValueKey<String>('carregando'),
            child: LoadingState(message: 'Carregando os aparelhos'),
          ),
          DevicesError(:final failure) => KeyedSubtree(
            key: const ValueKey<String>('erro'),
            child: ErrorState.fromError(
              failure,
              subject: 'os aparelhos',
              onRetry: () => context.read<DevicesBloc>().add(const DevicesRefreshRequested()),
            ),
          ),
          DevicesEmpty() || DevicesLoaded() => KeyedSubtree(
            key: const ValueKey<String>('vazio'),
            child: EmptyState(
              icon: AppIcons.deviceUnlinked,
              title: 'Nenhum aparelho vinculado',
              message:
                  'As regras valem para um aparelho. Vincule o celular da criança para '
                  'definir o que ela pode usar.',
              actionLabel: 'Vincular aparelho',
              onAction: () => context.push(GuardianPaths.pairing),
            ),
          ),
        },
      ),
    );
  }
}
