import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/security/pairing_code.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../auth/presentation/elevation.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/devices_providers.dart';
import '../../guardian_paths.dart';
import '../../realtime/guardian_realtime.dart';
import '../../shell/data/local_prefs.dart';
import '../../shell/data/share_service.dart';
import '../domain/pairing.dart';
import 'pairing_controller.dart';

/// Vinculacao de um aparelho da crianca: gera o codigo, acompanha o pedido e confirma.
class PairingPage extends ConsumerStatefulWidget {
  const PairingPage({super.key});

  @override
  ConsumerState<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends ConsumerState<PairingPage> {
  /// Validade padrao do codigo, usada so para desenhar a barra de tempo.
  static const Duration _codeLifetime = Duration(minutes: 15);

  Timer? _ticker;
  Timer? _poller;
  bool _generating = false;
  bool _cancelling = false;
  bool _offline = false;
  String? _actingOn;

  @override
  void initState() {
    super.initState();
    // O relogio redesenha a contagem regressiva. A consulta periodica e a reserva para o
    // caso de o aviso em tempo real nao chegar.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    WidgetsBinding.instance.addPostFrameCallback((_) => _poll());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    super.dispose();
  }

  int get _now => ref.read(guardianClockProvider)().millisecondsSinceEpoch;

  void _onTick() {
    if (!mounted) {
      return;
    }
    final PairingCodeInfo? code = ref.read(pairingProvider).code;
    if (code == null) {
      return;
    }
    if (code.expiresAt <= _now) {
      ref.read(pairingProvider.notifier).expireShownCode();
    } else {
      setState(() {});
    }
  }

  Future<void> _poll() async {
    if (!mounted) {
      return;
    }
    try {
      await ref.read(pairingProvider.notifier).poll();
      if (mounted && _offline) {
        setState(() => _offline = false);
      }
    } on AppFailure catch (failure) {
      if (mounted && failure is NetworkFailure && !_offline) {
        setState(() => _offline = true);
      }
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    await guardedAction<void>(context, ref, () => ref.read(pairingProvider.notifier).generate());
    if (mounted) {
      setState(() => _generating = false);
    }
  }

  Future<void> _cancelCode() async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Cancelar o código?',
      message: 'O código deixa de valer. Para vincular um aparelho será preciso gerar outro.',
      confirmLabel: 'Cancelar código',
      cancelLabel: 'Manter',
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _cancelling = true);
    try {
      await ref.read(pairingProvider.notifier).cancel();
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
      }
    }
  }

  Future<void> _copy(PairingCodeInfo code) async {
    await ref.read(shareServiceProvider).copy(PairingCode.format(code.code));
    if (mounted) {
      showAppSnackBar(context, 'Código copiado.', tone: Tone.success);
    }
  }

  Future<void> _share(PairingCodeInfo code) async {
    try {
      await ref
          .read(shareServiceProvider)
          .shareText(
            'Código de vinculação do ParentaLynx: ${PairingCode.format(code.code)}\n'
            'Digite no aparelho da criança até as ${formatClockMs(code.expiresAt)}. '
            'O código só pode ser usado uma vez.',
            subject: 'Código de vinculação do ParentaLynx',
          );
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _approve(Device device) async {
    final String? childName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _ApproveDialog(device: device),
    );
    if (childName == null || !mounted) {
      return;
    }
    setState(() => _actingOn = device.id);
    final Device? approved = await guardedAction<Device>(
      context,
      ref,
      () => ref.read(pairingProvider.notifier).approve(device.id, childName: childName),
    );
    if (!mounted) {
      return;
    }
    setState(() => _actingOn = null);
    if (approved != null) {
      ref.read(selectedDeviceIdProvider.notifier).select(approved.id);
    }
  }

  Future<void> _reject(Device device) async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Rejeitar o pedido?',
      message:
          'O aparelho "${device.deviceName}" não será vinculado. Para tentar de novo será '
          'preciso gerar outro código.',
      confirmLabel: 'Rejeitar',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _actingOn = device.id);
    try {
      await ref.read(pairingProvider.notifier).reject(device.id);
      if (mounted) {
        showAppSnackBar(context, 'Pedido rejeitado.');
      }
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _actingOn = null);
      }
    }
  }

  void _finish() {
    ref.read(pairingProvider.notifier).dismissApproved();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(GuardianPaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Um aviso em tempo real de pedido novo ou resolvido dispara a consulta na hora.
    ref.listen<AsyncValue<GuardianRealtimeEvent>>(guardianRealtimeEventsProvider, (
      AsyncValue<GuardianRealtimeEvent>? previous,
      AsyncValue<GuardianRealtimeEvent> next,
    ) {
      final String? type = next.value?.type;
      if (type == 'link_pending' || type == 'link_resolved') {
        _poll();
      }
    });

    final PairingState state = ref.watch(pairingProvider);
    final Device? approved = state.approved;
    return Scaffold(
      appBar: AppBar(title: const Text('Vincular aparelho')),
      body: approved != null
          ? _SuccessView(
              device: approved,
              onDone: _finish,
              onAnother: () => ref.read(pairingProvider.notifier).dismissApproved(),
            )
          : PageBody(children: _content(state)),
    );
  }

  List<Widget> _content(PairingState state) {
    final PairingCodeInfo? code = state.code;
    final int? otherCodeExpiresAt = state.otherCodeExpiresAt;
    return <Widget>[
      if (_offline) ...<Widget>[
        const NoticeBanner(
          tone: Tone.warning,
          icon: Icons.cloud_off_outlined,
          message: 'Sem conexão com o servidor. Tentando de novo a cada poucos segundos.',
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      for (final Device device in state.pending) ...<Widget>[
        _PendingLinkCard(
          device: device,
          busy: _actingOn == device.id,
          enabled: _actingOn == null,
          onApprove: () => _approve(device),
          onReject: () => _reject(device),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (code != null)
        _CodeCard(
          code: code,
          remaining: Duration(milliseconds: code.expiresAt - _now),
          lifetime: _codeLifetime,
          cancelling: _cancelling,
          onCopy: () => _copy(code),
          onShare: () => _share(code),
          onCancel: _cancelCode,
        )
      else ...<Widget>[
        _GenerateCard(
          hasPending: state.pending.isNotEmpty,
          busy: _generating,
          onGenerate: _generate,
        ),
        if (otherCodeExpiresAt != null && otherCodeExpiresAt > _now) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          NoticeBanner(
            message:
                'Já existe um código válido até as ${formatClockMs(otherCodeExpiresAt)}, '
                'gerado antes. Por segurança o servidor não guarda o texto do código, então '
                'ele não pode ser mostrado de novo. Gerar um novo cancela o anterior.',
          ),
        ],
      ],
      const SizedBox(height: AppSpacing.lg),
      const _HowItWorks(),
    ];
  }
}

class _GenerateCard extends StatelessWidget {
  const _GenerateCard({required this.hasPending, required this.busy, required this.onGenerate});

  final bool hasPending;
  final bool busy;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.link, size: 28, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              hasPending ? 'Vincular outro aparelho' : 'Gerar código de vinculação',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'O código vale por 15 minutos e só pode ser usado uma vez. Depois de digitado '
              'no aparelho da criança, você ainda confirma o vínculo aqui.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            BusyButton(
              label: 'Gerar código',
              icon: Icons.qr_code_2,
              busy: busy,
              onPressed: onGenerate,
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.code,
    required this.remaining,
    required this.lifetime,
    required this.cancelling,
    required this.onCopy,
    required this.onShare,
    required this.onCancel,
  });

  final PairingCodeInfo code;
  final Duration remaining;
  final Duration lifetime;
  final bool cancelling;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String formatted = PairingCode.format(code.code);
    final bool ending = remaining.inSeconds <= 60;
    final Tone tone = ending ? Tone.warning : Tone.info;
    final double fraction = (remaining.inMilliseconds / lifetime.inMilliseconds).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Código de vinculação',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label: 'Código ${formatted.split('').join(' ')}',
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SelectableText(
                  formatted,
                  maxLines: 1,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                color: tone.foreground(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.timer_outlined, size: 18, color: tone.foreground(context)),
                const SizedBox(width: 6),
                Text(
                  'Expira em ${formatCountdown(remaining.inMilliseconds)}',
                  style: theme.textTheme.labelLarge?.copyWith(color: tone.foreground(context)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            CopyShareButtons(onCopy: onCopy, onShare: onShare),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Text(
                    'Aguardando o aparelho da criança',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: cancelling ? null : onCancel,
                child: const Text('Cancelar código'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingLinkCard extends StatelessWidget {
  const _PendingLinkCard({
    required this.device,
    required this.busy,
    required this.enabled,
    required this.onApprove,
    required this.onReject,
  });

  final Device device;
  final bool busy;
  final bool enabled;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String confirmCode = device.confirmCode ?? '';
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.phonelink_ring_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('Pedido de vínculo', style: theme.textTheme.titleMedium)),
                Text(
                  formatRelativeMs(device.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              device.deviceName.isEmpty ? 'Aparelho sem nome' : device.deviceName,
              style: theme.textTheme.titleLarge,
            ),
            if (device.hardwareLabel.isNotEmpty)
              Text(
                device.hardwareLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (device.relink) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              NoticeBanner(
                icon: Icons.history,
                message: device.childName.isEmpty
                    ? 'Este aparelho já foi vinculado a esta conta. Ao aprovar, as regras e o '
                          'histórico anteriores são mantidos.'
                    : 'Este aparelho já foi vinculado a esta conta como "${device.childName}". '
                          'Ao aprovar, as regras e o histórico anteriores são mantidos.',
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    'Número de confirmação',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    label: 'Número de confirmação ${confirmCode.split('').join(' ')}',
                    excludeSemantics: true,
                    child: Text(
                      confirmCode.split('').join(' '),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Confira se o mesmo número aparece na tela do aparelho da criança. Se for '
                    'diferente ou se você não reconhece o aparelho, rejeite.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: enabled ? onReject : null,
                    child: const Text('Rejeitar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: BusyButton(
                    label: 'Aprovar',
                    busy: busy,
                    onPressed: enabled ? onApprove : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pede o nome da crianca antes de aprovar o vinculo.
class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog({required this.device});

  final Device device;

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.device.childName);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe o nome da criança.');
      return;
    }
    if (name.length > 40) {
      setState(() => _error = 'Use no máximo 40 caracteres.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Aprovar vínculo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'De quem é este aparelho? O nome aparece no painel e nos relatórios.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Nome da criança',
              errorText: _error,
              prefixIcon: const Icon(Icons.child_care_outlined),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: _submit,
          child: const Text('Aprovar'),
        ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      title: 'Como vincular',
      child: Column(
        children: <Widget>[
          _HowStep(number: 1, text: 'No aparelho da criança, instale e abra o ParentaLynx.'),
          _HowStep(number: 2, text: 'Escolha "Este é o aparelho da criança".'),
          _HowStep(number: 3, text: 'Digite o código mostrado aqui.'),
          _HowStep(
            number: 4,
            text: 'Confira o número de confirmação nos dois aparelhos e aprove o pedido.',
          ),
          _HowStep(
            number: 5,
            text: 'No aparelho da criança, conceda as permissões pedidas.',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({required this.number, required this.text, this.last = false});

  final int number;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text('$number', style: theme.textTheme.labelLarge),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.device, required this.onDone, required this.onAnother});

  final Device device;
  final VoidCallback onDone;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final StatusColors status = StatusColors.of(context);
    return PageBody(
      children: <Widget>[
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: status.successContainer, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 52, color: status.success),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Aparelho de ${device.displayName} vinculado',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          device.hardwareLabel,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xl),
        const NoticeBanner(
          title: 'Falta um passo no aparelho da criança',
          message:
              'O app da criança vai pedir as permissões de acesso ao uso, acessibilidade e '
              'notificações. Sem elas o controle não consegue contar o tempo nem bloquear '
              'aplicativos. O painel avisa se alguma estiver faltando.',
        ),
        const SizedBox(height: AppSpacing.lg),
        const NoticeBanner(
          tone: Tone.neutral,
          icon: Icons.tune,
          message:
              'As regras começam sem limite de tempo. Defina o limite diário, os horários e '
              'os aplicativos na aba Regras.',
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(onPressed: onDone, child: const Text('Concluir')),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(onPressed: onAnother, child: const Text('Vincular outro aparelho')),
      ],
    );
  }
}
