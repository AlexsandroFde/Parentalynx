import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../domain/entities/policy_sync_status.dart';

/// Mostra se a versao atual das regras ja foi confirmada pelo aparelho.
///
/// Toda alteracao e enviada ao servidor e so depois aplicada pelo aparelho, que confirma a
/// versao recebida. Enquanto a confirmacao nao chega, o estado fica como pendente.
class PolicySyncStatusView extends StatelessWidget {
  const PolicySyncStatusView({required this.status, this.now, super.key});

  final PolicySyncStatus status;

  /// Momento de referencia para o texto relativo. So para testes.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool pending = status.isPending;
    final Tone tone = pending ? Tone.info : Tone.success;
    final String title = pending
        ? 'Aguardando o aparelho confirmar'
        : 'Regras aplicadas no aparelho';
    final String detail;
    if (pending) {
      detail = status.deviceOnline
          ? 'As regras foram enviadas e serão aplicadas em instantes.'
          : 'O aparelho está offline. As regras serão aplicadas quando ele se conectar.';
    } else {
      final int? appliedAt = status.appliedAt;
      detail = appliedAt == null
          ? 'O aparelho confirmou a versão atual.'
          : 'Confirmado ${formatRelativeMs(appliedAt, now: now)}.';
    }
    return Semantics(
      container: true,
      label: '$title. $detail',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: tone.background(context),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                pending ? Icons.sync : Icons.check_circle_outline,
                size: 20,
                color: tone.foreground(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
