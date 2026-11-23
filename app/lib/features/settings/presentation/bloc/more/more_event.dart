part of 'more_bloc.dart';

sealed class MoreEvent extends Equatable {
  const MoreEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A aba abriu: busca a versao do app.
final class MoreStarted extends MoreEvent {
  const MoreStarted();
}
