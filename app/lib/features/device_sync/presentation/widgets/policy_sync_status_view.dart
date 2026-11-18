import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/policy_sync_status.dart';

/// Mostra se a versao atual das regras ja vale no aparelho.
///
/// Toda alteracao e salva no servidor e so depois aplicada pelo aparelho, que confirma a
/// versao recebida. Enquanto a confirmacao nao chega o estado e "aguardando", e com o aparelho
/// sem conexao a tela diz que as regras anteriores continuam valendo ate ele voltar. O app
/// nunca apresenta como aplicada uma regra que o aparelho nao confirmou.
class PolicySyncStatusView extends StatelessWidget {
  const PolicySyncStatusView({required this.status, this.now, super.key});

  final PolicySyncStatus status;

  /// Momento de referencia para o texto relativo. So para testes.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    if (!status.isPending) {
      final int? appliedAt = status.appliedAt;
      return SyncStatusLine(
        state: SyncState.applied,
        label: 'Regras aplicadas no aparelho',
        detail: appliedAt == null
            ? 'O aparelho confirmou a versão atual.'
            : 'Confirmado ${formatRelativeMs(appliedAt, now: now)}.',
      );
    }
    if (!status.deviceOnline) {
      return const SyncStatusLine(
        state: SyncState.offline,
        label: 'Aguardando o aparelho se conectar',
        detail:
            'As regras novas estão salvas e serão aplicadas quando ele voltar a ficar online. '
            'Até lá, valem as regras anteriores.',
      );
    }
    return const SyncStatusLine(
      state: SyncState.pending,
      label: 'Aguardando o aparelho confirmar',
      detail: 'As regras foram salvas e serão aplicadas em instantes.',
    );
  }
}
