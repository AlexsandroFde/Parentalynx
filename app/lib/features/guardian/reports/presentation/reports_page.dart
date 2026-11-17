import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../apps/presentation/app_category_ui.dart';
import '../../apps/presentation/app_icon.dart';
import '../../dashboard/presentation/widgets/device_selector.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/devices_providers.dart';
import '../../guardian_paths.dart';
import '../data/reports_repository.dart';
import '../domain/report_models.dart';
import '../domain/report_period.dart';
import '../reports_paths.dart';
import 'charts.dart';

/// Relatorios de uso do aparelho em foco, com filtro de periodo.
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportPreset _preset = ReportPreset.last7;
  String? _customFrom;
  String? _customTo;

  /// Ultimo relatorio carregado, mantido na tela enquanto o proximo periodo carrega.
  ReportSummary? _last;

  ReportPeriod _period(String today) {
    final String? from = _customFrom;
    final String? to = _customTo;
    if (_preset == ReportPreset.custom && from != null && to != null) {
      return ReportPeriod.custom(from, to, today: today);
    }
    return ReportPeriod.preset(_preset, today: today);
  }

  Future<void> _select(ReportPreset preset, String today) async {
    if (preset != ReportPreset.custom) {
      setState(() => _preset = preset);
      return;
    }
    final ReportPeriod current = _period(today);
    final DateTime last = parseDay(today);
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: last.subtract(const Duration(days: 400)),
      lastDate: last,
      initialDateRange: DateTimeRange(start: parseDay(current.from), end: parseDay(current.to)),
      helpText: 'Período do relatório (até ${ReportPeriod.maxDays} dias)',
      saveText: 'Aplicar',
    );
    if (range != null) {
      setState(() {
        _preset = ReportPreset.custom;
        _customFrom = formatDay(range.start);
        _customTo = formatDay(range.end);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Device? device = ref.watch(selectedDeviceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: device == null ? _noDevice() : _content(device),
    );
  }

  Widget _noDevice() {
    final AsyncValue<List<Device>> devices = ref.watch(devicesProvider);
    if (!devices.hasValue) {
      return devices.hasError
          ? FailureView(
              error: devices.error!,
              onRetry: () => ref.read(devicesProvider.notifier).refresh(),
            )
          : const LoadingView();
    }
    return EmptyState(
      icon: Icons.insights_outlined,
      title: 'Nenhum aparelho vinculado',
      message: 'Os relatórios aparecem depois que o aparelho da criança for vinculado.',
      actionLabel: 'Vincular aparelho',
      onAction: () => context.push(GuardianPaths.pairing),
    );
  }

  Widget _content(Device device) {
    final ThemeData theme = Theme.of(context);
    final String today = device.today.isEmpty ? formatDay(DateTime.now()) : device.today;
    final ReportPeriod period = _period(today);
    final ReportQuery query = (deviceId: device.id, from: period.from, to: period.to);
    final AsyncValue<ReportSummary> value = ref.watch(reportSummaryProvider(query));
    final ReportSummary? fresh = value.value;
    if (fresh != null) {
      _last = fresh;
    }
    final ReportSummary? summary = fresh ?? _last;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(reportSummaryProvider(query)),
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
                      selected: _preset == preset,
                      onSelected: (_) => _select(preset, today),
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
              if (value.isLoading && summary != null)
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
              child: value.hasError
                  ? FailureView(
                      error: value.error!,
                      onRetry: () => ref.invalidate(reportSummaryProvider(query)),
                    )
                  : const LoadingView(message: 'Montando o relatório'),
            )
          else ...<Widget>[
            if (value.hasError && fresh == null) ...<Widget>[
              NoticeBanner(
                tone: Tone.warning,
                message: 'Não foi possível atualizar. Mostrando o último relatório carregado.',
                actionLabel: 'Tentar de novo',
                onAction: () => ref.invalidate(reportSummaryProvider(query)),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            // Enquanto o novo periodo carrega, o relatorio anterior fica esmaecido na tela.
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: fresh == null ? 0.5 : 1,
              child: _ReportBody(summary: summary, device: device, period: period),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.summary, required this.device, required this.period});

  final ReportSummary summary;
  final Device device;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ChartPalette palette = ChartPalette.of(context);
    final ReportTotals totals = summary.totals;
    final bool multiDay = summary.daily.length > 1;
    final int totalMs = totals.totalMs;

    final List<AppUsage> topApps = summary.apps.take(8).toList();
    final int maxAppMs = topApps.isEmpty ? 1 : topApps.first.totalMs;
    final List<CategoryUsage> categories = summary.categories
        .where((CategoryUsage c) => c.totalMs > 0)
        .toList();
    final int maxCategoryMs = categories.isEmpty ? 1 : categories.first.totalMs;
    final int maxBlocked = summary.blockedByApp.isEmpty ? 1 : summary.blockedByApp.first.count;
    final int? peak = summary.peakHour;

    String share(int ms) => totalMs <= 0 ? '' : '${(ms * 100 / totalMs).round()}% do total';

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
