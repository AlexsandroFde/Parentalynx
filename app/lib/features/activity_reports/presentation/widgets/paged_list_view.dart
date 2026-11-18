import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/report_period.dart';
import '../bloc/paging/paged_list.dart';
import '../texts/report_texts.dart';

/// Lista paginada das telas de detalhe (eventos e navegacao): carregando, falha, vazio e os
/// itens agrupados por dia (`Hoje`, `Ontem`, `seg 16/11`), com o "carregar mais" no fim.
///
/// [visible] filtra os itens ja carregados (por exemplo, a busca); quando nenhum aparece,
/// mostra [noneVisible] e continua oferecendo carregar os mais antigos.
class PagedListBody<T> extends StatelessWidget {
  const PagedListBody({
    required this.state,
    required this.timeOf,
    required this.rowBuilder,
    required this.onRetry,
    required this.onLoadMore,
    required this.subject,
    required this.empty,
    this.visible,
    this.noneVisible,
    super.key,
  });

  final PagedListState<T> state;

  /// Instante do item (milissegundos), para o agrupamento por dia.
  final int Function(T item) timeOf;
  final Widget Function(BuildContext context, T item) rowBuilder;

  /// Tentar de novo depois de uma falha (da primeira pagina ou da seguinte).
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  /// O que nao carregou, para a mensagem de erro ("os eventos").
  final String subject;
  final Widget empty;
  final bool Function(T item)? visible;
  final Widget? noneVisible;

  @override
  Widget build(BuildContext context) {
    final PagedListState<T> list = state;
    return StateSwitcher(
      child: switch (list) {
        PagedListLoading<T>() => const KeyedSubtree(
          key: ValueKey<String>('carregando'),
          child: SkeletonListGroup(rows: 5),
        ),
        PagedListError<T>(:final AppFailure failure) => KeyedSubtree(
          key: const ValueKey<String>('erro'),
          child: AppPanel(
            child: ErrorState.fromError(failure, subject: subject, compact: true, onRetry: onRetry),
          ),
        ),
        PagedListEmpty<T>() => KeyedSubtree(key: const ValueKey<String>('vazio'), child: empty),
        final PagedListLoaded<T> loaded => KeyedSubtree(
          key: const ValueKey<String>('lista'),
          child: _groups(context, loaded),
        ),
      },
    );
  }

  Widget _groups(BuildContext context, PagedListLoaded<T> loaded) {
    final DateTime now = context.read<Clock>().now();
    final List<(String, List<T>)> groups = <(String, List<T>)>[];
    for (final T item in loaded.items) {
      if (visible != null && !visible!(item)) {
        continue;
      }
      final String label = dayHeading(DateTime.fromMillisecondsSinceEpoch(timeOf(item)), now: now);
      if (groups.isEmpty || groups.last.$1 != label) {
        groups.add((label, <T>[]));
      }
      groups.last.$2.add(item);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (groups.isEmpty && noneVisible != null) noneVisible!,
        for (int i = 0; i < groups.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.xl),
          AppSection(
            title: groups[i].$1,
            child: AppListGroup(
              children: <Widget>[for (final T item in groups[i].$2) rowBuilder(context, item)],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (loaded.moreFailure case final AppFailure failure)
          AppBanner(
            tone: Tone.warning,
            title: 'Não foi possível carregar mais itens',
            message: 'Os itens acima continuam valendo. ${failure.message}',
            actionLabel: 'Tentar de novo',
            onAction: onRetry,
            liveRegion: true,
          )
        else if (loaded.hasMore)
          Center(
            child: AppButton.secondary(
              label: 'Carregar mais antigos',
              icon: AppIcons.history,
              busy: loaded.loadingMore,
              onPressed: onLoadMore,
            ),
          )
        else
          Text(
            'Isso é tudo do período.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
      ],
    );
  }
}

/// Periodo de uma tela de detalhe, com a troca pelo calendario.
class ReportPeriodRow extends StatelessWidget {
  const ReportPeriodRow({
    required this.from,
    required this.to,
    required this.today,
    required this.onChanged,
    super.key,
  });

  final String from;
  final String to;

  /// Dia da cota corrente do aparelho (ultimo dia que pode ser escolhido).
  final String today;
  final void Function(String from, String to) onChanged;

  Future<void> _pick(BuildContext context) async {
    final DateTime last = parseDay(today);
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: last.subtract(const Duration(days: 400)),
      lastDate: last,
      initialDateRange: DateTimeRange(start: parseDay(from), end: parseDay(to)),
      helpText: 'Período (até ${ReportPeriod.maxDays} dias)',
      saveText: 'Aplicar',
    );
    if (range != null) {
      onChanged(formatDay(range.start), formatDay(range.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ReportPeriod period = ReportPeriod.custom(from, to, today: today);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      spacing: AppSpacing.sm,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(AppIcons.calendar, size: AppSizes.iconSm, color: context.colors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(period.describe(today: today), style: context.text.titleSmall),
            ),
          ],
        ),
        AppButton.tertiary(
          label: 'Alterar período',
          size: AppButtonSize.compact,
          onPressed: () => _pick(context),
        ),
      ],
    );
  }
}

/// Atualiza a lista puxando para baixo e, se falhar, avisa que a lista anterior continua.
Future<void> refreshKeepingList(
  BuildContext context,
  void Function(Completer<AppFailure?> completer) request,
) async {
  final Completer<AppFailure?> completer = Completer<AppFailure?>();
  request(completer);
  final AppFailure? failure = await completer.future;
  if (failure != null && context.mounted) {
    showAppSnackBar(
      context,
      'Não foi possível atualizar. A lista mostra o que foi carregado antes. ${failure.message}',
      tone: Tone.danger,
    );
  }
}
