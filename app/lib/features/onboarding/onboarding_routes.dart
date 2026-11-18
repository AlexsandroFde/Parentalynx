import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_paths.dart';
import '../server_config/presentation/bloc/server_config_bloc.dart';
import 'presentation/bloc/onboarding/onboarding_bloc.dart';
import 'presentation/pages/welcome_page.dart';

/// Rotas da configuracao inicial: as boas-vindas ([OnboardingPaths.welcome]), com a escolha
/// do papel deste aparelho e a folha do servidor.
List<RouteBase> onboardingRoutes(GetIt di) {
  return <RouteBase>[
    GoRoute(
      path: OnboardingPaths.welcome,
      builder: (BuildContext context, GoRouterState state) {
        return MultiBlocProvider(
          providers: <BlocProvider<Object?>>[
            BlocProvider<ServerConfigBloc>(
              create: (BuildContext context) => di<ServerConfigBloc>(),
            ),
            BlocProvider<OnboardingBloc>(create: (BuildContext context) => di<OnboardingBloc>()),
          ],
          child: const WelcomePage(),
        );
      },
    ),
  ];
}
