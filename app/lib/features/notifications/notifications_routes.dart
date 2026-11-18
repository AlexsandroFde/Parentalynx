import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_paths.dart';
import 'presentation/bloc/notification_prefs/notification_prefs_bloc.dart';
import 'presentation/pages/alerts_center_page.dart';
import 'presentation/pages/notification_prefs_page.dart';

/// Rota da aba Alertas (`GuardianPaths.alerts`) com as preferencias de notificacao abaixo.
///
/// A central usa os BLoCs do painel (`NotificationsBloc`, `NotificationPermissionBloc` e
/// `DevicesBloc`), que vivem no escopo da sessao. [children] recebe as outras telas que ficam
/// abaixo da aba (por exemplo os pedidos de tempo, em `time-requests`).
RouteBase alertsRoute(GetIt di, {List<RouteBase> children = const <RouteBase>[]}) {
  return GoRoute(
    path: GuardianPaths.alerts,
    builder: (BuildContext context, GoRouterState state) => const AlertsCenterPage(),
    routes: <RouteBase>[
      GoRoute(
        path: 'preferences',
        builder: (BuildContext context, GoRouterState state) {
          return BlocProvider<NotificationPrefsBloc>(
            create: (BuildContext context) {
              return di<NotificationPrefsBloc>()..add(const NotificationPrefsStarted());
            },
            child: const NotificationPrefsPage(),
          );
        },
      ),
      ...children,
    ],
  );
}
