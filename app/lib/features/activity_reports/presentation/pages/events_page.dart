import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../domain/entities/device_event.dart';
import '../../domain/entities/event_group.dart';
import '../bloc/device_events/device_events_bloc.dart';
import '../texts/event_texts.dart';
import '../widgets/paged_list_view.dart';

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
///
/// Espera um [DeviceEventsBloc] acima na arvore.
class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  static const String title = 'Eventos';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DeviceEventsState state = context.watch<DeviceEventsBloc>().state;
    final DeviceEventsBloc bloc = context.read<DeviceEventsBloc>();
    return Scaffold(
      appBar: AppBar(title: const Text(title)),
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
                      selected: state.group == group,
                      onSelected: (_) => bloc.add(DeviceEventsGroupSelected(group)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PagedListView<DeviceEvent>(
              state: state.list,
              onRetry: () => bloc.add(const DeviceEventsRetried()),
              onLoadMore: () => bloc.add(const DeviceEventsMoreRequested()),
              emptyIcon: Icons.event_available_outlined,
              emptyTitle: 'Nenhum evento no período',
              emptyMessage:
                  'Bloqueios, limites atingidos e mudanças de permissão aparecem aqui quando '
                  'acontecem.',
              itemBuilder: (BuildContext context, DeviceEvent event) {
                final DateTime now = context.read<Clock>().now();
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
                            ? formatRelativeMs(event.ts, now: now)
                            : '${text.detail}\n${formatRelativeMs(event.ts, now: now)}',
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
