import 'package:material_ui/material_ui.dart';

import '../../../../../core/time/formatters.dart';
import '../../../../../shared/widgets/feedback_views.dart';
import '../../../../child_device/domain/entities/child_device.dart';

/// Aviso de bloqueio geral: o motivo informado pelo aparelho, ou a pausa enviada e ainda nao
/// confirmada, com a liberacao prevista.
class DashboardLockBanner extends StatelessWidget {
  const DashboardLockBanner({
    required this.snapshot,
    required this.paused,
    required this.now,
    required this.onResume,
    super.key,
  });

  final DeviceSnapshot snapshot;

  /// Ha uma pausa do responsavel em vigor.
  final bool paused;
  final DateTime now;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final bool reported = snapshot.lockState.isLocked;
    final int? release = snapshot.lockReleaseAt;
    final String title = reported ? snapshot.lockState.label : DeviceLockState.manualLock.label;
    final String message;
    if (!reported) {
      message = 'Pausa enviada. Aguardando o aparelho confirmar.';
    } else if (release != null) {
      message = 'Liberação prevista ${formatReleaseTime(release, now: now)}.';
    } else if (snapshot.lockState == DeviceLockState.manualLock) {
      message = 'Fica pausado até você retomar.';
    } else {
      message = 'Só as exceções estão disponíveis.';
    }
    return NoticeBanner(
      tone: Tone.danger,
      icon: Icons.lock_outline,
      title: title,
      message: message,
      actionLabel: paused ? 'Retomar agora' : null,
      onAction: paused ? onResume : null,
    );
  }
}
