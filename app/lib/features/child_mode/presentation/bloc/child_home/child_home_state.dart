part of 'child_home_bloc.dart';

/// Tom de um aviso passageiro da tela inicial.
enum HomeNoticeKind { success, warning, failure }

/// Aviso passageiro da tela inicial (resultado de um comando).
final class HomeNotice extends Equatable {
  const HomeNotice({required this.kind, required this.message});

  HomeNotice.failure(AppFailure failure) : kind = HomeNoticeKind.failure, message = failure.message;

  final HomeNoticeKind kind;
  final String message;

  @override
  List<Object?> get props => <Object?>[kind, message];
}

final class ChildHomeState extends Equatable {
  const ChildHomeState({this.summary, this.syncing = false, this.notice});

  /// Dados que mudam devagar. Nulo enquanto a primeira consulta nao deu certo: os cartoes
  /// mostram o carregamento.
  final ChildHomeSummary? summary;

  /// "Sincronizar agora" em andamento.
  final bool syncing;

  /// Aviso a mostrar. Cada comando limpa o aviso anterior antes de comecar, entao dois avisos
  /// iguais seguidos aparecem duas vezes.
  final HomeNotice? notice;

  /// Copia mantendo o aviso atual.
  ChildHomeState copyWith({ChildHomeSummary? summary, bool? syncing}) {
    return ChildHomeState(
      summary: summary ?? this.summary,
      syncing: syncing ?? this.syncing,
      notice: notice,
    );
  }

  /// Copia trocando o aviso (nulo limpa).
  ChildHomeState withNotice(HomeNotice? notice) {
    return ChildHomeState(summary: summary, syncing: syncing, notice: notice);
  }

  @override
  List<Object?> get props => <Object?>[summary, syncing, notice];
}
