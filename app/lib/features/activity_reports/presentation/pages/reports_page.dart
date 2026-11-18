import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../app_management/presentation/widgets/app_category_ui.dart';
import '../../../app_management/presentation/widgets/app_icon_view.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../../child_device/presentation/widgets/device_selector.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/entities/report_summary.dart';
import '../bloc/activity_reports/activity_reports_bloc.dart';
import '../texts/report_texts.dart';
import '../widgets/charts.dart';

/// Relatorios de uso do aparelho em foco, com filtro de periodo.
///
/// Espera o [DevicesBloc] (aparelho em foco) e o [ActivityReportsBloc] acima na arvore. A tela
/// avisa o BLoC do relatorio quando o aparelho em foco muda.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  @override
  void initState() {
    super.initState();
    _followDevice(context.read<DevicesBloc>().state.selected);
  }

  void _followDevice(ChildDevice? device) {
    if (device != null) {
      context.read<ActivityReportsBloc>().add(
        ReportsDeviceChanged(deviceId: device.id, deviceToday: device.today),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final DevicesState devices = context.watch<DevicesBloc>().state;
    final ChildDevice? device = devices.selected;
    return BlocListener<DevicesBloc, DevicesState>(
      listenWhen: (DevicesState previous, DevicesState current) {
        final ChildDevice? before = previous.selected;
        final ChildDevice? after = current.selected;
        return before?.id != after?.id || before?.today != after?.today;
      },
      listener: (BuildContext context, DevicesState state) => _followDevice(state.selected),
      child: Scaffold(
        appBar: AppBar(title: const Text('Relatórios')),
        body: device == null ? _NoDevice(devices: devices) : _ReportsContent(device: device),
      ),
    );
  }
}

class _NoDevice extends StatelessWidget {
  const _NoDevice({required this.devices});

  final DevicesState devices;

  @override
  Widget build(BuildContext context) {
    return switch (devices) {
      DevicesInitial() || DevicesLoading() => const LoadingView(),
      DevicesError(:final failure) => FailureView(
        error: failure,
        onRetry: () => context.read<DevicesBloc>().add(const DevicesRefreshRequested()),
      ),
      DevicesEmpty() || DevicesLoaded() => EmptyState(
        icon: Icons.insights_outlined,
        title: 'Nenhum aparelho vinculado',
        message: 'Os relatórios aparecem depois que o aparelho da criança for vinculado.',
        actionLabel: 'Vincular aparelho',
        onAction: () => context.push(GuardianPaths.pairing),
      ),
    };
  }
}

class _ReportsContent extends StatelessWidget {
  const _ReportsContent({required this.device});

  final ChildDevice device;

  Future<void> _refresh(BuildContext context) {
    final Completer<void> done = Completer<void>();
    context.read<ActivityReportsBloc>().add(ReportsRefreshRequested(completer: done));
    return done.future;
  }

  Future<void> _select(BuildContext context, ReportPreset preset, ReportQuery query) async {
    final ActivityReportsBloc bloc = context.read<ActivityReportsBloc>();
    if (preset != ReportPreset.custom) {
      bloc.add(ReportsPresetSelected(preset));
      return;
    }
    final ReportPeriod current = query.period;
    final DateTime last = parseDay(query.today);
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: last.subtract(const Duration(days: 400)),
      lastDate: last,
      initialDateRange: DateTimeRange(start: parseDay(current.from), end: parseDay(current.to)),
      helpText: 'Período do relatório (até ${ReportPeriod.maxDays} dias)',
      saveText: 'Aplicar',
    );
    if (range != null) {
      bloc.add(ReportsCustomRangeSelected(from: formatDay(range.start), to: formatDay(range.end)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ActivityReportsState state = context.watch<ActivityReportsBloc>().state;
    final ReportQuery? query = state.query;
    if (query == null) {
      return const LoadingView();
    }
    final ReportPeriod period = query.period;
    final ReportSummary? summary = state.summary;
    final AppFailure? failure = state.failure;

    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: PageBody(
        children: <Widget>[
          const DeviceSelector(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final ReportPreset preset in ReportPreset.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(preset.label),
                      selected: query.selection.preset == preset,
                      onSelected: (_) => _select(context, preset, query),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${device.displayName}, ${period.rangeLabel}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (state.isLoading && summary != null)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (summary == null)
            SizedBox(
              height: 320,
              child: failure != null
                  ? FailureView(error: failure, onRetry: () => _refresh(context))
                  : const LoadingView(message: 'Montando o relatório'),
            )
          else ...<Widget>[
            if (failure != null && !state.isFresh) ...<Widget>[
              NoticeBanner(
                tone: Tone.warning,
                message: 'Não foi possível atualizar. Mostrando o último relatório carregado.',
                actionLabel: 'Tentar de novo',
                onAction: () => _refresh(context),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            // Enquanto o novo periodo carrega, o relatorio anterior fica esmaecido na tela.
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: state.isFresh ? 1 : 0.5,
              child: _ReportBody(summary: summary, period: period),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.summary, required this.period});

  final ReportSummary summary;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ChartPalette palette = ChartPalette.of(context);
    final ReportTotals totals = summary.totals;
    final bool multiDay = summary.isMultiDay;
    final int totalMs = totals.totalMs;

    final List<AppUsage> topApps = summary.topApps();
    final int maxAppMs = topApps.isEmpty ? 1 : topApps.first.totalMs;
    final List<CategoryUsage> categories = summary.usedCategories;
    final int maxCategoryMs = categories.isEmpty ? 1 : categories.first.totalMs;
    final int maxBlocked = summary.blockedByApp.isEmpty ? 1 : summary.blockedByApp.first.count;
    final int? peak = summary.peakHour;

    String share(int ms) {
      final int? percent = summary.percentOfTotal(ms);
      return percent == null ? '' : '$percent% do total';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Tempo de uso no período',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatDurationMs(totalMs),
                  key: const ValueKey<String>('report-total'),
                  style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _StatTile(
                      label: multiDay ? 'Média por dia' : 'Dentro do limite',
                      value: formatDurationMs(multiDay ? totals.avgPerDayMs : totals.quotaMs),
                    ),
                  ),
                  Expanded(
                    child: _StatTile(
                      label: 'Tentativas bloqueadas',
                      value: '${totals.blockedAttempts}',
                    ),
                  ),
                  Expanded(
                    child: _StatTile(label: 'Aberturas de apps', value: '${totals.opens}'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!summary.hasUsage && totals.blockedAttempts == 0)
          const SectionCard(
            child: EmptyState(
              icon: Icons.hourglass_empty,
              title: 'Sem uso registrado neste período',
              message:
                  'Se o aparelho foi usado, confira se ele sincronizou e se a permissão de '
                  'acesso ao uso continua ativa.',
            ),
          )
        else ...<Widget>[
          if (multiDay) ...<Widget>[
            ChartCard(
              title: 'Uso por dia',
              subtitle: 'Tempo em apps, comparado ao limite de cada dia.',
              legend: <LegendItem>[
                LegendItem(palette.usage, 'Dentro do limite'),
                LegendItem(palette.outsideQuota, 'Fora do limite (exceções)'),
                LegendItem(palette.limitTrack, 'Limite do dia'),
              ],
              semanticSummary:
                  'Gráfico de barras do uso por dia. Total de ${formatDurationMs(totalMs)} em '
                  '${summary.daily.length} dias.',
              chart: DailyUsageChart(daily: summary.daily),
              tableHeader: const <String>['Dia', 'Total', 'No limite', 'Limite'],
              tableRows: <List<String>>[
                for (final DailyUsage day in summary.daily)
                  <String>[
                    formatDayLabel(day.day),
                    formatDurationMs(day.totalMs),
                    formatDurationMs(day.quotaMs),
                    day.limitMs == null ? 'sem limite' : formatDurationMs(day.limitMs!),
                  ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          ChartCard(
            title: 'Horários de maior atividade',
            subtitle: peak == null
                ? 'Tempo de uso por hora do dia.'
                : 'Tempo de uso por hora do dia. Pico entre ${peak}h e ${peak + 1}h.',
            semanticSummary: peak == null
                ? 'Gráfico de uso por hora do dia, sem uso no período.'
                : 'Gráfico de uso por hora do dia. O pico é entre ${peak}h e ${peak + 1}h.',
            chart: HourlyChart(hourly: summary.hourly),
            tableHeader: const <String>['Hora', 'Tempo'],
            tableRows: <List<String>>[
              for (int hour = 0; hour < summary.hourly.length; hour++)
                if (summary.hourly[hour] > 0)
                  <String>['${hour}h às ${hour + 1}h', formatDurationMs(summary.hourly[hour])],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Uso por aplicativo',
            subtitle: summary.apps.length > topApps.length
                ? 'Os ${topApps.length} mais usados de ${summary.apps.length}.'
                : null,
            child: topApps.isEmpty
                ? const Text('Nenhum app usado no período.')
                : RankedBars(
                    color: palette.usage,
                    items: <RankedItem>[
                      for (final AppUsage app in topApps)
                        RankedItem(
                          leading: AppIconView(package: app.package, label: app.label, size: 36),
                          label: app.label,
                          value: formatDurationMs(app.totalMs),
                          fraction: app.totalMs / maxAppMs,
                          note:
                              '${app.opens} ${app.opens == 1 ? 'abertura' : 'aberturas'}, '
                              '${share(app.totalMs)}',
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Tempo por categoria',
            child: categories.isEmpty
                ? const Text('Sem categorias com uso no período.')
                : RankedBars(
                    color: palette.usage,
                    items: <RankedItem>[
                      for (final CategoryUsage category in categories)
                        RankedItem(
                          leading: Icon(
                            category.category.icon,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          label: category.category.label,
                          value: formatDurationMs(category.totalMs),
                          fraction: category.totalMs / maxCategoryMs,
                          note: share(category.totalMs),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (multiDay) ...<Widget>[
            ChartCard(
              title: 'Evolução do uso',
              subtitle: 'Total por dia e a média do período.',
              semanticSummary:
                  'Gráfico de linha da evolução do uso. Média de '
                  '${formatDurationMs(totals.avgPerDayMs)} por dia.',
              chart: EvolutionChart(daily: summary.daily),
              tableHeader: const <String>['Dia', 'Total'],
              tableRows: <List<String>>[
                for (final DailyUsage day in summary.daily)
                  <String>[formatDayLabel(day.day), formatDurationMs(day.totalMs)],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ChartCard(
              title: 'Tentativas de acesso bloqueadas',
              subtitle: 'Vezes em que um app não autorizado foi aberto, por dia.',
              height: 160,
              semanticSummary:
                  'Gráfico de barras das tentativas bloqueadas por dia. Total de '
                  '${totals.blockedAttempts}.',
              chart: BlockedAttemptsChart(daily: summary.daily),
              tableHeader: const <String>['Dia', 'Tentativas'],
              tableRows: <List<String>>[
                for (final DailyUsage day in summary.daily)
                  <String>[formatDayLabel(day.day), '${day.blockedAttempts}'],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SectionCard(
            title: 'Apps com tentativas bloqueadas',
            child: summary.blockedByApp.isEmpty
                ? const Text('Nenhuma tentativa de abrir app bloqueado no período.')
                : RankedBars(
                    color: palette.blocked,
                    items: <RankedItem>[
                      for (final BlockedApp app in summary.blockedByApp.take(8))
                        RankedItem(
                          leading: AppIconView(package: app.package, label: app.label, size: 36),
                          label: app.label,
                          value: '${app.count}',
                          fraction: app.count / maxBlocked,
                        ),
                    ],
                  ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: 'Detalhes',
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Column(
            children: <Widget>[
              _DetailLink(
                icon: Icons.timeline,
                title: 'Linha do tempo das sessões',
                subtitle: 'Cada app aberto, com início, fim e períodos sem uso.',
                onTap: () => context.push(ReportsPaths.sessionsOf(period.to)),
              ),
              _DetailLink(
                icon: Icons.list_alt_outlined,
                title: 'Eventos',
                subtitle: 'Bloqueios, limites, permissões e segurança.',
                onTap: () => context.push(ReportsPaths.eventsIn(period.from, period.to)),
              ),
              _DetailLink(
                icon: Icons.travel_explore,
                title: 'Histórico de navegação',
                subtitle: 'Páginas abertas no navegador ParentaLynx.',
                onTap: () => context.push(ReportsPaths.browsingIn(period.from, period.to)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(value, style: theme.textTheme.titleLarge),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _DetailLink extends StatelessWidget {
  const _DetailLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
