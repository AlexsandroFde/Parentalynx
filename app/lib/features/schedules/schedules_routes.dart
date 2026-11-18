import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../child_device/domain/entities/child_device.dart';
import '../device_policy/presentation/widgets/selected_device_gate.dart';
import 'presentation/bloc/schedule/schedule_bloc.dart';
import 'presentation/pages/allowed_hours_page.dart';
import 'presentation/pages/block_periods_page.dart';

/// Paginas de horarios abaixo da aba Regras. Caminhos relativos a `GuardianPaths.rules`.
List<RouteBase> scheduleRuleRoutes(GetIt di) {
  Widget withBloc(ChildDevice device, String key, Widget page) {
    return BlocProvider<ScheduleBloc>(
      key: ValueKey<String>('$key-${device.id}'),
      create: (BuildContext context) => di<ScheduleBloc>()..add(ScheduleStarted(device.id)),
      child: page,
    );
  }

  return <RouteBase>[
    GoRoute(
      path: 'hours',
      builder: (BuildContext context, GoRouterState state) {
        return SelectedDeviceGate(
          title: 'Horários permitidos',
          builder: (BuildContext context, ChildDevice device) {
            return withBloc(device, 'allowed-hours', AllowedHoursPage(device: device));
          },
        );
      },
    ),
    GoRoute(
      path: 'periods',
      builder: (BuildContext context, GoRouterState state) {
        return SelectedDeviceGate(
          title: 'Períodos de bloqueio',
          builder: (BuildContext context, ChildDevice device) {
            return withBloc(device, 'block-periods', BlockPeriodsPage(device: device));
          },
        );
      },
    ),
  ];
}
