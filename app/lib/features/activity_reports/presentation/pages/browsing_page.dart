import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../domain/entities/browsing_entry.dart';
import '../bloc/browsing_history/browsing_history_bloc.dart';
import '../texts/event_texts.dart';
import '../widgets/paged_list_view.dart';

/// Historico de navegacao do navegador gerenciado, com o que foi bloqueado e o motivo.
///
/// Espera um [BrowsingHistoryBloc] acima na arvore.
class BrowsingPage extends StatelessWidget {
  const BrowsingPage({super.key});

  static const String title = 'Histórico de navegação';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BrowsingHistoryState state = context.watch<BrowsingHistoryBloc>().state;
    final BrowsingHistoryBloc bloc = context.read<BrowsingHistoryBloc>();
    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Só o que foi aberto no navegador ParentaLynx.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                FilterChip(
                  label: const Text('Só bloqueados'),
                  selected: state.onlyBlocked,
                  onSelected: (bool value) {
                    bloc.add(BrowsingHistoryOnlyBlockedChanged(onlyBlocked: value));
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: PagedListView<BrowsingEntry>(
              state: state.list,
              onRetry: () => bloc.add(const BrowsingHistoryRetried()),
              onLoadMore: () => bloc.add(const BrowsingHistoryMoreRequested()),
              emptyIcon: Icons.travel_explore,
              emptyTitle: 'Nenhuma página registrada',
              emptyMessage:
                  'O histórico existe só para o navegador ParentaLynx. Páginas abertas em '
                  'outros navegadores ou apps não são registradas.',
              itemBuilder: (BuildContext context, BrowsingEntry entry) {
                final DateTime now = context.read<Clock>().now();
                if (!state.shows(entry)) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            entry.displayTitle,
                            style: theme.textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            entry.url,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  formatRelativeMs(entry.ts, now: now),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              if (entry.blocked)
                                StatusPill(
                                  label: browsingReasonLabel(entry.reason),
                                  tone: Tone.danger,
                                  icon: Icons.block,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
