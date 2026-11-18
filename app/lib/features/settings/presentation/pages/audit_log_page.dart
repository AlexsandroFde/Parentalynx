import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/clock.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../domain/entities/audit_entry.dart';
import '../bloc/audit_log/audit_log_bloc.dart';
import '../texts/settings_texts.dart';

/// Registro de alteracoes administrativas da conta, do mais novo para o mais antigo.
///
/// Espera um [AuditLogBloc] acima na arvore.
class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de alterações')),
      body: BlocBuilder<AuditLogBloc, AuditLogState>(
        builder: (BuildContext context, AuditLogState state) {
          return switch (state) {
            AuditLogLoading() => const LoadingView(),
            AuditLogError(:final failure) => FailureView(
              error: failure,
              onRetry: () => context.read<AuditLogBloc>().add(const AuditLogLoadRequested()),
            ),
            AuditLogEmpty() => const EmptyState(
              icon: Icons.history,
              title: 'Nenhuma alteração registrada',
              message: 'Mudanças de regras, vínculos e acessos à conta aparecem aqui.',
            ),
            AuditLogLoaded() => _AuditList(state: state),
          };
        },
      ),
    );
  }
}

class _AuditList extends StatelessWidget {
  const _AuditList({required this.state});

  final AuditLogLoaded state;

  static IconData _iconFor(String action) {
    if (action.startsWith('auth') || action.startsWith('session')) {
      return Icons.login;
    }
    if (action.startsWith('policy')) {
      return Icons.tune;
    }
    if (action.startsWith('pairing') || action.startsWith('device')) {
      return Icons.smartphone_outlined;
    }
    if (action.startsWith('guardian') || action.startsWith('account')) {
      return Icons.person_outline;
    }
    return Icons.history;
  }

  void _loadMore(BuildContext context) {
    context.read<AuditLogBloc>().add(const AuditLogMoreRequested());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = context.read<Clock>().now();
    final List<AuditEntry> entries = state.entries;
    return PageBody(
      children: <Widget>[
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (int index = 0; index < entries.length; index++) ...<Widget>[
                if (index > 0) const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(_iconFor(entries[index].action)),
                  title: Text(entries[index].title),
                  subtitle: Text(auditSubtitle(entries[index], now: now)),
                ),
              ],
            ],
          ),
        ),
        if (state.moreFailure != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          NoticeBanner(
            tone: Tone.danger,
            message: 'Não foi possível carregar mais registros.',
            actionLabel: 'Tentar de novo',
            onAction: () => _loadMore(context),
          ),
        ],
        if (state.hasMore && state.moreFailure == null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Center(
              child: state.loadingMore
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : TextButton(
                      onPressed: () => _loadMore(context),
                      child: const Text('Carregar mais antigos'),
                    ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'O registro guarda as alterações dos últimos 365 dias.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
