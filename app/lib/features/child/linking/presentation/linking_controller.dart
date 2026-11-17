import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/security/pairing_code.dart';
import '../../../../core/time/formatters.dart';
import '../../agent/data/child_agent_repository.dart';
import '../../agent/data/child_device_repository.dart';
import '../../agent/domain/child_models.dart';
import '../../agent/presentation/child_session.dart';
import '../data/pairing_repository.dart';
import '../domain/pairing.dart';

/// Estado do fluxo de vinculacao.
sealed class LinkingState {
  const LinkingState();
}

/// Formulario do codigo. [restoring] vale enquanto se verifica se ha um pedido em andamento.
final class LinkingForm extends LinkingState {
  const LinkingForm({this.submitting = false, this.restoring = false, this.error});

  final bool submitting;
  final bool restoring;
  final String? error;
}

/// Pedido enviado, aguardando o responsavel aprovar.
final class LinkingWaiting extends LinkingState {
  const LinkingWaiting({required this.claim, this.connectionTrouble = false});

  final PairingClaim claim;

  /// A ultima consulta ao servidor falhou. A espera continua.
  final bool connectionTrouble;
}

/// Aprovado: gravando as credenciais e ligando o controle.
final class LinkingActivating extends LinkingState {
  const LinkingActivating({required this.claim});

  final PairingClaim claim;
}

/// Intervalo entre as consultas do andamento do pedido.
final Provider<Duration> pairingPollIntervalProvider = Provider<Duration>(
  (Ref ref) => const Duration(seconds: 3),
);

final linkingControllerProvider = NotifierProvider.autoDispose<LinkingController, LinkingState>(
  LinkingController.new,
);

class LinkingController extends Notifier<LinkingState> {
  Timer? _timer;
  bool _polling = false;

  @override
  LinkingState build() {
    ref.onDispose(_stopPolling);
    Future<void>.microtask(_restore);
    return const LinkingForm(restoring: true);
  }

  /// Retoma a espera de um pedido feito antes de o app ser fechado.
  Future<void> _restore() async {
    PairingClaim? claim;
    try {
      claim = await ref.read(pendingClaimStoreProvider).read();
    } on Object {
      claim = null;
    }
    if (!ref.mounted) {
      return;
    }
    final LinkingState current = state;
    if (current is! LinkingForm || !current.restoring) {
      return;
    }
    if (claim == null) {
      state = const LinkingForm();
      return;
    }
    state = LinkingWaiting(claim: claim);
    _startPolling();
    await pollNow();
  }

  /// Envia o codigo informado pelo responsavel.
  Future<void> submit({required String code, required String deviceName}) async {
    final LinkingState current = state;
    if (current is! LinkingForm || current.submitting) {
      return;
    }
    if (!PairingCode.isComplete(code)) {
      state = const LinkingForm(error: 'Digite o código completo. Ele tem 8 letras e números.');
      return;
    }
    if (deviceName.trim().isEmpty) {
      state = const LinkingForm(error: 'Escolha um nome para este aparelho.');
      return;
    }
    final ChildDeviceRepository device = ref.read(childDeviceRepositoryProvider);
    final PairingRepository pairing = ref.read(pairingRepositoryProvider);
    final PendingClaimStore store = ref.read(pendingClaimStoreProvider);
    state = const LinkingForm(submitting: true);
    try {
      final DeviceIdentity info = await device.deviceInfo();
      final PairingClaim claim = await pairing.claim(
        code: code,
        device: info.withName(deviceName.trim()),
      );
      await store.write(claim);
      if (!ref.mounted) {
        return;
      }
      state = LinkingWaiting(claim: claim);
      _startPolling();
    } on Object catch (error) {
      if (ref.mounted) {
        state = LinkingForm(error: linkingErrorMessage(toFailure(error)));
      }
    }
  }

  /// Consulta o andamento agora. O temporizador chama este metodo a cada intervalo.
  Future<void> pollNow() async {
    final LinkingState current = state;
    if (current is! LinkingWaiting || _polling) {
      return;
    }
    _polling = true;
    final PairingRepository pairing = ref.read(pairingRepositoryProvider);
    try {
      final PairingStatus status = await pairing.status(current.claim.pollToken);
      if (!ref.mounted || !_isStillWaitingFor(current.claim)) {
        return;
      }
      switch (status) {
        case PairingPending():
          if (current.connectionTrouble) {
            state = LinkingWaiting(claim: current.claim);
          }
        case PairingRejected():
          await _backToForm(
            'O responsável não aprovou este aparelho. Se foi engano, peça um novo código.',
          );
        case PairingExpired():
          await _backToForm(
            'O pedido venceu antes de ser aprovado. Peça um novo código ao responsável.',
          );
        case PairingApproved():
          await _activate(current.claim, status);
      }
    } on AppFailure {
      // Falha de rede ou do servidor: a espera continua e a tela avisa.
      if (ref.mounted && _isStillWaitingFor(current.claim)) {
        state = LinkingWaiting(claim: current.claim, connectionTrouble: true);
      }
    } finally {
      _polling = false;
    }
  }

  /// Desiste do pedido em andamento e volta ao formulario.
  Future<void> cancelWaiting() async {
    _stopPolling();
    final PendingClaimStore store = ref.read(pendingClaimStoreProvider);
    state = const LinkingForm();
    await store.clear();
  }

  /// Apaga a mensagem de erro quando a pessoa volta a digitar.
  void clearError() {
    final LinkingState current = state;
    if (current is LinkingForm && current.error != null && !current.submitting) {
      state = const LinkingForm();
    }
  }

  bool _isStillWaitingFor(PairingClaim claim) {
    final LinkingState now = state;
    return now is LinkingWaiting && now.claim.linkId == claim.linkId;
  }

  Future<void> _backToForm(String message) async {
    _stopPolling();
    final PendingClaimStore store = ref.read(pendingClaimStoreProvider);
    state = LinkingForm(error: message);
    await store.clear();
  }

  Future<void> _activate(PairingClaim claim, PairingApproved approved) async {
    _stopPolling();
    final ChildAgentRepository agent = ref.read(childAgentRepositoryProvider);
    final PendingClaimStore store = ref.read(pendingClaimStoreProvider);
    final ChildLinkController link = ref.read(childLinkProvider.notifier);
    final String serverUrl = ref.read(serverUrlProvider);
    state = LinkingActivating(claim: claim);
    try {
      await agent.activate(
        LinkCredentials(
          serverUrl: serverUrl,
          deviceId: approved.deviceId,
          deviceToken: approved.deviceToken,
          offlineSecret: approved.offlineSecret,
          childName: approved.childName,
          guardianName: approved.guardianName.isNotEmpty
              ? approved.guardianName
              : claim.guardianName,
        ),
        approved.policyVersion,
        approved.policyJson,
      );
      await store.clear();
      // A mudanca de fase faz o roteador sair desta tela e seguir para a configuracao.
      link.markLinked();
    } on AppFailure catch (failure) {
      await store.clear();
      if (ref.mounted) {
        state = LinkingForm(
          error:
              'O responsável aprovou, mas não foi possível ligar o controle neste aparelho. '
              '${failure.message} Peça um novo código e tente de novo.',
        );
      }
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(
      ref.read(pairingPollIntervalProvider),
      (Timer timer) => unawaited(pollNow()),
    );
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Texto para mostrar quando o pedido de vinculo falha.
String linkingErrorMessage(AppFailure failure) {
  if (failure is! ApiFailure) {
    return failure.message;
  }
  switch (failure.code) {
    case 'code_expired':
      return 'Este código venceu ou já foi usado. Peça um novo código ao responsável.';
    case 'invalid_credentials':
    case 'not_found':
    case 'validation_error':
      return 'Código incorreto. Confira com o responsável e tente de novo.';
    case 'rate_limited':
    case 'account_locked':
      final int? retry = failure.retryAfterSec;
      if (retry == null || retry <= 0) {
        return 'Muitas tentativas. Espere alguns minutos e tente de novo.';
      }
      return 'Muitas tentativas. Tente de novo em ${formatMinutes((retry / 60).ceil())}.';
    default:
      return failure.message;
  }
}
