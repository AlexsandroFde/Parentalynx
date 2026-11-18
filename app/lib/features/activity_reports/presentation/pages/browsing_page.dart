import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../domain/entities/browsing_entry.dart';
import '../../domain/entities/report_period.dart';
import '../bloc/browsing_history/browsing_history_bloc.dart';
import '../bloc/paging/paged_list.dart';
import '../texts/event_texts.dart';
import '../texts/report_help.dart';
import '../texts/report_texts.dart';
import '../widgets/paged_list_view.dart';
import '../widgets/reports_device_gate.dart';

/// Historico do navegador gerenciado: o que foi aberto e o que foi bloqueado (com o motivo),
/// agrupado por dia, com busca e o filtro de bloqueadas. Explica o que o historico inclui e
/// quem ve (privacidade).
///
/// Espera um [BrowsingHistoryBloc] acima na arvore.
class BrowsingPage extends StatelessWidget {
  const BrowsingPage({super.key});

  static const String title = 'Histórico de navegação';

  @override
  Widget build(BuildContext context) {
    final BrowsingHistoryState state = context.watch<BrowsingHistoryBloc>().state;
    final BrowsingHistoryBloc bloc = context.read<BrowsingHistoryBloc>();
    final ChildDevice? device = context.select<DevicesBloc, ChildDevice?>(
      (DevicesBloc devices) => devices.state.selected,
    );
    final String today = quotaDayOf(device?.today ?? '', context.read<Clock>().now());
    final bool searching = state.query.trim().isNotEmpty;
    final PagedListState<BrowsingEntry> list = state.list;
    final bool hasMore = list is PagedListLoaded<BrowsingEntry> && list.hasMore;
    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
        actions: const <Widget>[
          HelpButton(title: 'Sobre o histórico', topics: browsingHelpTopics),
          SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: AppPageBody(
        onRefresh: () => refreshKeepingList(
          context,
          (completer) => bloc.add(BrowsingHistoryRefreshRequested(completer: completer)),
        ),
        children: <Widget>[
          if (device != null) ReportHeader(device: device),
          if (state.from.isNotEmpty) ...<Widget>[
            ReportPeriodRow(
              from: state.from,
              to: state.to,
              today: today.compareTo(state.to) < 0 ? state.to : today,
              onChanged: (String from, String to) {
                bloc.add(BrowsingHistoryPeriodChanged(from: from, to: to));
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppBanner(
            icon: AppIcons.privacy,
            title: 'Só o navegador ParentaLynx',
            message:
                'Páginas abertas em outros navegadores ou apps não aparecem aqui. A criança vê '
                'no navegador que o histórico é registrado.',
            actionLabel: 'Saiba mais',
            onAction: () =>
                showHelpSheet(context, title: 'Sobre o histórico', topics: browsingHelpTopics),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSegmentedControl<bool>(
            segments: const <AppChoice<bool>>[
              AppChoice<bool>(value: false, label: 'Todas'),
              AppChoice<bool>(value: true, label: 'Bloqueadas', icon: AppIcons.blocked),
            ],
            selected: state.onlyBlocked,
            onChanged: (bool value) {
              bloc.add(BrowsingHistoryOnlyBlockedChanged(onlyBlocked: value));
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _SearchField(onChanged: (String value) => bloc.add(BrowsingHistoryQueryChanged(value))),
          const SizedBox(height: AppSpacing.xl),
          PagedListBody<BrowsingEntry>(
            state: list,
            timeOf: (BrowsingEntry entry) => entry.ts,
            subject: 'o histórico',
            visible: state.isFiltered ? state.shows : null,
            onRetry: () => bloc.add(const BrowsingHistoryRetried()),
            onLoadMore: () => bloc.add(const BrowsingHistoryMoreRequested()),
            rowBuilder: (BuildContext context, BrowsingEntry entry) => _EntryRow(entry: entry),
            noneVisible: AppPanel(
              child: EmptyState(
                compact: true,
                icon: searching ? AppIcons.search : AppIcons.webBlocked,
                title: searching
                    ? 'Nada encontrado para "${state.query.trim()}"'
                    : 'Nenhuma página bloqueada',
                message: hasMore
                    ? 'A busca vale para as páginas já carregadas. Carregue as mais antigas para '
                          'procurar no resto do período.'
                    : 'Nenhuma das páginas do período corresponde ao filtro.',
              ),
            ),
            empty: const AppPanel(
              child: EmptyState(
                compact: true,
                icon: AppIcons.web,
                title: 'Nenhuma página registrada no período',
                message:
                    'O histórico existe só para o navegador ParentaLynx e só quando o registro '
                    'está ligado em Regras, Navegação na internet.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Busca por titulo, site ou endereco, com o botao de limpar.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _controller,
      label: 'Buscar no histórico',
      hint: 'Site ou título da página',
      prefixIcon: AppIcons.search,
      textInputAction: TextInputAction.search,
      onChanged: (String value) {
        setState(() {});
        widget.onChanged(value);
      },
      suffix: _controller.text.isEmpty
          ? null
          : AppIconButton(
              icon: AppIcons.close,
              tooltip: 'Limpar busca',
              onPressed: () {
                _controller.clear();
                setState(() {});
                widget.onChanged('');
              },
            ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final BrowsingEntry entry;

  void _open(BuildContext context) {
    final DateTime now = context.read<Clock>().now();
    final DateTime when = DateTime.fromMillisecondsSinceEpoch(entry.ts);
    unawaited(
      showAppSheet<void>(
        context,
        title: entry.displayTitle,
        subtitle: '${dayHeading(when, now: now)} às ${formatClock(when)}',
        builder: (BuildContext sheetContext) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Endereço', style: context.textStyles.eyebrow),
              const SizedBox(height: AppSpacing.xs),
              Text(entry.url, style: context.text.bodyLarge),
              if (entry.blocked) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                AppBanner(
                  tone: Tone.danger,
                  icon: AppIcons.blocked,
                  title: 'Bloqueada: ${browsingReasonLabel(entry.reason)}',
                  message: 'A página não abriu no aparelho da criança.',
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton.secondary(
                label: 'Copiar endereço',
                icon: AppIcons.copy,
                expand: true,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: entry.url));
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                  if (context.mounted) {
                    showAppSnackBar(context, 'Endereço copiado.', tone: Tone.success);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      leading: AppIconTile(
        icon: entry.blocked ? AppIcons.webBlocked : AppIcons.webAllowed,
        tone: entry.blocked ? Tone.danger : Tone.neutral,
      ),
      title: entry.displayTitle,
      titleStyle: context.text.bodyLarge,
      subtitle: entry.title.isEmpty ? null : entry.domain,
      below: entry.blocked
          ? Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusBadge(
                label: browsingReasonLabel(entry.reason),
                tone: Tone.danger,
                icon: AppIcons.blocked,
              ),
            )
          : null,
      trailing: AppRowValue(formatClockMs(entry.ts)),
      showChevron: false,
      onTap: () => _open(context),
    );
  }
}
