import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/time/clock.dart';
import '../../../../../core/time/formatters.dart';
import '../../../domain/entities/browsing_entry.dart';
import '../../../domain/entities/report_period.dart';
import '../../../domain/usecases/list_browsing_history.dart';
import '../paging/paged_list.dart';

part 'browsing_history_event.dart';
part 'browsing_history_state.dart';

/// Historico do navegador gerenciado no periodo, com paginacao e o filtro de bloqueados.
class BrowsingHistoryBloc extends Bloc<BrowsingHistoryEvent, BrowsingHistoryState> {
  BrowsingHistoryBloc({required this._listBrowsingHistory, required this._clock})
    : super(const BrowsingHistoryState()) {
    on<BrowsingHistoryStarted>(_onStarted, transformer: restartable());
    on<BrowsingHistoryOnlyBlockedChanged>(_onOnlyBlockedChanged);
    on<BrowsingHistoryMoreRequested>(_onMoreRequested, transformer: droppable());
    on<BrowsingHistoryRetried>(_onRetried, transformer: droppable());
  }

  final ListBrowsingHistory _listBrowsingHistory;
  final Clock _clock;

  String? _deviceId;
  String _from = '';
  String _to = '';

  Future<void> _onStarted(BrowsingHistoryStarted event, Emitter<BrowsingHistoryState> emit) async {
    final String today = quotaDayOf(event.deviceToday, _clock.now());
    _deviceId = event.deviceId;
    _from = event.from ?? addDays(today, -6);
    _to = event.to ?? today;
    await _reload(emit);
  }

  void _onOnlyBlockedChanged(
    BrowsingHistoryOnlyBlockedChanged event,
    Emitter<BrowsingHistoryState> emit,
  ) {
    emit(state.copyWith(onlyBlocked: event.onlyBlocked));
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
    emit(state.copyWith(list: const PagedListLoading<BrowsingEntry>()));
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
    return (String? before) {
      return _listBrowsingHistory(deviceId, from: _from, to: _to, before: before);
    };
  }
}
