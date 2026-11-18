import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/navigation/launch_action.dart';
import 'package:parentalynx/features/child_mode/presentation/bloc/child_shell/child_shell_bloc.dart';
import 'package:parentalynx/features/device_linking/domain/entities/link_state.dart';
import 'package:parentalynx/features/device_linking/domain/repositories/i_link_state_repository.dart';

import '../../support/fakes.dart';
import '../../support/test_dependencies.dart';
import 'support/child_fakes.dart';

void main() {
  late TestDependencies deps;
  late FakeLaunchActionSource launch;

  setUp(() {
    launch = FakeLaunchActionSource();
    deps = childDependencies(launchActions: launch).deps;
    addTearDown(deps.dispose);
  });

  void setPhase(LinkPhase phase) {
    deps.di<ILinkStateRepository>().update(LinkState(phase));
  }

  Future<ChildShellBloc> start() async {
    final ChildShellBloc bloc = deps.di<ChildShellBloc>()..add(const ChildShellStarted());
    addTearDown(bloc.close);
    await pumpEventQueue();
    return bloc;
  }

  test('acao espera enquanto o vinculo e desconhecido e abre a tela quando fica pronto', () async {
    final ChildShellBloc bloc = await start();
    launch.open(LaunchAction.guardianArea);
    await pumpEventQueue();

    expect(bloc.state.destination, isNull);
    expect(launch.pending, LaunchAction.guardianArea);

    setPhase(LinkPhase.ready);
    await pumpEventQueue();
    expect(bloc.state.destination, ChildLaunchDestination.guardianArea);

    bloc.add(const ChildShellLaunchActionHandled());
    await pumpEventQueue();
    expect(launch.pending, isNull);
    expect(bloc.state.destination, isNull);
  });

  test('acao espera durante a configuracao inicial', () async {
    setPhase(LinkPhase.onboarding);
    final ChildShellBloc bloc = await start();

    launch.open(LaunchAction.permissions);
    await pumpEventQueue();

    expect(bloc.state.destination, isNull);
    expect(launch.pending, LaunchAction.permissions);
  });

  test('sem vinculo a acao e descartada', () async {
    setPhase(LinkPhase.unlinked);
    final ChildShellBloc bloc = await start();

    launch.open(LaunchAction.guardianArea);
    await pumpEventQueue();

    expect(launch.pending, isNull);
    expect(bloc.state.destination, isNull);
  });

  test('acao do modo responsavel e descartada no aparelho pronto', () async {
    setPhase(LinkPhase.ready);
    await start();

    launch.open(LaunchAction.alerts);
    await pumpEventQueue();

    expect(launch.pending, isNull);
  });

  test('cada acao leva a sua tela', () {
    ChildLaunchDestination? destination(LaunchAction action) {
      return ChildShellState(phase: LinkPhase.ready, pendingAction: action).destination;
    }

    expect(destination(LaunchAction.childHome), ChildLaunchDestination.home);
    expect(destination(LaunchAction.permissions), ChildLaunchDestination.permissions);
    expect(destination(LaunchAction.guardianArea), ChildLaunchDestination.guardianArea);
    expect(destination(LaunchAction.alerts), isNull);
  });
}
