part of 'child_home_bloc.dart';

sealed class ChildHomeEvent extends Equatable {
  const ChildHomeEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela inicial abriu: carrega os dados e passa a atualiza-los periodicamente.
final class ChildHomeStarted extends ChildHomeEvent {
  const ChildHomeStarted();
}

/// Recarregar os dados que mudam devagar (temporizador, regras novas).
final class ChildHomeRefreshRequested extends ChildHomeEvent {
  const ChildHomeRefreshRequested();
}

/// A crianca tocou em "Sincronizar agora".
final class ChildHomeSyncRequested extends ChildHomeEvent {
  const ChildHomeSyncRequested();
}

/// A crianca tocou em "Abrir o navegador seguro".
final class ChildHomeBrowserRequested extends ChildHomeEvent {
  const ChildHomeBrowserRequested();
}

/// A crianca tocou em um app sempre liberado.
final class ChildHomeAppLaunchRequested extends ChildHomeEvent {
  const ChildHomeAppLaunchRequested(this.app);

  final AllowedApp app;

  @override
  List<Object?> get props => <Object?>[app];
}

/// Um pedido de tempo acabou de ser registrado pela folha de pedido.
final class ChildHomeTimeRequestSent extends ChildHomeEvent {
  const ChildHomeTimeRequestSent();
}
