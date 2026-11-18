import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/browsing_entry.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/cursor_page.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/day_timeline.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/device_event.dart';
import 'package:parentalynx/features/activity_reports/domain/entities/event_group.dart';
import 'package:parentalynx/features/activity_reports/domain/usecases/get_day_timeline.dart';
import 'package:parentalynx/features/activity_reports/domain/usecases/list_device_events.dart';
import 'package:parentalynx/features/activity_reports/presentation/bloc/browsing_history/browsing_history_bloc.dart';
import 'package:parentalynx/features/activity_reports/presentation/bloc/day_timeline/day_timeline_bloc.dart';
import 'package:parentalynx/features/activity_reports/presentation/bloc/device_events/device_events_bloc.dart';
import 'package:parentalynx/features/activity_reports/presentation/bloc/paging/paged_list.dart';

import '../../../support/fakes.dart';

class _MockGetDayTimeline extends Mock implements GetDayTimeline {}

class _MockListDeviceEvents extends Mock implements ListDeviceEvents {}

void main() {
  setUpAll(() => registerFallbackValue(EventGroup.all));

  test('linha do tempo: o dia escolhido nunca passa de hoje', () async {
    final _MockGetDayTimeline get = _MockGetDayTimeline();
    when(() => get(any(), day: any(named: 'day')))
        .thenAnswer((_) async => Ok<DayTimeline>(DayTimeline.fromSessions(const [])));
    final DayTimelineBloc bloc = DayTimelineBloc(getDayTimeline: get, clock: FakeClock())
      ..add(const DayTimelineStarted(deviceId: 'd', deviceToday: '2026-11-17'))
      ..add(const DayTimelineDaySelected('2026-11-30'));
    await bloc.stream.firstWhere(
      (DayTimelineState s) => s is DayTimelineEmpty && s.day == '2026-11-17',
    );
    expect(bloc.state.canGoForward, isFalse);
    await bloc.close();
  });

  test('linha do tempo: atualizar com falha mantém o dia na tela e devolve a falha', () async {
    final _MockGetDayTimeline get = _MockGetDayTimeline();
    when(() => get(any(), day: any(named: 'day')))
        .thenAnswer((_) async => Ok<DayTimeline>(DayTimeline.fromSessions(const [])));
    final DayTimelineBloc bloc = DayTimelineBloc(getDayTimeline: get, clock: FakeClock())
      ..add(const DayTimelineStarted(deviceId: 'd', deviceToday: '2026-11-17'));
    await bloc.stream.firstWhere((DayTimelineState s) => s is DayTimelineEmpty);
    when(() => get(any(), day: any(named: 'day')))
        .thenAnswer((_) async => const Err<DayTimeline>(NetworkFailure()));
    final Completer<AppFailure?> done = Completer<AppFailure?>();
    bloc.add(DayTimelineRefreshRequested(completer: done));
    expect(await done.future, isA<NetworkFailure>());
    expect(bloc.state, isA<DayTimelineEmpty>());
    await bloc.close();
  });

  test('eventos: o grupo pedido na abertura e o periodo escolhido vao para a consulta', () async {
    final _MockListDeviceEvents list = _MockListDeviceEvents();
    when(
      () => list(
        any(),
        from: any(named: 'from'),
        to: any(named: 'to'),
        group: any(named: 'group'),
        before: any(named: 'before'),
      ),
    ).thenAnswer(
      (_) async => const Ok<CursorPage<DeviceEvent>>(CursorPage<DeviceEvent>(items: [])),
    );
    final DeviceEventsBloc bloc = DeviceEventsBloc(listDeviceEvents: list, clock: FakeClock())
      ..add(
        const DeviceEventsStarted(
          deviceId: 'd',
          deviceToday: '2026-11-17',
          group: EventGroup.blocks,
        ),
      );
    await bloc.stream.firstWhere((DeviceEventsState s) => s.list is PagedListEmpty<DeviceEvent>);
    expect(bloc.state.group, EventGroup.blocks);
    expect(bloc.state.from, '2026-11-11');

    bloc.add(const DeviceEventsPeriodChanged(from: '2026-11-20', to: '2026-11-01'));
    await bloc.stream.firstWhere(
      (DeviceEventsState s) => s.from == '2026-11-01' && s.list is PagedListEmpty<DeviceEvent>,
    );
    // Datas invertidas e alem de hoje sao corrigidas: de 01/11 ate hoje.
    expect(bloc.state.to, '2026-11-17');
    await bloc.close();
  });

  test('navegacao: a busca acha por titulo, site ou endereco', () {
    const BrowsingEntry entry = BrowsingEntry(
      id: '1',
      ts: 0,
      url: 'https://pt.wikipedia.org/wiki/Lince',
      domain: 'pt.wikipedia.org',
      title: 'Lince',
      blocked: false,
    );
    expect(const BrowsingHistoryState(query: 'WIKI').shows(entry), isTrue);
    expect(const BrowsingHistoryState(query: 'lince').shows(entry), isTrue);
    expect(const BrowsingHistoryState(query: 'jogos').shows(entry), isFalse);
    expect(const BrowsingHistoryState(onlyBlocked: true).shows(entry), isFalse);
  });
}
