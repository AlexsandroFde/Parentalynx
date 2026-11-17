import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/data/devices_repository.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/devices_providers.dart';
import '../data/api_pairing_repository.dart';
import '../domain/pairing.dart';

/// Estado da tela de vinculacao.
class PairingState {
  const PairingState({
    this.code,
    this.otherCodeExpiresAt,
    this.pending = const <Device>[],
    this.approved,
    this.loaded = false,
  });

  /// Codigo gerado nesta abertura do app e ainda valido no servidor, com o texto para mostrar.
  final PairingCodeInfo? code;

  /// Ha um codigo ativo no servidor que nao foi gerado nesta abertura do app. O texto dele
  /// nao pode ser recuperado (o servidor guarda so o hash): resta gerar outro.
  final int? otherCodeExpiresAt;

  /// Pedidos de vinculo aguardando aprovacao.
  final List<Device> pending;

  /// Aparelho que acabou de ser aprovado, para a tela de sucesso.
  final Device? approved;

  /// Verdadeiro depois da primeira consulta ao servidor.
  final bool loaded;

  PairingState copyWith({
    PairingCodeInfo? Function()? code,
    int? Function()? otherCodeExpiresAt,
    List<Device>? pending,
    Device? Function()? approved,
    bool? loaded,
  }) {
    return PairingState(
      code: code == null ? this.code : code(),
      otherCodeExpiresAt: otherCodeExpiresAt == null
          ? this.otherCodeExpiresAt
          : otherCodeExpiresAt(),
      pending: pending ?? this.pending,
      approved: approved == null ? this.approved : approved(),
      loaded: loaded ?? this.loaded,
    );
  }
}

/// Geracao do codigo, acompanhamento dos pedidos e aprovacao.
///
/// O estado fica vivo enquanto o app estiver aberto, para o codigo continuar na tela se a
/// pessoa sair da pagina e voltar.
final NotifierProvider<PairingController, PairingState> pairingProvider =
    NotifierProvider<PairingController, PairingState>(PairingController.new);

class PairingController extends Notifier<PairingState> {
  /// Muda a cada codigo gerado ou cancelado. Uma consulta que comecou antes da mudanca nao
  /// pode decidir sobre o codigo novo.
  int _codeEpoch = 0;

  PairingRepository get _repository => ref.read(pairingRepositoryProvider);

  @override
  PairingState build() => const PairingState();

  /// (E) Gera um codigo novo. O anterior deixa de valer.
  Future<void> generate() async {
    final PairingCodeInfo code = await _repository.createCode();
    if (!ref.mounted) {
      return;
    }
    _codeEpoch += 1;
    state = state.copyWith(code: () => code, otherCodeExpiresAt: () => null, approved: () => null);
  }

  /// Cancela o codigo mostrado.
  Future<void> cancel() async {
    final PairingCodeInfo? code = state.code;
    if (code == null) {
      return;
    }
    await _repository.cancelCode(code.id);
    if (ref.mounted) {
      _codeEpoch += 1;
      state = state.copyWith(code: () => null);
    }
  }

  /// Consulta o servidor: pedidos pendentes e situacao do codigo.
  Future<void> poll() async {
    final int epoch = _codeEpoch;
    final ActivePairing active = await _repository.active();
    if (!ref.mounted) {
      return;
    }
    final bool pendingChanged = !_sameIds(state.pending, active.pending);
    if (epoch != _codeEpoch) {
      // Um codigo foi gerado ou cancelado durante a consulta: so os pedidos sao confiaveis.
      state = state.copyWith(pending: active.pending, loaded: true);
    } else {
      final PairingCodeInfo? shown = state.code;
      final ActiveCodeRef? serverCode = active.code;
      final bool shownStillActive =
          shown != null && serverCode != null && serverCode.id == shown.id;
      state = state.copyWith(
        // Se o codigo mostrado deixou de valer (foi usado, cancelado ou venceu), sai da tela.
        code: () => shownStillActive ? shown : null,
        otherCodeExpiresAt: () =>
            serverCode != null && !shownStillActive ? serverCode.expiresAt : null,
        pending: active.pending,
        loaded: true,
      );
    }
    if (pendingChanged) {
      await ref.read(devicesProvider.notifier).refresh();
    }
  }

  /// (E) Aprova o pedido de vinculo dando nome a crianca.
  Future<Device> approve(String deviceId, {required String childName}) async {
    final Device device = await ref
        .read(devicesRepositoryProvider)
        .approve(deviceId, childName: childName);
    if (ref.mounted) {
      state = state.copyWith(
        pending: state.pending.where((Device item) => item.id != deviceId).toList(),
        approved: () => device,
      );
      await ref.read(devicesProvider.notifier).refresh();
    }
    return device;
  }

  /// Rejeita o pedido de vinculo.
  Future<void> reject(String deviceId) async {
    await ref.read(devicesRepositoryProvider).reject(deviceId);
    if (ref.mounted) {
      state = state.copyWith(
        pending: state.pending.where((Device item) => item.id != deviceId).toList(),
      );
      await ref.read(devicesProvider.notifier).refresh();
    }
  }

  /// Sai da tela de sucesso para vincular outro aparelho.
  void dismissApproved() {
    state = state.copyWith(approved: () => null);
  }

  /// O codigo mostrado venceu sem ser usado.
  void expireShownCode() {
    if (state.code != null) {
      _codeEpoch += 1;
      state = state.copyWith(code: () => null);
    }
  }

  static bool _sameIds(List<Device> a, List<Device> b) {
    if (a.length != b.length) {
      return false;
    }
    final Set<String> ids = a.map((Device device) => device.id).toSet();
    return b.every((Device device) => ids.contains(device.id));
  }
}
