import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/bloc/form_status.dart';
import 'package:parentalynx/core/platform/native_api.g.dart' show TimeRequestInfo;
import 'package:parentalynx/features/screen_time/domain/entities/child_time_request.dart';
import 'package:parentalynx/features/screen_time/domain/usecases/get_own_time_requests.dart';
import 'package:parentalynx/features/screen_time/presentation/bloc/time_request_sheet/time_request_sheet_bloc.dart';
import 'package:parentalynx/features/screen_time/presentation/texts/child_time_request_texts.dart';

import '../../../support/test_dependencies.dart';
import '../../child_mode/support/child_fakes.dart';

void main() {
  group('textos dos pedidos de tempo', () {
    ChildTimeRequest request(ChildTimeRequestStatus status, {bool delivered = true, int? granted}) {
      return ChildTimeRequest(
        id: 'r',
        createdAtMs: 0,
        status: status,
        delivered: delivered,
        minutes: 30,
        grantedMinutes: granted,
      );
    }

    test('cada situacao tem o seu texto', () {
      expect(
        childTimeRequestStatusText(request(ChildTimeRequestStatus.pending)),
        'Esperando a resposta',
      );
      expect(
        childTimeRequestStatusText(request(ChildTimeRequestStatus.pending, delivered: false)),
        'Esperando conexão para enviar',
      );
      expect(
        childTimeRequestStatusText(request(ChildTimeRequestStatus.approved, granted: 45)),
        'Aprovado: mais 45min',
      );
      expect(
        childTimeRequestStatusText(request(ChildTimeRequestStatus.denied)),
        'Não aprovado desta vez',
      );
      expect(childTimeRequestAmount(request(ChildTimeRequestStatus.pending)), 'Mais 30min');
    });
  });

  group('pedido de mais tempo pela crianca', () {
    late TestDependencies deps;
    late ChildBridge bridge;

    setUp(() {
      (:deps, :bridge) = childDependencies();
      addTearDown(deps.dispose);
    });

    blocTest<TimeRequestSheetBloc, TimeRequestSheetState>(
      'registra o pedido no agente com o tempo escolhido e sem recado vazio',
      setUp: () {
        when(() => bridge.agent.submitTimeRequest(any(), any())).thenAnswer((_) async => 'req-1');
      },
      build: () => deps.di<TimeRequestSheetBloc>(),
      act: (TimeRequestSheetBloc bloc) => bloc
        ..add(const TimeRequestSheetOpened())
        ..add(const TimeRequestMinutesSelected(60))
        ..add(const TimeRequestSheetSubmitted(message: '   ')),
      verify: (TimeRequestSheetBloc bloc) {
        expect(bloc.state.status, FormStatus.succeeded);
        verify(() => bridge.agent.submitTimeRequest(60, null)).called(1);
      },
    );

    blocTest<TimeRequestSheetBloc, TimeRequestSheetState>(
      'falha da ponte vira mensagem e o pedido pode ser enviado de novo',
      setUp: () {
        when(() => bridge.agent.submitTimeRequest(any(), any()))
            .thenThrow(PlatformException(code: 'IllegalStateException', details: 'Cause: x'));
      },
      build: () => deps.di<TimeRequestSheetBloc>(),
      act: (TimeRequestSheetBloc bloc) => bloc.add(const TimeRequestSheetSubmitted(message: 'oi')),
      verify: (TimeRequestSheetBloc bloc) {
        expect(bloc.state.status, FormStatus.editing);
        expect(bloc.state.error, 'Não foi possível registrar o pedido. Tente de novo.');
      },
    );

    test('pedidos deste aparelho chegam do mais recente para o mais antigo', () async {
      bridge.requests = <TimeRequestInfo>[
        TimeRequestInfo(id: 'a', createdAtMs: 1, status: 'denied', delivered: true),
        TimeRequestInfo(id: 'b', createdAtMs: 3, minutes: 15, status: 'approved', delivered: true),
        TimeRequestInfo(id: 'c', createdAtMs: 2, status: 'weird', delivered: false),
      ];

      final List<ChildTimeRequest> requests = (await deps.di<GetOwnTimeRequests>()()).valueOrNull!;

      expect(requests.map((ChildTimeRequest r) => r.id), <String>['b', 'c', 'a']);
      expect(requests[1].status, ChildTimeRequestStatus.pending);
    });
  });
}
