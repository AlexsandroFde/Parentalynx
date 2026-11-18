import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../child_device/domain/entities/child_device.dart';
import '../device_policy/presentation/widgets/selected_device_gate.dart';
import 'presentation/bloc/protection/protection_bloc.dart';
import 'presentation/bloc/web_filter/web_filter_bloc.dart';
import 'presentation/pages/protection_page.dart';
import 'presentation/pages/web_rules_page.dart';

/// Paginas de regras de bloqueio abaixo da aba Regras. Caminhos relativos a
/// `GuardianPaths.rules`.
List<RouteBase> blockingRuleRoutes(GetIt di) {
  return <RouteBase>[
    GoRoute(
      path: 'web',
      builder: (BuildContext context, GoRouterState state) {
        return SelectedDeviceGate(
          title: 'Navegação na internet',
          builder: (BuildContext context, ChildDevice device) {
            return BlocProvider<WebFilterBloc>(
              key: ValueKey<String>('web-rules-${device.id}'),
              create: (BuildContext context) =>
                  di<WebFilterBloc>()..add(WebFilterStarted(device.id)),
              child: WebRulesPage(device: device),
            );
          },
        );
      },
    ),
    GoRoute(
      path: 'protection',
      builder: (BuildContext context, GoRouterState state) {
        return SelectedDeviceGate(
          title: 'Proteção',
          builder: (BuildContext context, ChildDevice device) {
            return BlocProvider<ProtectionBloc>(
              key: ValueKey<String>('protection-${device.id}'),
              create: (BuildContext context) =>
                  di<ProtectionBloc>()..add(ProtectionStarted(device.id)),
              child: ProtectionPage(device: device),
            );
          },
        );
      },
    ),
  ];
}
