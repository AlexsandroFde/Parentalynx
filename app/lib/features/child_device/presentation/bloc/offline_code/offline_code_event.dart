part of 'offline_code_bloc.dart';

sealed class OfflineCodeEvent extends Equatable {
  const OfflineCodeEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A folha do codigo abriu: atualiza o codigo e a contagem a cada segundo.
final class OfflineCodeStarted extends OfflineCodeEvent {
  const OfflineCodeStarted();
}
