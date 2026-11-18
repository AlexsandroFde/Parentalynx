import 'package:material_ui/material_ui.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../bloc/paging/paged_list.dart';

/// Lista paginada com os estados de carregamento, erro, vazio e "carregar mais".
class PagedListView<T> extends StatelessWidget {
  const PagedListView({
    required this.state,
    required this.itemBuilder,
    required this.onRetry,
    required this.onLoadMore,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    super.key,
  });

  final PagedListState<T> state;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Tentar de novo depois de uma falha (da primeira pagina ou da seguinte).
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      PagedListLoading<T>() => const LoadingView(),
      PagedListError<T>(:final failure) => FailureView(error: failure, onRetry: onRetry),
      PagedListEmpty<T>() => EmptyState(icon: emptyIcon, title: emptyTitle, message: emptyMessage),
      final PagedListLoaded<T> loaded => _list(context, loaded),
    };
  }

  Widget _list(BuildContext context, PagedListLoaded<T> loaded) {
    final List<T> items = loaded.items;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: items.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index < items.length) {
              return itemBuilder(context, items[index]);
            }
            if (loaded.moreFailure != null) {
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: NoticeBanner(
                  tone: Tone.warning,
                  message: 'Não foi possível carregar mais itens.',
                  actionLabel: 'Tentar de novo',
                  onAction: onRetry,
                ),
              );
            }
            if (!loaded.hasMore) {
              return const SizedBox(height: AppSpacing.lg);
            }
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Center(
                child: loaded.loadingMore
                    ? const CircularProgressIndicator()
                    : OutlinedButton(onPressed: onLoadMore, child: const Text('Carregar mais')),
              ),
            );
          },
        ),
      ),
    );
  }
}
