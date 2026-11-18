import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/route_paths.dart';
import '../child_device/domain/entities/child_device.dart';
import 'presentation/bloc/activity_reports/activity_reports_bloc.dart';
import 'presentation/bloc/browsing_history/browsing_history_bloc.dart';
import 'presentation/bloc/day_timeline/day_timeline_bloc.dart';
import 'presentation/bloc/device_events/device_events_bloc.dart';
import 'presentation/pages/browsing_page.dart';
import 'presentation/pages/events_page.dart';
import 'presentation/pages/reports_page.dart';
import 'presentation/pages/sessions_page.dart';
import 'presentation/widgets/reports_device_gate.dart';

/// Rotas da aba "Relatórios": a raiz da aba ([GuardianPaths.reports]) e, abaixo dela, a linha
/// do tempo (`sessions?day=`), os eventos e a navegacao (`events` e `browsing`, com
/// `?from=&to=`).
///
/// As paginas usam o aparelho em foco do `DevicesBloc`, que precisa estar acima das rotas.
List<RouteBase> activityReportsRoutes(GetIt di) {
  return <RouteBase>[
    GoRoute(
      path: GuardianPaths.reports,
      builder: (BuildContext context, GoRouterState state) {
        return BlocProvider<ActivityReportsBloc>(
          create: (BuildContext context) => di<ActivityReportsBloc>(),
          child: const ReportsPage(),
        );
      },
      routes: <RouteBase>[
        GoRoute(
          path: 'sessions',
          builder: (BuildContext context, GoRouterState state) {
            final String? day = state.uri.queryParameters['day'];
            return ReportsDeviceGate(
              title: SessionsPage.title,
              icon: Icons.timeline,
              builder: (BuildContext context, ChildDevice device) {
                return BlocProvider<DayTimelineBloc>(
                  key: ValueKey<String>(device.id),
                  create: (BuildContext context) => di<DayTimelineBloc>()
                    ..add(
                      DayTimelineStarted(
                        deviceId: device.id,
                        deviceToday: device.today,
                        initialDay: day,
                      ),
                    ),
                  child: const SessionsPage(),
                );
              },
            );
          },
        ),
        GoRoute(
          path: 'events',
          builder: (BuildContext context, GoRouterState state) {
            final String? from = state.uri.queryParameters['from'];
            final String? to = state.uri.queryParameters['to'];
            return ReportsDeviceGate(
              title: EventsPage.title,
              icon: Icons.list_alt_outlined,
              builder: (BuildContext context, ChildDevice device) {
                return BlocProvider<DeviceEventsBloc>(
                  key: ValueKey<String>(device.id),
                  create: (BuildContext context) => di<DeviceEventsBloc>()
                    ..add(
                      DeviceEventsStarted(
                        deviceId: device.id,
                        deviceToday: device.today,
                        from: from,
                        to: to,
                      ),
                    ),
                  child: const EventsPage(),
                );
              },
            );
          },
        ),
        GoRoute(
          path: 'browsing',
          builder: (BuildContext context, GoRouterState state) {
            final String? from = state.uri.queryParameters['from'];
            final String? to = state.uri.queryParameters['to'];
            return ReportsDeviceGate(
              title: BrowsingPage.title,
              icon: Icons.travel_explore,
              builder: (BuildContext context, ChildDevice device) {
                return BlocProvider<BrowsingHistoryBloc>(
                  key: ValueKey<String>(device.id),
                  create: (BuildContext context) => di<BrowsingHistoryBloc>()
                    ..add(
                      BrowsingHistoryStarted(
                        deviceId: device.id,
                        deviceToday: device.today,
                        from: from,
                        to: to,
                      ),
                    ),
                  child: const BrowsingPage(),
                );
              },
            );
          },
        ),
      ],
    ),
  ];
}
