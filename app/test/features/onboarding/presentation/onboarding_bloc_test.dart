import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/bloc/action_status.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/onboarding/presentation/bloc/onboarding/onboarding_bloc.dart';
import 'package:parentalynx/features/server_config/domain/usecases/watch_server_address.dart';
import 'package:parentalynx/features/user_role/domain/entities/user_role.dart';
import 'package:parentalynx/features/user_role/domain/usecases/change_user_role.dart';

class _MockWatchServerAddress extends Mock implements WatchServerAddress {}

class _MockChangeUserRole extends Mock implements ChangeUserRole {}

void main() {
  late _MockWatchServerAddress watchServerAddress;
  late _MockChangeUserRole changeUserRole;
  const NativeFailure denied = NativeFailure(
    code: NativeErrorCode.adminAuthRequired,
    message: 'Autenticação do responsável necessária.',
  );

  setUpAll(() => registerFallbackValue(UserRole.unset));

  setUp(() {
    watchServerAddress = _MockWatchServerAddress();
    changeUserRole = _MockChangeUserRole();
    when(() => watchServerAddress.isConfigured).thenReturn(true);
    when(() => changeUserRole(any())).thenAnswer((_) async => okVoid);
  });

  OnboardingBloc build() {
    return OnboardingBloc(watchServerAddress: watchServerAddress, changeUserRole: changeUserRole);
  }

  blocTest<OnboardingBloc, OnboardingState>(
    'com servidor, grava o papel escolhido',
    build: build,
    act: (OnboardingBloc bloc) => bloc.add(const OnboardingRoleChosen(UserRole.guardian)),
    expect: () => const <OnboardingState>[
      OnboardingState(choosing: UserRole.guardian, action: ActionRunning()),
      OnboardingState(action: ActionSucceeded()),
    ],
    verify: (_) => verify(() => changeUserRole(UserRole.guardian)).called(1),
  );

  blocTest<OnboardingBloc, OnboardingState>(
    'sem servidor, espera a folha do servidor e continua quando ele e gravado',
    setUp: () {
      final List<bool> configured = <bool>[false, true];
      when(() => watchServerAddress.isConfigured).thenAnswer((_) => configured.removeAt(0));
    },
    build: build,
    act: (OnboardingBloc bloc) async {
      bloc.add(const OnboardingRoleChosen(UserRole.child));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const OnboardingServerSheetClosed(saved: true));
    },
    expect: () => const <OnboardingState>[
      OnboardingState(awaitingServerFor: UserRole.child),
      OnboardingState(choosing: UserRole.child, action: ActionRunning()),
      OnboardingState(action: ActionSucceeded()),
    ],
  );

  blocTest<OnboardingBloc, OnboardingState>(
    'folha do servidor fechada sem gravar desiste da escolha',
    setUp: () => when(() => watchServerAddress.isConfigured).thenReturn(false),
    build: build,
    act: (OnboardingBloc bloc) async {
      bloc.add(const OnboardingRoleChosen(UserRole.child));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const OnboardingServerSheetClosed(saved: false));
    },
    expect: () => const <OnboardingState>[
      OnboardingState(awaitingServerFor: UserRole.child),
      OnboardingState(),
    ],
    verify: (_) => verifyNever(() => changeUserRole(any())),
  );

  blocTest<OnboardingBloc, OnboardingState>(
    'recusa do lado nativo vira falha e libera as opcoes',
    setUp: () {
      when(() => changeUserRole(UserRole.guardian))
          .thenAnswer((_) async => const Err<void>(denied));
    },
    build: build,
    act: (OnboardingBloc bloc) => bloc.add(const OnboardingRoleChosen(UserRole.guardian)),
    expect: () => const <OnboardingState>[
      OnboardingState(choosing: UserRole.guardian, action: ActionRunning()),
      OnboardingState(action: ActionFailed(denied)),
    ],
  );
}
