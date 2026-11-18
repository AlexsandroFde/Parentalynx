import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/platform/native_api.g.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/user_role/data/repositories/native_user_role_repository.dart';
import 'package:parentalynx/features/user_role/domain/entities/user_role.dart';
import 'package:parentalynx/features/user_role/domain/usecases/change_user_role.dart';
import 'package:parentalynx/features/user_role/presentation/bloc/user_role_bloc.dart';

import '../../support/native_doubles.dart';
import '../../support/test_dependencies.dart';

void main() {
  test('trocar o perfil grava no lado nativo e avisa quem observa', () async {
    final TestDependencies deps = TestDependencies();
    addTearDown(deps.dispose);
    final UserRoleBloc bloc = deps.di<UserRoleBloc>();
    expect(bloc.state.role, UserRole.unset);
    final Future<UserRoleState> changed = bloc.stream.firstWhere(
      (UserRoleState state) => state.role == UserRole.child,
    );

    final Result<void> result = await deps.di<ChangeUserRole>()(UserRole.child);

    expect(result.isOk, isTrue);
    verify(() => deps.native.mode.setMode(AppMode.child)).called(1);
    expect((await changed).role, UserRole.child);
  });

  test('o lado nativo pode recusar a troca com o aparelho vinculado', () async {
    final TestDependencies deps = TestDependencies(role: UserRole.child);
    addTearDown(deps.dispose);
    when(() => deps.native.mode.setMode(any()))
        .thenThrow(PlatformException(code: 'mode_locked', message: 'Desvincule o aparelho antes.'));

    final Result<void> result = await deps.di<ChangeUserRole>()(UserRole.unset);

    final AppFailure failure = result.failureOrNull!;
    expect(failure, isA<NativeFailure>());
    expect((failure as NativeFailure).code, NativeErrorCode.modeLocked);
    expect(failure.message, 'Desvincule o aparelho antes.');
    expect(deps.di<UserRoleBloc>().state.role, UserRole.child);
  });

  test('pedir o perfil atual nao fala com o lado nativo', () async {
    final TestDependencies deps = TestDependencies(role: UserRole.guardian);
    addTearDown(deps.dispose);
    await deps.di<ChangeUserRole>()(UserRole.guardian);
    verifyNever(() => deps.native.mode.setMode(any()));
  });

  test('perfil inicial cai em "nao escolhido" quando a ponte falha', () async {
    final MockAppModeApi api = MockAppModeApi();
    when(api.getMode).thenThrow(PlatformException(code: 'channel-error'));
    expect(await NativeUserRoleRepository.readInitial(api), UserRole.unset);
    when(api.getMode).thenAnswer((_) async => AppMode.guardian);
    expect(await NativeUserRoleRepository.readInitial(api), UserRole.guardian);
  });
}
