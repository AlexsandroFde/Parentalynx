part of 'web_filter_bloc.dart';

sealed class WebFilterEvent extends Equatable {
  const WebFilterEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela de navegacao abriu para um aparelho (ou a pessoa pediu para tentar de novo).
final class WebFilterStarted extends WebFilterEvent {
  const WebFilterStarted(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => <Object?>[deviceId];
}

/// Liga ou desliga o navegador gerenciado no aparelho.
final class WebManagedBrowserChanged extends WebFilterEvent {
  const WebManagedBrowserChanged(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => <Object?>[enabled];
}

/// Liga ou desliga o registro do historico de navegacao.
final class WebHistoryLoggingChanged extends WebFilterEvent {
  const WebHistoryLoggingChanged(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => <Object?>[enabled];
}

/// Liga ou desliga a busca segura.
final class WebSafeSearchChanged extends WebFilterEvent {
  const WebSafeSearchChanged(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => <Object?>[enabled];
}

/// Liga ou desliga o filtro DNS familiar.
final class WebSafeDnsChanged extends WebFilterEvent {
  const WebSafeDnsChanged(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => <Object?>[enabled];
}

/// Troca o modo de filtragem (lista de bloqueio ou so autorizados).
final class WebModeChanged extends WebFilterEvent {
  const WebModeChanged(this.mode);

  final WebMode mode;

  @override
  List<Object?> get props => <Object?>[mode];
}

/// Bloqueia ou libera uma categoria de sites.
final class WebCategoryToggled extends WebFilterEvent {
  const WebCategoryToggled({required this.category, required this.blocked});

  final WebCategory category;
  final bool blocked;

  @override
  List<Object?> get props => <Object?>[category, blocked];
}

/// Acrescenta um site ja conferido a uma lista.
final class WebDomainAdded extends WebFilterEvent {
  const WebDomainAdded({required this.list, required this.domain});

  final WebDomainList list;
  final String domain;

  @override
  List<Object?> get props => <Object?>[list, domain];
}

/// Remove um site de uma lista.
final class WebDomainRemoved extends WebFilterEvent {
  const WebDomainRemoved({required this.list, required this.domain});

  final WebDomainList list;
  final String domain;

  @override
  List<Object?> get props => <Object?>[list, domain];
}

/// Envia o rascunho ao servidor.
final class WebFilterSaveRequested extends WebFilterEvent {
  const WebFilterSaveRequested();
}

/// Descarta as alteracoes locais.
final class WebFilterDiscardRequested extends WebFilterEvent {
  const WebFilterDiscardRequested();
}

/// O servidor informou uma versao nova da politica do aparelho.
final class _WebFilterServerVersionChanged extends WebFilterEvent {
  const _WebFilterServerVersionChanged(this.version);

  final int version;

  @override
  List<Object?> get props => <Object?>[version];
}
