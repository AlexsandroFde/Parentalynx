import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/route_paths.dart';
import '../../../../../shared/design_system/design_system.dart';
import '../../../../child_device/domain/entities/child_device.dart';
import '../../../../child_device/presentation/texts/device_texts.dart';
import '../../../../device_policy/domain/entities/policy.dart';
import '../../../../device_sync/domain/entities/policy_sync_status.dart';
import '../../../domain/entities/active_commands.dart';
import '../../texts/dashboard_texts.dart';

/// Avisos do painel que pedem atencao agora, do mais importante para o menos: controle
/// inativo, bloqueio em vigor (qual regra e quando libera), pausa ou suspensao aguardando o
/// aparelho, pedidos de tempo, problemas de protecao e pedidos de vinculo.
///
/// So aparece o que existe de fato; sem nada a resolver, nao ocupa espaco.
class DashboardNotices extends StatelessWidget {
  const DashboardNotices({
    required this.device,
    required this.commands,
    required this.sync,
    required this.pendingLinks,
    required this.policyLoaded,
    required this.busy,
    required this.now,
    required this.onResume,
    required this.onEndSuspension,
    super.key,
  });

  final ChildDevice device;
  final ActiveCommands commands;
  final PolicySyncStatus sync;

  /// Pedidos de vinculo de outros aparelhos aguardando aprovacao.
  final int pendingLinks;

  /// A politica (comandos em vigor) ja foi carregada.
  final bool policyLoaded;

  /// Um comando esta em andamento: as acoes dos avisos ficam fora de alcance.
  final bool busy;
  final DateTime now;
  final VoidCallback onResume;
  final VoidCallback onEndSuspension;

  @override
  Widget build(BuildContext context) {
    final DeviceSnapshot? snapshot = device.snapshot;
    final String name = device.displayName;
    final List<Widget> banners = <Widget>[];

    void add(DashboardNotice notice, {String? actionLabel, VoidCallback? onAction}) {
      banners.add(
        AppBanner(
          title: notice.title,
          message: notice.message,
          tone: notice.tone,
          icon: notice.icon,
          actionLabel: busy ? null : actionLabel,
          onAction: busy ? null : onAction,
          liveRegion: true,
        ),
      );
    }

    void openDevice() => context.push(GuardianPaths.device(device.id));

    if (snapshot != null && !snapshot.enforcementActive) {
      add(
        (
          title: 'Controle inativo no aparelho',
          message:
              'O aparelho de $name informou que as regras não estão sendo aplicadas. Os '
              'detalhes do aparelho mostram o que falta.',
          tone: Tone.danger,
          icon: AppIcons.protectionOff,
        ),
        actionLabel: 'Ver o aparelho',
        onAction: openDevice,
      );
    }

    final DeviceLockState lock = snapshot?.lockState ?? DeviceLockState.none;
    if (lock == DeviceLockState.manualLock && policyLoaded && !commands.paused) {
      // A pausa foi encerrada aqui, mas o aparelho ainda nao recebeu.
      add((
        title: 'Retomada aguardando o aparelho',
        message: device.online
            ? 'A pausa foi encerrada e o aparelho de $name libera assim que receber.'
            : 'A pausa foi encerrada. O aparelho de $name está sem conexão e libera quando '
                  'voltar a ficar online.',
        tone: Tone.warning,
        icon: AppIcons.pending,
      ));
    } else if (lock.isLocked) {
      add(
        lockNotice(snapshot!, now: now),
        actionLabel: switch (lock) {
          DeviceLockState.manualLock when commands.paused => 'Retomar agora',
          DeviceLockState.tamperLock => 'Ver o aparelho',
          _ => null,
        },
        onAction: lock == DeviceLockState.tamperLock ? openDevice : onResume,
      );
    } else if (commands.paused) {
      add(
        pausePendingNotice(device, until: commands.pausedUntil, now: now),
        actionLabel: 'Cancelar pausa',
        onAction: onResume,
      );
    }

    final Suspension? suspension = commands.suspension;
    if (suspension != null) {
      add(
        suspensionNotice(suspension, pending: sync.isPending, now: now),
        actionLabel: 'Encerrar suspensão',
        onAction: onEndSuspension,
      );
    }

    final int requests = device.pendingTimeRequests;
    if (requests > 0) {
      add(
        (
          title: requests == 1 ? '$name pediu mais tempo' : '$name fez $requests pedidos de tempo',
          message: 'Responda para $name saber se pode continuar.',
          tone: Tone.warning,
          icon: AppIcons.timeRequest,
        ),
        actionLabel: 'Ver pedidos',
        onAction: () => context.go(GuardianPaths.timeRequests),
      );
    }

    final List<String> issues = snapshot?.issues ?? const <String>[];
    if (issues.length == 1) {
      final ({String title, String message}) issue = describeIssue(issues.single);
      add(
        (
          title: issue.title,
          message: issue.message,
          tone: Tone.warning,
          icon: AppIcons.protectionWeak,
        ),
        actionLabel: 'Ver o aparelho',
        onAction: openDevice,
      );
    } else if (issues.length > 1) {
      add(
        (
          title: '${issues.length} problemas na proteção',
          message: '${issues.map((String code) => describeIssue(code).title).join('; ')}.',
          tone: Tone.warning,
          icon: AppIcons.protectionWeak,
        ),
        actionLabel: 'Ver como resolver',
        onAction: openDevice,
      );
    }

    if (pendingLinks > 0) {
      add(
        (
          title: pendingLinks == 1
              ? 'Um aparelho aguarda a sua aprovação'
              : '$pendingLinks aparelhos aguardam a sua aprovação',
          message: 'Confira o número de confirmação nos dois aparelhos antes de aprovar.',
          tone: Tone.info,
          icon: AppIcons.deviceRinging,
        ),
        actionLabel: 'Ver pedido de vínculo',
        onAction: () => context.push(GuardianPaths.pairing),
      );
    }

    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < banners.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            banners[i],
          ],
        ],
      ),
    );
  }
}
