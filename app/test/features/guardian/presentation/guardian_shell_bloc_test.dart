import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/navigation/launch_action.dart';
import 'package:parentalynx/features/guardian/domain/usecases/watch_launch_action.dart';
import 'package:parentalynx/features/guardian/presentation/bloc/shell/guardian_shell_bloc.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeLaunchActionSource source;

  setUp(() => source = FakeLaunchActionSource());

  GuardianShellBloc build() => GuardianShellBloc(launchAction: WatchLaunchAction(source));

  blocTest<GuardianShellBloc, GuardianShellState>(
    'acompanha a acao de abertura e consome a de alertas depois de tratada',
    build: build,
    act: (GuardianShellBloc bloc) async {
      bloc.add(const GuardianShellStarted());
      await pumpEventQueue();
      source.open(LaunchAction.alerts);
      await pumpEventQueue();
      expect(bloc.state.opensAlerts, isTrue);
      bloc.add(const GuardianShellLaunchActionHandled());
    },
    expect: () => const <GuardianShellState>[
      // Sem acao pendente ao abrir.
      GuardianShellState(),
      GuardianShellState(pendingAction: LaunchAction.alerts),
      GuardianShellState(),
    ],
    verify: (_) => expect(source.pending, isNull),
  );

  blocTest<GuardianShellBloc, GuardianShellState>(
    'acao pendente antes de o painel abrir tambem chega',
    setUp: () => source.open(LaunchAction.alerts),
    build: build,
    act: (GuardianShellBloc bloc) => bloc.add(const GuardianShellStarted()),
    expect: () => const <GuardianShellState>[
      GuardianShellState(pendingAction: LaunchAction.alerts),
    ],
  );

  blocTest<GuardianShellBloc, GuardianShellState>(
    'acoes do modo crianca nao sao consumidas pelo painel',
    setUp: () => source.open(LaunchAction.childHome),
    build: build,
    act: (GuardianShellBloc bloc) async {
      bloc.add(const GuardianShellStarted());
      await pumpEventQueue();
      bloc.add(const GuardianShellLaunchActionHandled());
    },
    expect: () => const <GuardianShellState>[
      GuardianShellState(pendingAction: LaunchAction.childHome),
    ],
    verify: (GuardianShellBloc bloc) {
      expect(bloc.state.opensAlerts, isFalse);
      expect(source.pending, LaunchAction.childHome);
    },
  );
}
