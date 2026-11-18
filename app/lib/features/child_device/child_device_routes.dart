import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_paths.dart';
import 'presentation/bloc/child_device/child_device_bloc.dart';
import 'presentation/bloc/offline_code/offline_code_bloc.dart';
import 'presentation/pages/device_detail_page.dart';
import 'presentation/pages/devices_page.dart';

/// Rotas da lista de aparelhos (`GuardianPaths.devices`) e do detalhe de cada aparelho.
///
/// A lista usa o `DevicesBloc` do escopo da sessao; o detalhe recebe o seu proprio BLoC.
List<RouteBase> childDeviceRoutes(GetIt di) {
  return <RouteBase>[
    GoRoute(
      path: GuardianPaths.devices,
      builder: (BuildContext context, GoRouterState state) => const DevicesPage(),
      routes: <RouteBase>[
        GoRoute(
          path: ':deviceId',
          builder: (BuildContext context, GoRouterState state) {
            final String deviceId = state.pathParameters['deviceId'] ?? '';
            return BlocProvider<ChildDeviceBloc>(
              create: (BuildContext context) {
                return di<ChildDeviceBloc>()..add(ChildDeviceStarted(deviceId));
              },
              child: DeviceDetailPage(
                offlineCodeBloc: (String secret) => di<OfflineCodeBloc>(param1: secret),
              ),
            );
          },
        ),
      ],
    ),
  ];
}
