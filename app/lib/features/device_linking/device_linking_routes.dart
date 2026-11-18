import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_paths.dart';
import 'presentation/bloc/device_linking/device_linking_bloc.dart';
import 'presentation/pages/pairing_page.dart';

/// Rotas da vinculacao vista pelo responsavel ([GuardianPaths.pairing]). A tela fica fora das
/// abas do painel e espera o `DevicesBloc` acima da arvore.
List<RouteBase> deviceLinkingRoutes(GetIt di) {
  return <RouteBase>[
    GoRoute(
      path: GuardianPaths.pairing,
      builder: (BuildContext context, GoRouterState state) {
        return BlocProvider<DeviceLinkingBloc>(
          create: (BuildContext context) =>
              di<DeviceLinkingBloc>()..add(const DeviceLinkingStarted()),
          child: const PairingPage(),
        );
      },
    ),
  ];
}
