import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../../child_device/presentation/widgets/device_selector.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/entities/report_summary.dart';
import '../bloc/activity_reports/activity_reports_bloc.dart';
import '../texts/report_help.dart';
import '../texts/report_texts.dart';
import '../widgets/report_sections.dart';
import '../widgets/reports_device_gate.dart';

/// Relatorios de uso do aparelho em foco, com a escolha de periodo.
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
        appBar: AppBar(
          title: const Text('Relatórios'),
          actions: const <Widget>[
            HelpButton(title: 'Como ler os relatórios', topics: reportsHelpTopics),
            SizedBox(width: AppSpacing.xs),
          ],
        ),
        body: device == null ? ReportsNoDevice(devices: devices) : _ReportsContent(device: device),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final ActivityReportsState state = context.watch<ActivityReportsBloc>().state;
    final ReportQuery? query = state.query;
    final ReportSummary? summary = state.summary;
    final AppFailure? failure = state.failure;

    final Widget content;
    if (query == null || (summary == null && failure == null)) {
      content = const KeyedSubtree(key: ValueKey<String>('carregando'), child: _ReportSkeleton());
    } else if (summary == null) {
      content = KeyedSubtree(
        key: const ValueKey<String>('erro'),
        child: AppPanel(
          child: ErrorState.fromError(
            failure!,
            subject: 'o relatório',
            compact: true,
            onRetry: () => _refresh(context),
          ),
        ),
      );
    } else {
      // Os dados na tela podem ser do periodo anterior enquanto o novo carrega (ou se falhou):
      // os rotulos e os atalhos seguem o periodo dos dados mostrados.
      final ReportPeriod shown = summary.from.isEmpty || summary.to.isEmpty
          ? query.period
          : ReportPeriod.custom(summary.from, summary.to, today: query.today);
      content = KeyedSubtree(
        key: const ValueKey<String>('relatorio'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (failure != null && !state.isFresh) ...<Widget>[
              AppBanner(
                tone: Tone.warning,
                title: 'Não foi possível atualizar o relatório',
                message:
                    'Mostrando ${shown.rangeLabel}, o último relatório carregado. '
                    '${failure.message}',
                actionLabel: 'Tentar de novo',
                onAction: () => _refresh(context),
                liveRegion: true,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            AnimatedOpacity(
              duration: AppMotion.resolve(context, AppMotion.base),
              opacity: state.isFresh ? 1 : AppOpacity.disabled + AppOpacity.focus,
              child: ReportBody(summary: summary, period: shown, today: query.today),
            ),
          ],
        ),
      );
    }

    return AppPageBody(
      onRefresh: () => _refresh(context),
      children: <Widget>[
        const DeviceSelector(),
        ReportHeader(device: device),
        if (query != null) ...<Widget>[
          _PeriodPicker(query: query, updating: state.isLoading && summary != null),
          const SizedBox(height: AppSpacing.md),
        ],
        DeviceFreshnessLine(device: device),
        const SizedBox(height: AppSpacing.xl),
        StateSwitcher(child: content),
      ],
    );
  }
}

/// Atalhos de periodo (Hoje, Ontem, 7 e 30 dias), o periodo por extenso e a escolha de outras
/// datas no calendario.
class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.query, required this.updating});

  final ReportQuery query;

  /// Um periodo novo esta carregando com o anterior na tela.
  final bool updating;

  static const List<ReportPreset> _presets = <ReportPreset>[
    ReportPreset.today,
    ReportPreset.yesterday,
    ReportPreset.last7,
    ReportPreset.last30,
  ];

  /// Com fonte grande os atalhos quebram linha em vez de espremer quatro segmentos.
  static const double _wrapFromTextScale = 1.5;

  Future<void> _pickDates(BuildContext context) async {
    final ActivityReportsBloc bloc = context.read<ActivityReportsBloc>();
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
    final ActivityReportsBloc bloc = context.read<ActivityReportsBloc>();
    final ReportPreset selected = query.selection.preset;
    final bool custom = selected == ReportPreset.custom;
    final List<AppChoice<ReportPreset>> choices = <AppChoice<ReportPreset>>[
      for (final ReportPreset preset in _presets)
        AppChoice<ReportPreset>(value: preset, label: preset.label),
    ];
    final bool large = MediaQuery.textScalerOf(context).scale(1) >= _wrapFromTextScale;
    final Widget presets = large
        ? AppChoiceChips<ReportPreset>(
            choices: choices,
            selected: custom ? null : selected,
            onSelected: (ReportPreset preset) => bloc.add(ReportsPresetSelected(preset)),
          )
        : AppSegmentedControl<ReportPreset>(
            segments: choices,
            // Com datas escolhidas a mao nenhum atalho fica marcado.
            selected: selected,
            onChanged: (ReportPreset preset) => bloc.add(ReportsPresetSelected(preset)),
          );
    final Widget period = Semantics(
      liveRegion: true,
      child: Text(
        updating
            ? 'Carregando ${query.period.describe(today: query.today)}…'
            : query.period.describe(today: query.today),
        style: context.text.titleSmall,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        presets,
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: AppSpacing.sm,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (updating)
                  const SizedBox.square(
                    dimension: AppSizes.iconSm,
                    child: CircularProgressIndicator(strokeWidth: AppSizes.focusRing),
                  )
                else
                  Icon(
                    AppIcons.calendar,
                    size: AppSizes.iconSm,
                    color: context.colors.textSecondary,
                  ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: period),
              ],
            ),
            AppButton.tertiary(
              label: custom ? 'Alterar datas' : 'Outras datas',
              icon: AppIcons.calendar,
              size: AppButtonSize.compact,
              onPressed: () => _pickDates(context),
            ),
          ],
        ),
      ],
    );
  }
}

/// Forma do relatorio enquanto a primeira consulta carrega.
class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SkeletonPanel(height: 168),
        SectionGap(),
        SkeletonPanel(height: 232),
        SectionGap(),
        SkeletonListGroup(rows: 4),
      ],
    );
  }
}
