import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/bloc/form_status.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../domain/entities/credential_errors.dart';
import '../../../domain/entities/guardian_session.dart';
import '../../../domain/services/credentials_policy.dart';
import '../../../domain/usecases/sign_in.dart';
import '../../messages/auth_messages.dart';

part 'login_event.dart';
part 'login_state.dart';

/// Formulario de entrada em uma conta que ja existe.
///
/// Ao entrar, a sessao do dominio passa a "aberta" e o roteador leva ao painel: este BLoC
/// nao precisa avisar ninguem.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required this._signIn}) : super(const LoginState()) {
    on<LoginSubmitted>(_onSubmitted, transformer: droppable());
  }

  final SignIn _signIn;

  Future<void> _onSubmitted(LoginSubmitted event, Emitter<LoginState> emit) async {
    final CredentialErrors errors = CredentialsPolicy.validateLogin(
      email: event.email,
      password: event.password,
    );
    if (!errors.isEmpty) {
      emit(LoginState(errors: errors));
      return;
    }
    emit(const LoginState(status: FormStatus.submitting));
    final Result<AuthenticatedSession> result = await _signIn(
      email: event.email,
      password: event.password,
    );
    switch (result) {
      case Ok<AuthenticatedSession>():
        emit(const LoginState(status: FormStatus.succeeded));
      case Err<AuthenticatedSession>(:final AppFailure failure):
        emit(LoginState(errors: loginErrorsFor(failure)));
    }
  }
}
