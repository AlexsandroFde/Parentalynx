import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../domain/entities/device_event.dart';
import '../../domain/entities/event_group.dart';
import '../../domain/entities/report_period.dart';
import '../bloc/device_events/device_events_bloc.dart';
import '../texts/event_texts.dart';
import '../texts/report_help.dart';
import '../widgets/event_visual.dart';
import '../widgets/paged_list_view.dart';
import '../widgets/reports_device_gate.dart';

/// Eventos registrados pelo aparelho no periodo, agrupados por dia e com filtro por tipo.
/// Cada evento aparece em palavras simples, com um icone no tom da gravidade.
///
/// Espera um [DeviceEventsBloc] acima na arvore.
class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  static const String title = 'Eventos do aparelho';

  @override
  Widget build(BuildContext context) {
    final DeviceEventsState state = context.watch<DeviceEventsBloc>().state;
    final DeviceEventsBloc bloc = context.read<DeviceEventsBloc>();
    final ChildDevice? device = context.select<DevicesBloc, ChildDevice?>(
      (DevicesBloc devices) => devices.state.selected,
    );
    final String today = quotaDayOf(device?.today ?? '', context.read<Clock>().now());
    final String group = eventGroupLabel(state.group).toLowerCase();
    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
        actions: const <Widget>[
          HelpButton(title: 'Sobre os eventos', topics: eventsHelpTopics),
          SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: AppPageBody(
        onRefresh: () => refreshKeepingList(
          context,
          (completer) => bloc.add(DeviceEventsRefreshRequested(completer: completer)),
        ),
        children: <Widget>[
          if (device != null) ReportHeader(device: device),
          if (state.from.isNotEmpty) ...<Widget>[
            ReportPeriodRow(
              from: state.from,
              to: state.to,
              today: today.compareTo(state.to) < 0 ? state.to : today,
              onChanged: (String from, String to) {
                bloc.add(DeviceEventsPeriodChanged(from: from, to: to));
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppChoiceChips<EventGroup>(
            choices: <AppChoice<EventGroup>>[
              for (final EventGroup value in EventGroup.values)
                AppChoice<EventGroup>(value: value, label: eventGroupLabel(value)),
            ],
            selected: state.group,
            onSelected: (EventGroup value) => bloc.add(DeviceEventsGroupSelected(value)),
          ),
          const SizedBox(height: AppSpacing.xl),
          PagedListBody<DeviceEvent>(
            state: state.list,
            timeOf: (DeviceEvent event) => event.ts,
            subject: 'os eventos',
            onRetry: () => bloc.add(const DeviceEventsRetried()),
            onLoadMore: () => bloc.add(const DeviceEventsMoreRequested()),
            rowBuilder: (BuildContext context, DeviceEvent event) => _EventRow(event: event),
            empty: AppPanel(
              child: EmptyState(
                compact: true,
                icon: AppIcons.available,
                title: state.group == EventGroup.all
                    ? 'Nenhum evento no período'
                    : 'Nenhum evento de $group no período',
                message:
                    'Bloqueios, limites atingidos, pedidos de tempo e mudanças de permissão '
                    'aparecem aqui quando acontecem.',
                actionLabel: state.group == EventGroup.all ? null : 'Ver todos os eventos',
                onAction: state.group == EventGroup.all
                    ? null
                    : () => bloc.add(const DeviceEventsGroupSelected(EventGroup.all)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final DeviceEvent event;

  @override
  Widget build(BuildContext context) {
    final ({String title, String? detail}) text = describeEvent(event);
    final ({IconData icon, Tone tone}) visual = eventVisual(event);
    return AppListRow(
      leading: AppIconTile(icon: visual.icon, tone: visual.tone),
      title: text.title,
      titleStyle: context.text.bodyLarge,
      subtitle: text.detail,
      trailing: AppRowValue(formatClockMs(event.ts)),
    );
  }
}
