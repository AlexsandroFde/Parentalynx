import 'package:get_it/get_it.dart';

import '../../core/network/api_client.dart';
import '../../core/time/clock.dart';
import 'data/datasources/remote/reports_remote_data_source.dart';
import 'data/repositories/api_reports_repository.dart';
import 'domain/repositories/i_reports_repository.dart';
import 'domain/usecases/get_day_timeline.dart';
import 'domain/usecases/get_report_summary.dart';
import 'domain/usecases/list_browsing_history.dart';
import 'domain/usecases/list_device_events.dart';
import 'presentation/bloc/activity_reports/activity_reports_bloc.dart';
import 'presentation/bloc/browsing_history/browsing_history_bloc.dart';
import 'presentation/bloc/day_timeline/day_timeline_bloc.dart';
import 'presentation/bloc/device_events/device_events_bloc.dart';

/// Registra as dependencias dos relatorios de uso.
void registerActivityReportsModule(GetIt di) {
  di
    ..registerLazySingleton<ReportsRemoteDataSource>(() => ReportsRemoteDataSource(di<ApiClient>()))
    ..registerLazySingleton<IReportsRepository>(
      () => ApiReportsRepository(di<ReportsRemoteDataSource>()),
    )
    ..registerFactory<GetReportSummary>(() => GetReportSummary(di<IReportsRepository>()))
    ..registerFactory<GetDayTimeline>(() => GetDayTimeline(di<IReportsRepository>()))
    ..registerFactory<ListDeviceEvents>(() => ListDeviceEvents(di<IReportsRepository>()))
    ..registerFactory<ListBrowsingHistory>(() => ListBrowsingHistory(di<IReportsRepository>()))
    // Uma instancia por tela aberta.
    ..registerFactory<ActivityReportsBloc>(
      () => ActivityReportsBloc(getReportSummary: di<GetReportSummary>(), clock: di<Clock>()),
    )
    ..registerFactory<DayTimelineBloc>(
      () => DayTimelineBloc(getDayTimeline: di<GetDayTimeline>(), clock: di<Clock>()),
    )
    ..registerFactory<DeviceEventsBloc>(
      () => DeviceEventsBloc(listDeviceEvents: di<ListDeviceEvents>(), clock: di<Clock>()),
    )
    ..registerFactory<BrowsingHistoryBloc>(
      () => BrowsingHistoryBloc(listBrowsingHistory: di<ListBrowsingHistory>(), clock: di<Clock>()),
    );
}
