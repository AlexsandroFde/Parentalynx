import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/bloc/action_status.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/onboarding/presentation/bloc/onboarding/onboarding_bloc.dart';
import 'package:parentalynx/features/user_role/domain/entities/user_role.dart';
import 'package:parentalynx/features/user_role/domain/usecases/change_user_role.dart';

class _MockChangeUserRole extends Mock implements ChangeUserRole {}

void main() {
  late _MockChangeUserRole changeUserRole;
  const NativeFailure denied = NativeFailure(
    code: NativeErrorCode.adminAuthRequired,
    message: 'Autenticação do responsável necessária.',
  );

  setUpAll(() => registerFallbackValue(UserRole.unset));

  setUp(() {
    changeUserRole = _MockChangeUserRole();
    when(() => changeUserRole(any())).thenAnswer((_) async => okVoid);
  });

  OnboardingBloc build() => OnboardingBloc(changeUserRole: changeUserRole);

  blocTest<OnboardingBloc, OnboardingState>(
    'grava o papel escolhido',
    build: build,
    act: (OnboardingBloc bloc) => bloc.add(const OnboardingRoleChosen(UserRole.guardian)),
    expect: () => const <OnboardingState>[
      OnboardingState(choosing: UserRole.guardian, action: ActionRunning()),
      OnboardingState(action: ActionSucceeded()),
    ],
    verify: (_) => verify(() => changeUserRole(UserRole.guardian)).called(1),
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
