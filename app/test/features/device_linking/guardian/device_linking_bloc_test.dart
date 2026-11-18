import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:parentalynx/core/bloc/action_status.dart';
import 'package:parentalynx/features/device_linking/device_linking_module.dart';
import 'package:parentalynx/features/device_linking/domain/usecases/get_shown_link_code.dart';
import 'package:parentalynx/features/device_linking/presentation/bloc/device_linking/device_linking_bloc.dart';
import 'package:parentalynx/features/device_sync/domain/entities/realtime_update.dart';

import '../../../support/fake_backend.dart';
import '../../../support/fakes.dart';
import '../../../support/guardian_fixtures.dart';
import '../../../support/test_dependencies.dart';

const String _activePath = '/v1/guardian/pairing-codes/active';
const String _codesPath = '/v1/guardian/pairing-codes';

/// Vinculacao vista pelo responsavel: o BLoC com os casos de uso reais e o servidor falso.
void main() {
  late FakeBackend backend;
  late FakeElevationPrompter prompter;
  late TestDependencies deps;
  late int expiresAt;

  void activeIs({String? codeId, List<Object?> pending = const <Object?>[]}) {
    backend.onJson('GET', _activePath, <String, Object?>{
      'code': codeId == null ? null : <String, Object?>{'id': codeId, 'expiresAt': expiresAt},
      'pending': pending,
    });
  }

  Map<String, Object?> newCode() {
    return <String, Object?>{'id': 'c1', 'code': 'AB2D9XYZ', 'expiresAt': expiresAt};
  }

  setUp(() {
    backend = FakeBackend();
    prompter = FakeElevationPrompter();
    deps = TestDependencies(backend: backend, sessionToken: 'gs_x', elevationPrompter: prompter);
    addTearDown(deps.dispose);
    registerDeviceLinkingModule(deps.di);
    expiresAt = deps.clock.now().add(const Duration(minutes: 15)).millisecondsSinceEpoch;
    backend.onJson('POST', _codesPath, newCode(), status: 201);
    backend.onJson('GET', '/v1/guardian/devices', <String, Object?>{'devices': <Object?>[]});
  });

  DeviceLinkingBloc build() {
    final DeviceLinkingBloc bloc = deps.di<DeviceLinkingBloc>();
    addTearDown(bloc.close);
    return bloc;
  }

  Future<void> run(DeviceLinkingBloc bloc, DeviceLinkingEvent event) async {
    bloc.add(event);
    await pumpEventQueue();
  }

  test('gera o codigo e o mantem enquanto o servidor o considera ativo', () async {
    activeIs(codeId: 'c1');
    final DeviceLinkingBloc bloc = build();

    await run(bloc, const LinkCodeRequested());
    await run(bloc, const LinkRequestsCheckRequested());

    expect(bloc.state.code?.code, 'AB2D9XYZ');
    expect(bloc.state.loaded, isTrue);
    expect(bloc.state.requests, isEmpty);
    expect(bloc.state.remaining, const Duration(minutes: 15));
  });

  test('o codigo continua na tela quando a pessoa sai da pagina e volta', () async {
    final DeviceLinkingBloc first = build();
    await run(first, const LinkCodeRequested());
    await first.close();

    expect(build().state.code?.id, 'c1');
  });

  test('codigo usado sai da tela e o pedido pendente aparece', () async {
    final DeviceLinkingBloc bloc = build();
    await run(bloc, const LinkCodeRequested());
    activeIs(
      pending: <Object?>[deviceJson(id: 'p1', status: 'pending', confirmCode: '4821')],
    );

    await run(bloc, const LinkRequestsCheckRequested());

    expect(bloc.state.code, isNull);
    expect(bloc.state.requests.single.confirmCode, '4821');
    expect(deps.di<GetShownLinkCode>()(), isNull);
    // Os pedidos mudaram: a lista de aparelhos e recarregada para o painel.
    expect(backend.calls('GET', '/v1/guardian/devices'), hasLength(1));
  });

  test('codigo ativo gerado em outra sessao e sinalizado, sem texto', () async {
    activeIs(codeId: 'outro');
    final DeviceLinkingBloc bloc = build();

    await run(bloc, const LinkRequestsCheckRequested());

    expect(bloc.state.code, isNull);
    expect(bloc.state.otherCodeExpiresAt, expiresAt);
    expect(bloc.state.otherCodeStillValidUntil, expiresAt);
  });

  test('consulta iniciada antes de gerar nao apaga o codigo novo', () async {
    final Completer<http.Response> slow = Completer<http.Response>();
    backend.on('GET', _activePath, (_) => slow.future);
    final DeviceLinkingBloc bloc = build();

    await run(bloc, const LinkRequestsCheckRequested());
    await run(bloc, const LinkCodeRequested());
    slow.complete(jsonResponse(<String, Object?>{'code': null, 'pending': <Object?>[]}));
    await pumpEventQueue();

    expect(bloc.state.code?.id, 'c1');
    expect(bloc.state.loaded, isTrue);
  });

  test('aprovar envia o nome da crianca e guarda o aparelho aprovado', () async {
    activeIs(
      pending: <Object?>[deviceJson(id: 'p1', status: 'pending', confirmCode: '4821')],
    );
    backend.onJson('POST', '/v1/guardian/devices/p1/approve', <String, Object?>{
      'device': deviceJson(id: 'p1', childName: 'Ana'),
    });
    final DeviceLinkingBloc bloc = build();
    await run(bloc, const LinkRequestsCheckRequested());

    await run(bloc, const LinkApprovalSubmitted(requestId: 'p1', childName: ' Ana '));

    expect(backend.lastBody('POST', '/v1/guardian/devices/p1/approve')['childName'], 'Ana');
    expect(bloc.state.requests, isEmpty);
    expect(bloc.state.approved?.childName, 'Ana');
    expect(bloc.state.action, const ActionSucceeded());
    await run(bloc, const ApprovedLinkDismissed());
    expect(bloc.state.approved, isNull);
  });

  test('aparelho ja conhecido volta com o identificador do cadastro antigo', () async {
    activeIs(
      pending: <Object?>[
        deviceJson(id: 'p1', status: 'pending', confirmCode: '4821', relink: true),
      ],
    );
    backend.onJson('POST', '/v1/guardian/devices/p1/approve', <String, Object?>{
      'device': deviceJson(id: 'd-antigo', childName: 'João'),
    });
    final DeviceLinkingBloc bloc = build();
    await run(bloc, const LinkRequestsCheckRequested());
    expect(bloc.state.requests.single.relink, isTrue);

    await run(bloc, const LinkApprovalSubmitted(requestId: 'p1', childName: 'João'));

    expect(bloc.state.approved?.id, 'd-antigo');
    expect(bloc.state.approved?.displayName, 'João');
  });

  test('elevacao exigida pede a senha e repete a geracao', () async {
    int calls = 0;
    backend.on('POST', _codesPath, (_) {
      calls++;
      return calls == 1
          ? errorResponse(403, 'elevation_required')
          : jsonResponse(newCode(), status: 201);
    });
    final DeviceLinkingBloc bloc = build();

    await run(bloc, const LinkCodeRequested());

    expect(prompter.requests, 1);
    expect(calls, 2);
    expect(bloc.state.code?.id, 'c1');
  });

  test('pedido de senha recusado volta ao repouso, sem aviso de falha', () async {
    prompter.accept = false;
    backend.onError('POST', _codesPath, status: 403, code: 'elevation_required');
    final DeviceLinkingBloc bloc = build();

    await run(bloc, const LinkCodeRequested());

    expect(bloc.state.code, isNull);
    expect(bloc.state.action, const ActionIdle());
  });

  test('rejeitar tira o pedido da tela e avisa', () async {
    activeIs(
      pending: <Object?>[deviceJson(id: 'p1', status: 'pending', confirmCode: '4821')],
    );
    backend.on('POST', '/v1/guardian/devices/p1/reject', (_) => http.Response('', 204));
    final DeviceLinkingBloc bloc = build();
    await run(bloc, const LinkRequestsCheckRequested());

    await run(bloc, const LinkRejectionSubmitted('p1'));

    expect(backend.calls('POST', '/v1/guardian/devices/p1/reject'), hasLength(1));
    expect(bloc.state.requests, isEmpty);
    expect(bloc.state.action, const ActionSucceeded(message: 'Pedido rejeitado.'));
  });

  test('cancelar o codigo avisa o servidor e tira o codigo da tela', () async {
    backend.on('DELETE', '$_codesPath/c1', (_) => http.Response('', 204));
    final DeviceLinkingBloc bloc = build();
    await run(bloc, const LinkCodeRequested());

    await run(bloc, const LinkCodeCancelRequested());

    expect(backend.calls('DELETE', '$_codesPath/c1'), hasLength(1));
    expect(bloc.state.code, isNull);
    expect(deps.di<GetShownLinkCode>()(), isNull);
  });

  test('o codigo vencido sai da tela na contagem regressiva', () async {
    final DeviceLinkingBloc bloc = build();
    await run(bloc, const LinkCodeRequested());

    deps.clock.advance(const Duration(minutes: 14, seconds: 30));
    await run(bloc, const LinkCodeTicked());
    expect(bloc.state.remaining, const Duration(seconds: 30));
    expect(bloc.state.codeExpired, isFalse);

    deps.clock.advance(const Duration(seconds: 30));
    await run(bloc, const LinkCodeTicked());
    expect(bloc.state.code, isNull);
    expect(deps.di<GetShownLinkCode>()(), isNull);
    // A tela explica que o codigo venceu; gerar outro limpa o aviso.
    expect(bloc.state.codeExpired, isTrue);
    await run(bloc, const LinkCodeRequested());
    expect(bloc.state.codeExpired, isFalse);
  });

  test('aviso em tempo real de pedido novo dispara a consulta', () async {
    activeIs();
    final DeviceLinkingBloc bloc = build();
    await run(bloc, const DeviceLinkingStarted());
    expect(backend.calls('GET', _activePath), hasLength(1));

    activeIs(
      pending: <Object?>[deviceJson(id: 'p1', status: 'pending', confirmCode: '4821')],
    );
    deps.realtime.emit(const LinkRequested('p1'));
    await pumpEventQueue();

    expect(backend.calls('GET', _activePath), hasLength(2));
    expect(bloc.state.requests.single.id, 'p1');
  });

  test('sem conexao mostra o aviso ate a proxima consulta dar certo', () async {
    backend.on('GET', _activePath, (_) => throw http.ClientException('sem rede'));
    final DeviceLinkingBloc bloc = build();

    await run(bloc, const LinkRequestsCheckRequested());
    expect(bloc.state.offline, isTrue);

    activeIs();
    await run(bloc, const LinkRequestsCheckRequested());
    expect(bloc.state.offline, isFalse);
  });
}
