import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/security/pairing_code.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/services/share_service.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../authentication/presentation/widgets/auth_widgets.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../domain/entities/link_code.dart';
import '../../domain/entities/link_request.dart';
import '../../domain/services/link_request_rules.dart';
import '../bloc/device_linking/device_linking_bloc.dart';
import '../dialogs/approve_link_dialog.dart';

/// Vinculacao de um aparelho da crianca: gera o codigo, acompanha o pedido e confirma.
///
/// Espera acima na arvore o [DeviceLinkingBloc] e o [DevicesBloc] (o aparelho aprovado passa a
/// ser o aparelho em foco no painel).
class PairingPage extends StatefulWidget {
  const PairingPage({super.key});

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  Timer? _ticker;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    // O relogio redesenha a contagem regressiva. A consulta periodica e a reserva para o
    // caso de o aviso em tempo real nao chegar.
    final DeviceLinkingBloc bloc = context.read<DeviceLinkingBloc>();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => bloc.add(const LinkCodeTicked()));
    _poller = Timer.periodic(
      const Duration(seconds: 5),
      (_) => bloc.add(const LinkRequestsCheckRequested()),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    super.dispose();
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
    context.read<DeviceLinkingBloc>().add(const LinkCodeCancelRequested());
  }

  Future<void> _copy(LinkCode code) async {
    await context.read<ShareService>().copy(PairingCode.format(code.code));
    if (mounted) {
      showAppSnackBar(context, 'Código copiado.', tone: Tone.success);
    }
  }

  Future<void> _share(LinkCode code) async {
    try {
      await context.read<ShareService>().shareText(
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

  Future<void> _approve(LinkRequest request) async {
    final String? childName = await showApproveLinkDialog(context, request);
    if (childName == null || !mounted) {
      return;
    }
    context.read<DeviceLinkingBloc>().add(
      LinkApprovalSubmitted(requestId: request.id, childName: childName),
    );
  }

  Future<void> _reject(LinkRequest request) async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Rejeitar o pedido?',
      message:
          'O aparelho "${request.deviceName}" não será vinculado. Para tentar de novo será '
          'preciso gerar outro código.',
      confirmLabel: 'Rejeitar',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    context.read<DeviceLinkingBloc>().add(LinkRejectionSubmitted(request.id));
  }

  void _finish() {
    context.read<DeviceLinkingBloc>().add(const ApprovedLinkDismissed());
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(GuardianPaths.home);
    }
  }

  void _onAction(BuildContext context, DeviceLinkingState state) {
    switch (state.action) {
      case ActionSucceeded(:final String? message):
        final LinkRequest? approved = state.approved;
        if (state.command == LinkingCommand.approve && approved != null) {
          // O aparelho aprovado passa a ser o aparelho em foco no painel.
          context.read<DevicesBloc>().add(DeviceSelected(approved.id));
        }
        if (message != null) {
          showAppSnackBar(context, message);
        }
      case ActionFailed(:final failure):
        showFailure(context, failure);
      case ActionIdle() || ActionRunning():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DeviceLinkingBloc, DeviceLinkingState>(
      listenWhen: (DeviceLinkingState previous, DeviceLinkingState current) {
        return previous.action != current.action;
      },
      listener: _onAction,
      builder: (BuildContext context, DeviceLinkingState state) {
        final LinkRequest? approved = state.approved;
        return Scaffold(
          appBar: AppBar(title: const Text('Vincular aparelho')),
          body: approved != null
              ? _SuccessView(
                  device: approved,
                  onDone: _finish,
                  onAnother: () =>
                      context.read<DeviceLinkingBloc>().add(const ApprovedLinkDismissed()),
                )
              : PageBody(children: _content(context, state)),
        );
      },
    );
  }

  List<Widget> _content(BuildContext context, DeviceLinkingState state) {
    final LinkCode? code = state.code;
    final int? otherCodeExpiresAt = state.otherCodeStillValidUntil;
    final String? busyRequestId = state.busyRequestId;
    return <Widget>[
      if (state.offline) ...<Widget>[
        const NoticeBanner(
          tone: Tone.warning,
          icon: Icons.cloud_off_outlined,
          message: 'Sem conexão com o servidor. Tentando de novo a cada poucos segundos.',
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      for (final LinkRequest request in state.requests) ...<Widget>[
        _PendingLinkCard(
          request: request,
          busy: busyRequestId == request.id,
          enabled: busyRequestId == null,
          onApprove: () => _approve(request),
          onReject: () => _reject(request),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (code != null)
        _CodeCard(
          code: code,
          remaining: state.remaining,
          lifetime: LinkRequestRules.codeLifetime,
          cancelling: state.cancelling,
          onCopy: () => _copy(code),
          onShare: () => _share(code),
          onCancel: _cancelCode,
        )
      else ...<Widget>[
        _GenerateCard(
          hasPending: state.requests.isNotEmpty,
          busy: state.generating,
          onGenerate: () => context.read<DeviceLinkingBloc>().add(const LinkCodeRequested()),
        ),
        if (otherCodeExpiresAt != null) ...<Widget>[
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

  final LinkCode code;
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
    required this.request,
    required this.busy,
    required this.enabled,
    required this.onApprove,
    required this.onReject,
  });

  final LinkRequest request;
  final bool busy;
  final bool enabled;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = context.read<Clock>().now();
    final String confirmCode = request.confirmCode ?? '';
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
                  formatRelativeMs(request.createdAt, now: now),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              request.deviceName.isEmpty ? 'Aparelho sem nome' : request.deviceName,
              style: theme.textTheme.titleLarge,
            ),
            if (request.hardwareLabel.isNotEmpty)
              Text(
                request.hardwareLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (request.relink) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              NoticeBanner(
                icon: Icons.history,
                message: request.childName.isEmpty
                    ? 'Este aparelho já foi vinculado a esta conta. Ao aprovar, as regras e o '
                          'histórico anteriores são mantidos.'
                    : 'Este aparelho já foi vinculado a esta conta como "${request.childName}". '
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

  final LinkRequest device;
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
