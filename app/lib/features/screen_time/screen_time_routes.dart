import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../child_device/domain/entities/child_device.dart';
import '../device_policy/presentation/widgets/selected_device_gate.dart';
import 'presentation/bloc/screen_time/screen_time_bloc.dart';
import 'presentation/bloc/time_requests/time_requests_bloc.dart';
import 'presentation/pages/daily_limit_page.dart';
import 'presentation/pages/time_requests_page.dart';

/// Paginas de tempo de tela abaixo da aba Regras. Caminhos relativos a `GuardianPaths.rules`.
List<RouteBase> screenTimeRuleRoutes(GetIt di) {
  return <RouteBase>[
    GoRoute(
      path: 'limit',
      builder: (BuildContext context, GoRouterState state) {
        return SelectedDeviceGate(
          title: 'Limite diário',
          builder: (BuildContext context, ChildDevice device) {
            return BlocProvider<ScreenTimeBloc>(
              key: ValueKey<String>('daily-limit-${device.id}'),
              create: (BuildContext context) =>
                  di<ScreenTimeBloc>()..add(ScreenTimeStarted(device.id)),
              child: DailyLimitPage(device: device),
            );
          },
        );
      },
    ),
  ];
}

/// Pedidos de tempo, abaixo da aba Alertas. Caminho relativo a `GuardianPaths.alerts`.
List<RouteBase> screenTimeAlertRoutes(GetIt di) {
  return <RouteBase>[
    GoRoute(
      path: 'time-requests',
      builder: (BuildContext context, GoRouterState state) {
        return BlocProvider<TimeRequestsBloc>(
          create: (BuildContext context) =>
              di<TimeRequestsBloc>()..add(const TimeRequestsStarted()),
          child: const TimeRequestsPage(),
        );
      },
    ),
  ];
}
