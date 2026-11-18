part of 'browser_bloc.dart';

sealed class BrowserEvent extends Equatable {
  const BrowserEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// O navegador abriu: le a configuracao e passa a receber os enderecos pedidos por outros
/// apps.
final class BrowserStarted extends BrowserEvent {
  const BrowserStarted();
}

/// Ler de novo a configuracao. A tela pede ao voltar ao primeiro plano, porque as regras
/// podem ter mudado.
final class BrowserSettingsRefreshRequested extends BrowserEvent {
  const BrowserSettingsRefreshRequested();
}

/// A pessoa confirmou o texto da barra: um endereco ou uma busca.
final class BrowserAddressSubmitted extends BrowserEvent {
  const BrowserAddressSubmitted(this.input);

  final String input;

  @override
  List<Object?> get props => <Object?>[input];
}

/// Outro app pediu para abrir um endereco (link tocado).
final class BrowserUrlRequested extends BrowserEvent {
  const BrowserUrlRequested(this.url);

  final String url;

  @override
  List<Object?> get props => <Object?>[url];
}

final class BrowserReloadRequested extends BrowserEvent {
  const BrowserReloadRequested();
}

/// Voltar uma pagina. A tela so pede quando ha pagina aberta ([BrowserReady.hasPage]); na
/// pagina inicial o botao voltar fecha o navegador.
final class BrowserBackRequested extends BrowserEvent {
  const BrowserBackRequested();
}

final class BrowserForwardRequested extends BrowserEvent {
  const BrowserForwardRequested();
}

/// Voltar a pagina inicial do navegador.
final class BrowserHomeRequested extends BrowserEvent {
  const BrowserHomeRequested();
}

/// A tela ja mostrou o aviso passageiro.
final class BrowserNoticeCleared extends BrowserEvent {
  const BrowserNoticeCleared();
}

/// O motor quer navegar para [url]. A resposta vai em [decision]: verdadeiro deixa seguir.
final class BrowserNavigationRequested extends BrowserEvent {
  const BrowserNavigationRequested({
    required this.url,
    required this.isMainFrame,
    required this.decision,
  });

  final String url;
  final bool isMainFrame;
  final Completer<bool> decision;

  @override
  List<Object?> get props => <Object?>[url, isMainFrame, decision];
}

final class BrowserPageStarted extends BrowserEvent {
  const BrowserPageStarted(this.url);

  final String url;

  @override
  List<Object?> get props => <Object?>[url];
}

final class BrowserPageFinished extends BrowserEvent {
  const BrowserPageFinished(this.url);

  final String url;

  @override
  List<Object?> get props => <Object?>[url];
}

final class BrowserProgressChanged extends BrowserEvent {
  const BrowserProgressChanged(this.progress);

  final int progress;

  @override
  List<Object?> get props => <Object?>[progress];
}

/// O endereco da pagina mudou sem nova navegacao (ancora, historico da pagina).
final class BrowserUrlChanged extends BrowserEvent {
  const BrowserUrlChanged(this.url);

  final String url;

  @override
  List<Object?> get props => <Object?>[url];
}

/// A pagina principal nao carregou.
final class BrowserMainFrameFailed extends BrowserEvent {
  const BrowserMainFrameFailed(this.description);

  final String description;

  @override
  List<Object?> get props => <Object?>[description];
}
