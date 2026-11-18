import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../app_management/presentation/widgets/app_icon_view.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../domain/entities/day_timeline.dart';
import '../../domain/entities/usage_session.dart';
import '../bloc/day_timeline/day_timeline_bloc.dart';
import '../texts/report_help.dart';
import '../texts/report_texts.dart';
import '../widgets/paged_list_view.dart';
import '../widgets/reports_device_gate.dart';

/// Linha do tempo das sessoes de um dia: o resumo do dia, a faixa de 24 horas e cada app
/// aberto, com as pausas longas entre os blocos de uso.
///
/// Espera um [DayTimelineBloc] acima na arvore.
class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  static const String title = 'Linha do tempo';

  @override
  Widget build(BuildContext context) {
    final DayTimelineState state = context.watch<DayTimelineBloc>().state;
    final DayTimelineBloc bloc = context.read<DayTimelineBloc>();
    final ChildDevice? device = context.select<DevicesBloc, ChildDevice?>(
      (DevicesBloc devices) => devices.state.selected,
    );
    final String day = state.day;
    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
        actions: const <Widget>[
          HelpButton(title: 'Sobre a linha do tempo', topics: timelineHelpTopics),
          SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: AppPageBody(
        onRefresh: () => refreshKeepingList(
          context,
          (completer) => bloc.add(DayTimelineRefreshRequested(completer: completer)),
        ),
        children: <Widget>[
          if (device != null) ReportHeader(device: device),
          if (state is! DayTimelineInitial) _DayStepper(state: state),
          const SizedBox(height: AppSpacing.xl),
          StateSwitcher(
            child: switch (state) {
              DayTimelineInitial() || DayTimelineLoading() => KeyedSubtree(
                key: ValueKey<String>('carregando-$day'),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SkeletonPanel(height: 168),
                    SectionGap(),
                    SkeletonListGroup(rows: 4),
                  ],
                ),
              ),
              DayTimelineError(:final failure) => KeyedSubtree(
                key: ValueKey<String>('erro-$day'),
                child: AppPanel(
                  child: ErrorState.fromError(
                    failure,
                    subject: 'a linha do tempo',
                    compact: true,
                    onRetry: () => bloc.add(const DayTimelineRetried()),
                  ),
                ),
              ),
              DayTimelineEmpty() => KeyedSubtree(
                key: ValueKey<String>('vazio-$day'),
                child: AppPanel(
                  child: EmptyState(
                    compact: true,
                    icon: AppIcons.elapsed,
                    title: 'Sem uso registrado neste dia',
                    message:
                        'O aparelho não registrou uso de apps em ${formatDayLabel(day)}. Se ele '
                        'foi usado, confira se está conectado.',
                    actionLabel: 'Ver o dia anterior',
                    onAction: () => bloc.add(const DayTimelinePreviousDayRequested()),
                  ),
                ),
              ),
              DayTimelineLoaded(:final DayTimeline timeline) => KeyedSubtree(
                key: ValueKey<String>('dia-$day'),
                child: _TimelineBody(timeline: timeline),
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Dia mostrado, com o anterior, o seguinte, o calendario e a volta para hoje.
class _DayStepper extends StatelessWidget {
  const _DayStepper({required this.state});

  final DayTimelineState state;

  Future<void> _pick(BuildContext context) async {
    final DayTimelineBloc bloc = context.read<DayTimelineBloc>();
    final DateTime last = parseDay(state.today);
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: last.subtract(const Duration(days: 400)),
      lastDate: last,
      initialDate: parseDay(state.day),
      helpText: 'Dia da linha do tempo',
    );
    if (picked != null) {
      bloc.add(DayTimelineDaySelected(formatDay(picked)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final DayTimelineBloc bloc = context.read<DayTimelineBloc>();
    final bool isToday = state.day == state.today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPanel(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
          child: Row(
            children: <Widget>[
              AppIconButton(
                icon: AppIcons.chevronLeft,
                tooltip: 'Dia anterior',
                onPressed: () => bloc.add(const DayTimelinePreviousDayRequested()),
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    children: <Widget>[
                      Text(
                        timelineDayTitle(state.day, today: state.today),
                        textAlign: TextAlign.center,
                        style: context.text.titleMedium,
                      ),
                      Text(
                        timelineDaySubtitle(state.day, today: state.today),
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              AppIconButton(
                icon: AppIcons.chevronRight,
                tooltip: 'Dia seguinte',
                onPressed: state.canGoForward
                    ? () => bloc.add(const DayTimelineNextDayRequested())
                    : null,
              ),
              AppIconButton(
                icon: AppIcons.calendar,
                tooltip: 'Escolher o dia',
                onPressed: () => _pick(context),
              ),
            ],
          ),
        ),
        if (!isToday) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: AppButton.tertiary(
              label: 'Voltar para hoje',
              size: AppButtonSize.compact,
              onPressed: () => bloc.add(DayTimelineDaySelected(state.today)),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimelineBody extends StatelessWidget {
  const _TimelineBody({required this.timeline});

  final DayTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final List<UsageSession> sessions = timeline.sessions;
    final AppChartStyle style = AppChartStyle.of(context);
    DateTime first = sessions.first.localStart;
    DateTime last = sessions.first.localEnd;
    for (final UsageSession session in sessions) {
      if (session.localStart.isBefore(first)) {
        first = session.localStart;
      }
      if (session.localEnd.isAfter(last)) {
        last = session.localEnd;
      }
    }
    final String span = 'Primeiro uso às ${formatClock(first)} e último às ${formatClock(last)}.';
    final int count = sessions.length;
    final int gap = timeline.longestGapMs;
    // Os blocos de uso continuo, separados pelas pausas longas.
    final List<Widget> blocks = <Widget>[];
    List<Widget> rows = <Widget>[];
    for (final TimelineItem item in timeline.items) {
      switch (item) {
        case TimelineSession(:final UsageSession session):
          rows.add(_SessionRow(session: session));
        case TimelineGap(gap: final InactivityGap pause):
          if (rows.isNotEmpty) {
            blocks.add(AppListGroup(children: rows));
            rows = <Widget>[];
          }
          blocks.add(_PauseLine(gap: pause, offsetMin: sessions.first.tzOffsetMin));
      }
    }
    if (rows.isNotEmpty) {
      blocks.add(AppListGroup(children: rows));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSection(
          title: 'Resumo do dia',
          child: AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                MetricRow(
                  metrics: <MetricTile>[
                    MetricTile(value: formatDurationMs(timeline.totalMs), label: 'Tempo de uso'),
                    MetricTile(value: '$count', label: count == 1 ? 'Sessão' : 'Sessões'),
                    MetricTile(
                      value: gap > 0 ? formatDurationMs(gap) : 'Nenhuma',
                      label: 'Maior pausa',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  container: true,
                  label: 'Faixa de 24 horas com os períodos de uso. $span',
                  child: ExcludeSemantics(
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Builder(
                        builder: (BuildContext context) {
                          final TextScaler scaler = MediaQuery.textScalerOf(context);
                          final double labelHeight = scaler.scale(
                            style.axisLabel.fontSize ?? AppSpacing.md,
                          );
                          return SizedBox(
                            height: _DayStripPainter.barHeight + AppSpacing.sm + labelHeight * 1.4,
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _DayStripPainter(
                                sessions: sessions,
                                color: style.primary,
                                track: style.track,
                                label: style.axisLabel,
                                scaler: scaler,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(span, style: context.text.bodySmall),
              ],
            ),
          ),
        ),
        const SectionGap(),
        AppSection(
          title: 'Sessões',
          subtitle: 'Na ordem do dia, no horário do aparelho.',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks),
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final UsageSession session;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      leading: AppIconView(package: session.package, label: session.label, size: AppSizes.iconTile),
      title: session.label,
      titleStyle: context.text.bodyLarge,
      subtitle:
          '${formatClock(session.localStart)} às ${formatClock(session.localEnd)} · '
          '${session.category.label}',
      trailing: Text(formatDurationMs(session.durationMs), style: context.textStyles.metricSmall),
    );
  }
}

/// Pausa longa entre dois blocos de uso.
class _PauseLine extends StatelessWidget {
  const _PauseLine({required this.gap, required this.offsetMin});

  final InactivityGap gap;

  /// Fuso do aparelho, para os horarios da pausa.
  final int offsetMin;

  @override
  Widget build(BuildContext context) {
    DateTime local(int ms) {
      return DateTime.fromMillisecondsSinceEpoch(ms + offsetMin * 60000, isUtc: true);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(AppIcons.pause, size: AppSizes.iconSm, color: context.colors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Sem uso por ${formatDurationMs(gap.durationMs)}, das '
              '${formatClock(local(gap.start))} às ${formatClock(local(gap.end))}',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Faixa de 24 horas com um bloco para cada sessao, na hora local do aparelho.
class _DayStripPainter extends CustomPainter {
  const _DayStripPainter({
    required this.sessions,
    required this.color,
    required this.track,
    required this.label,
    required this.scaler,
  });

  static const double barHeight = 20;
  static const double _minWidth = 1.5;

  final List<UsageSession> sessions;
  final Color color;
  final Color track;
  final TextStyle label;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect background = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, barHeight),
      const Radius.circular(AppRadius.xs),
    );
    canvas.drawRRect(background, Paint()..color = track);
    canvas
      ..save()
      ..clipRRect(background);
    final Paint fill = Paint()..color = color;
    for (final UsageSession session in sessions) {
      final DateTime start = session.localStart;
      final double startMinute = start.hour * 60 + start.minute + start.second / 60;
      final double left = size.width * startMinute / 1440;
      final double width = math.max(_minWidth, size.width * (session.durationMs / 60000) / 1440);
      canvas.drawRect(Rect.fromLTWH(left, 0, width, barHeight), fill);
    }
    canvas.restore();
    for (final int hour in const <int>[0, 6, 12, 18, 24]) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: '${hour}h', style: label),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final double x = (size.width * hour / 24 - painter.width / 2).clamp(
        0.0,
        math.max(0.0, size.width - painter.width),
      );
      painter.paint(canvas, Offset(x, barHeight + AppSpacing.sm));
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(_DayStripPainter oldDelegate) {
    return oldDelegate.sessions != sessions ||
        oldDelegate.color != color ||
        oldDelegate.track != track ||
        oldDelegate.scaler != scaler;
  }
}
