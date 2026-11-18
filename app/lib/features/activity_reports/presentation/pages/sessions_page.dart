import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../app_management/presentation/widgets/app_icon_view.dart';
import '../../domain/entities/day_timeline.dart';
import '../../domain/entities/usage_session.dart';
import '../bloc/day_timeline/day_timeline_bloc.dart';
import '../widgets/charts.dart';

String _clock(DateTime time) => formatClock(time);

/// Linha do tempo das sessoes de um dia: cada app aberto e os periodos sem uso.
///
/// Espera um [DayTimelineBloc] acima na arvore.
class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  static const String title = 'Linha do tempo';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DayTimelineState state = context.watch<DayTimelineBloc>().state;
    if (state is DayTimelineInitial) {
      return Scaffold(
        appBar: AppBar(title: const Text(title)),
        body: const LoadingView(),
      );
    }
    final DayTimelineBloc bloc = context.read<DayTimelineBloc>();
    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Dia anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => bloc.add(const DayTimelinePreviousDayRequested()),
                ),
                Expanded(
                  child: Text(
                    formatDayRelative(state.day, today: state.today),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Dia seguinte',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: state.canGoForward
                      ? () => bloc.add(const DayTimelineNextDayRequested())
                      : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (state) {
              DayTimelineInitial() || DayTimelineLoading() => const LoadingView(),
              DayTimelineError(:final failure) => FailureView(
                error: failure,
                onRetry: () => bloc.add(const DayTimelineRetried()),
              ),
              DayTimelineEmpty() => const EmptyState(
                icon: Icons.bedtime_outlined,
                title: 'Nenhuma sessão neste dia',
                message: 'O aparelho não registrou uso de apps neste dia.',
              ),
              DayTimelineLoaded(:final timeline) => _SessionsBody(timeline: timeline),
            },
          ),
        ],
      ),
    );
  }
}

class _SessionsBody extends StatelessWidget {
  const _SessionsBody({required this.timeline});

  final DayTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<UsageSession> sessions = timeline.sessions;
    final int longestGap = timeline.longestGapMs;
    final TextStyle? muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return PageBody(
      children: <Widget>[
        SectionCard(
          title: 'Resumo do dia',
          subtitle:
              '${sessions.length} ${sessions.length == 1 ? 'sessão' : 'sessões'}, '
              '${formatDurationMs(timeline.totalMs)} de uso'
              '${longestGap > 0 ? ', maior pausa de ${formatDurationMs(longestGap)}' : ''}.',
          child: Semantics(
            label: 'Faixa de 24 horas com os períodos de uso do dia',
            child: SizedBox(
              height: 44,
              child: CustomPaint(
                painter: _DayStripPainter(
                  sessions: sessions,
                  color: ChartPalette.of(context).usage,
                  track: theme.colorScheme.surfaceContainerHighest,
                  ink: theme.colorScheme.onSurfaceVariant,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final TimelineItem item in timeline.items)
          switch (item) {
            TimelineSession(:final UsageSession session) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Card(
                child: ListTile(
                  leading: AppIconView(package: session.package, label: session.label, size: 36),
                  title: Text(session.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${_clock(session.localStart)} às ${_clock(session.localEnd)}. '
                    '${session.category.label}',
                  ),
                  trailing: Text(
                    formatDurationMs(session.durationMs),
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ),
            ),
            TimelineGap(:final InactivityGap gap) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Row(
                children: <Widget>[
                  Icon(Icons.more_vert, size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Sem uso por ${formatDurationMs(gap.durationMs)}', style: muted),
                ],
              ),
            ),
          },
      ],
    );
  }
}

/// Faixa de 24 horas com um bloco para cada sessao, na hora local do aparelho.
class _DayStripPainter extends CustomPainter {
  const _DayStripPainter({
    required this.sessions,
    required this.color,
    required this.track,
    required this.ink,
  });

  final List<UsageSession> sessions;
  final Color color;
  final Color track;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    const double barHeight = 18;
    final RRect background = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, barHeight),
      const Radius.circular(4),
    );
    canvas.drawRRect(background, Paint()..color = track);
    canvas.save();
    canvas.clipRRect(background);
    final Paint fill = Paint()..color = color;
    for (final UsageSession session in sessions) {
      final DateTime start = session.localStart;
      final double startMinute = start.hour * 60 + start.minute + start.second / 60;
      final double left = size.width * startMinute / 1440;
      final double width = math.max(1.5, size.width * (session.durationMs / 60000) / 1440);
      canvas.drawRect(Rect.fromLTWH(left, 0, width, barHeight), fill);
    }
    canvas.restore();
    for (final int hour in const <int>[0, 6, 12, 18, 24]) {
      final TextPainter label = TextPainter(
        text: TextSpan(
          text: '${hour}h',
          style: TextStyle(color: ink, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final double x = (size.width * hour / 24 - label.width / 2).clamp(
        0.0,
        size.width - label.width,
      );
      label.paint(canvas, Offset(x, barHeight + 6));
    }
  }

  @override
  bool shouldRepaint(_DayStripPainter oldDelegate) {
    return oldDelegate.sessions != sessions || oldDelegate.color != color;
  }
}
