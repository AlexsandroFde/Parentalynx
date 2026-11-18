import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/time/clock.dart';
import '../../../../../core/time/formatters.dart';
import '../../../domain/entities/browsing_entry.dart';
import '../../../domain/entities/report_period.dart';
import '../../../domain/usecases/list_browsing_history.dart';
import '../paging/paged_list.dart';

part 'browsing_history_event.dart';
part 'browsing_history_state.dart';

/// Historico do navegador gerenciado no periodo, com paginacao, troca de periodo, o filtro de
/// bloqueados e a busca nas paginas carregadas.
class BrowsingHistoryBloc extends Bloc<BrowsingHistoryEvent, BrowsingHistoryState> {
  BrowsingHistoryBloc({required this._listBrowsingHistory, required this._clock})
    : super(const BrowsingHistoryState()) {
    on<BrowsingHistoryStarted>(_onStarted, transformer: restartable());
    on<BrowsingHistoryPeriodChanged>(_onPeriodChanged, transformer: restartable());
    on<BrowsingHistoryOnlyBlockedChanged>(_onOnlyBlockedChanged);
    on<BrowsingHistoryQueryChanged>(_onQueryChanged);
    on<BrowsingHistoryRefreshRequested>(_onRefreshRequested, transformer: droppable());
    on<BrowsingHistoryMoreRequested>(_onMoreRequested, transformer: droppable());
    on<BrowsingHistoryRetried>(_onRetried, transformer: droppable());
  }

  final ListBrowsingHistory _listBrowsingHistory;
  final Clock _clock;

  String? _deviceId;
  String _today = '';
  String _from = '';
  String _to = '';

  Future<void> _onStarted(BrowsingHistoryStarted event, Emitter<BrowsingHistoryState> emit) async {
    _today = quotaDayOf(event.deviceToday, _clock.now());
    _deviceId = event.deviceId;
    _from = event.from ?? addDays(_today, -6);
    _to = event.to ?? _today;
    await _reload(emit);
  }

  Future<void> _onPeriodChanged(
    BrowsingHistoryPeriodChanged event,
    Emitter<BrowsingHistoryState> emit,
  ) async {
    final ReportPeriod period = ReportPeriod.custom(event.from, event.to, today: _today);
    _from = period.from;
    _to = period.to;
    await _reload(emit);
  }

  void _onOnlyBlockedChanged(
    BrowsingHistoryOnlyBlockedChanged event,
    Emitter<BrowsingHistoryState> emit,
  ) {
    emit(state.copyWith(onlyBlocked: event.onlyBlocked));
  }

  void _onQueryChanged(BrowsingHistoryQueryChanged event, Emitter<BrowsingHistoryState> emit) {
    emit(state.copyWith(query: event.query));
  }

  Future<void> _onRefreshRequested(
    BrowsingHistoryRefreshRequested event,
    Emitter<BrowsingHistoryState> emit,
  ) async {
    final String from = _from;
    final String to = _to;
    final PageLoader<BrowsingEntry>? load = _loader();
    if (load == null) {
      event.completer?.complete(null);
      return;
    }
    final PagedListState<BrowsingEntry> next = await PagedList.first<BrowsingEntry>(load);
    final AppFailure? failure = next is PagedListError<BrowsingEntry> ? next.failure : null;
    // Um periodo escolhido durante a recarga vale mais que ela; uma falha mantem a lista.
    final bool outdated = _from != from || _to != to;
    if (!outdated && (failure == null || state.list is! PagedListLoaded<BrowsingEntry>)) {
      emit(state.copyWith(list: next));
    }
    event.completer?.complete(failure);
  }

  Future<void> _onMoreRequested(
    BrowsingHistoryMoreRequested event,
    Emitter<BrowsingHistoryState> emit,
  ) async {
    await _loadMore(emit);
  }

  Future<void> _onRetried(BrowsingHistoryRetried event, Emitter<BrowsingHistoryState> emit) async {
    if (state.list is PagedListLoaded<BrowsingEntry>) {
      await _loadMore(emit);
    } else {
      await _reload(emit);
    }
  }

  Future<void> _reload(Emitter<BrowsingHistoryState> emit) async {
    final PageLoader<BrowsingEntry>? load = _loader();
    if (load == null) {
      return;
    }
    emit(state.copyWith(list: const PagedListLoading<BrowsingEntry>(), from: _from, to: _to));
    emit(state.copyWith(list: await PagedList.first<BrowsingEntry>(load)));
  }

  Future<void> _loadMore(Emitter<BrowsingHistoryState> emit) async {
    final PagedListLoaded<BrowsingEntry>? loading = PagedList.startMore<BrowsingEntry>(state.list);
    final PageLoader<BrowsingEntry>? load = _loader();
    if (loading == null || load == null) {
      return;
    }
    emit(state.copyWith(list: loading));
    emit(state.copyWith(list: await PagedList.more<BrowsingEntry>(loading, load)));
  }

  PageLoader<BrowsingEntry>? _loader() {
    final String? deviceId = _deviceId;
    if (deviceId == null) {
      return null;
    }
    final String from = _from;
    final String to = _to;
    return (String? before) {
      return _listBrowsingHistory(deviceId, from: from, to: to, before: before);
    };
  }
}
