import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/event_transformers.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/usecases/watch_user_role.dart';

part 'user_role_event.dart';
part 'user_role_state.dart';

/// Perfil do app (responsavel ou crianca), observado pelo roteador para escolher a area.
///
/// Nao troca o perfil: quem troca usa o caso de uso `ChangeUserRole`, e o repositorio avisa
/// este BLoC. Assim nenhuma funcionalidade precisa falar com ele diretamente.
class UserRoleBloc extends Bloc<UserRoleEvent, UserRoleState> {
  UserRoleBloc({required this._watchUserRole}) : super(UserRoleState(_watchUserRole.current)) {
    on<UserRoleSubscriptionRequested>(_onSubscriptionRequested, transformer: restartable());
  }

  final WatchUserRole _watchUserRole;

  Future<void> _onSubscriptionRequested(
    UserRoleSubscriptionRequested event,
    Emitter<UserRoleState> emit,
  ) {
    return emit.forEach<UserRole>(_watchUserRole(), onData: UserRoleState.new);
  }
}
