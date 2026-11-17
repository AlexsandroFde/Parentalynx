import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../apps/presentation/app_icon.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/devices_providers.dart';
import '../data/reports_repository.dart';
import '../domain/event_texts.dart';
import '../domain/report_models.dart';
import 'charts.dart';

String _clock(DateTime time) => formatClock(time);

/// Linha do tempo das sessoes de um dia: cada app aberto e os periodos sem uso.
class SessionsPage extends ConsumerStatefulWidget {
  const SessionsPage({this.initialDay, super.key});

  final String? initialDay;

  @override
  ConsumerState<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends ConsumerState<SessionsPage> {
  String? _day;

  @override
  Widget build(BuildContext context) {
    final Device? device = ref.watch(selectedDeviceProvider);
    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Linha do tempo')),
        body: const EmptyState(icon: Icons.timeline, title: 'Nenhum aparelho vinculado'),
      );
    }
    final String today = device.today.isEmpty ? formatDay(DateTime.now()) : device.today;
    final String day = _day ?? widget.initialDay ?? today;
    final SessionsQuery query = (deviceId: device.id, day: day);
    final AsyncValue<List<UsageSession>> sessions = ref.watch(daySessionsProvider(query));
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Linha do tempo')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Dia anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _day = addDays(day, -1)),
                ),
                Expanded(
                  child: Text(
                    formatDayRelative(day, today: today),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Dia seguinte',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: day.compareTo(today) >= 0
                      ? null
                      : () => setState(() => _day = addDays(day, 1)),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<UsageSession>>(
              value: sessions,
              onRetry: () => ref.invalidate(daySessionsProvider(query)),
              data: (List<UsageSession> data) => _SessionsBody(sessions: data),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsBody extends StatelessWidget {
  const _SessionsBody({required this.sessions});

  final List<UsageSession> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.bedtime_outlined,
        title: 'Nenhuma sessão neste dia',
        message: 'O aparelho não registrou uso de apps neste dia.',
      );
    }
    final ThemeData theme = Theme.of(context);
    final List<Object> items = buildTimeline(sessions);
    final int totalMs = sessions.fold<int>(0, (int sum, UsageSession s) => sum + s.durationMs);
    final int longestGap = items.whereType<InactivityGap>().fold<int>(
      0,
      (int best, InactivityGap gap) => math.max(best, gap.durationMs),
    );
    final TextStyle? muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return PageBody(
      children: <Widget>[
        SectionCard(
          title: 'Resumo do dia',
          subtitle:
              '${sessions.length} ${sessions.length == 1 ? 'sessão' : 'sessões'}, '
              '${formatDurationMs(totalMs)} de uso'
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
        for (final Object item in items)
          if (item is UsageSession)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Card(
                child: ListTile(
                  leading: AppIconView(package: item.package, label: item.label, size: 36),
                  title: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${_clock(item.localStart)} às ${_clock(item.localEnd)}. '
                    '${item.category.label}',
                  ),
                  trailing: Text(
                    formatDurationMs(item.durationMs),
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ),
            )
          else if (item is InactivityGap)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Row(
                children: <Widget>[
                  Icon(Icons.more_vert, size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Sem uso por ${formatDurationMs(item.durationMs)}', style: muted),
                ],
              ),
            ),
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

/// Carrega uma pagina de itens a partir de um cursor.
typedef PageLoader<T> = Future<ResultPage<T>> Function(String? before);

/// Lista paginada com carregamento sob demanda, estados de erro e vazio.
class _PagedList<T> extends StatefulWidget {
  const _PagedList({
    required this.loader,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    super.key,
  });

  final PageLoader<T> loader;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<_PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<_PagedList<T>> {
  final List<T> _items = <T>[];
  String? _next;
  bool _loading = false;
  bool _started = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ResultPage<T> page = await widget.loader(_started ? _next : null);
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(page.items);
        _next = page.nextBefore;
        _started = true;
        _loading = false;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      if (_error != null) {
        return FailureView(error: _error!, onRetry: _load);
      }
      if (_loading || !_started) {
        return const LoadingView();
      }
      return EmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
      );
    }
    final bool hasMore = _next != null;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: _items.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index < _items.length) {
              return widget.itemBuilder(context, _items[index]);
            }
            if (_error != null) {
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: NoticeBanner(
                  tone: Tone.warning,
                  message: 'Não foi possível carregar mais itens.',
                  actionLabel: 'Tentar de novo',
                  onAction: _load,
                ),
              );
            }
            if (!hasMore) {
              return const SizedBox(height: AppSpacing.lg);
            }
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : OutlinedButton(onPressed: _load, child: const Text('Carregar mais')),
              ),
            );
          },
        ),
      ),
    );
  }
}

({IconData icon, Tone tone}) _eventVisual(DeviceEvent event) {
  return switch (EventGroup.of(event.type)) {
    EventGroup.blocks => (icon: Icons.block, tone: Tone.danger),
    EventGroup.limit => (icon: Icons.timer_outlined, tone: Tone.warning),
    EventGroup.security => (icon: Icons.security, tone: Tone.danger),
    EventGroup.apps => (icon: Icons.apps_outlined, tone: Tone.info),
    EventGroup.system || EventGroup.all => (icon: Icons.settings_outlined, tone: Tone.neutral),
  };
}

/// Eventos registrados pelo aparelho no periodo, com filtro por tipo.
class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({this.from, this.to, super.key});

  final String? from;
  final String? to;

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  EventGroup _group = EventGroup.all;

  @override
  Widget build(BuildContext context) {
    final Device? device = ref.watch(selectedDeviceProvider);
    final ThemeData theme = Theme.of(context);
    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Eventos')),
        body: const EmptyState(icon: Icons.list_alt_outlined, title: 'Nenhum aparelho vinculado'),
      );
    }
    final String today = device.today.isEmpty ? formatDay(DateTime.now()) : device.today;
    final String from = widget.from ?? addDays(today, -6);
    final String to = widget.to ?? today;
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      body: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: <Widget>[
                for (final EventGroup group in EventGroup.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(group.label),
                      selected: _group == group,
                      onSelected: (_) => setState(() => _group = group),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _PagedList<DeviceEvent>(
              // A chave recria a lista quando o filtro ou o aparelho mudam.
              key: ValueKey<String>('${device.id}-${_group.name}-$from-$to'),
              loader: (String? before) => ref
                  .read(reportsRepositoryProvider)
                  .events(device.id, from: from, to: to, types: _group.types, before: before),
              emptyIcon: Icons.event_available_outlined,
              emptyTitle: 'Nenhum evento no período',
              emptyMessage:
                  'Bloqueios, limites atingidos e mudanças de permissão aparecem aqui quando '
                  'acontecem.',
              itemBuilder: (BuildContext context, DeviceEvent event) {
                final ({String title, String? detail}) text = describeEvent(event);
                final ({IconData icon, Tone tone}) visual = _eventVisual(event);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: visual.tone.background(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(visual.icon, size: 20, color: visual.tone.foreground(context)),
                      ),
                      title: Text(text.title),
                      subtitle: Text(
                        text.detail == null
                            ? formatRelativeMs(event.ts)
                            : '${text.detail}\n${formatRelativeMs(event.ts)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      isThreeLine: text.detail != null,
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

/// Historico de navegacao do navegador gerenciado, com o que foi bloqueado e o motivo.
class BrowsingPage extends ConsumerStatefulWidget {
  const BrowsingPage({this.from, this.to, super.key});

  final String? from;
  final String? to;

  @override
  ConsumerState<BrowsingPage> createState() => _BrowsingPageState();
}

class _BrowsingPageState extends ConsumerState<BrowsingPage> {
  bool _onlyBlocked = false;

  @override
  Widget build(BuildContext context) {
    final Device? device = ref.watch(selectedDeviceProvider);
    final ThemeData theme = Theme.of(context);
    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Histórico de navegação')),
        body: const EmptyState(icon: Icons.travel_explore, title: 'Nenhum aparelho vinculado'),
      );
    }
    final String today = device.today.isEmpty ? formatDay(DateTime.now()) : device.today;
    final String from = widget.from ?? addDays(today, -6);
    final String to = widget.to ?? today;
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de navegação')),
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
                  selected: _onlyBlocked,
                  onSelected: (bool value) => setState(() => _onlyBlocked = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: _PagedList<BrowsingEntry>(
              key: ValueKey<String>('${device.id}-$from-$to'),
              loader: (String? before) => ref
                  .read(reportsRepositoryProvider)
                  .browsing(device.id, from: from, to: to, before: before),
              emptyIcon: Icons.travel_explore,
              emptyTitle: 'Nenhuma página registrada',
              emptyMessage:
                  'O histórico existe só para o navegador ParentaLynx. Páginas abertas em '
                  'outros navegadores ou apps não são registradas.',
              itemBuilder: (BuildContext context, BrowsingEntry entry) {
                if (_onlyBlocked && !entry.blocked) {
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
                            entry.title.isEmpty ? entry.domain : entry.title,
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
                                  formatRelativeMs(entry.ts),
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
