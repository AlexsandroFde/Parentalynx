import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/security/pairing_code.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/services/share_service.dart';
import '../../../authentication/presentation/widgets/auth_widgets.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../domain/entities/link_code.dart';
import '../../domain/entities/link_request.dart';
import '../../domain/services/link_request_rules.dart';
import '../bloc/device_linking/device_linking_bloc.dart';
import '../dialogs/approve_link_dialog.dart';

/// Passos da vinculacao, mostrados inteiros desde o comeco.
const List<String> _steps = <String>[
  'Gere aqui um código de vinculação.',
  'No aparelho da criança, abra o ParentaLynx, escolha "Este é o aparelho da criança" e '
      'digite o código.',
  'Confira se o número de confirmação é o mesmo nos dois aparelhos e aprove.',
  'No aparelho da criança, conceda as permissões que o app pedir.',
];

/// Ajuda da vinculacao, em perguntas e respostas.
const List<HelpTopic> _help = <HelpTopic>[
  HelpTopic(
    title: 'Como funciona a vinculação?',
    body:
        'Você gera um código aqui e digita no aparelho da criança. O aparelho dela pede para '
        'entrar na sua conta e você aprova aqui, conferindo o número de confirmação.',
  ),
  HelpTopic(
    title: 'Por que conferir o número de confirmação?',
    body:
        'Ele garante que o pedido veio do aparelho que está com você. Se o número for '
        'diferente, outra pessoa pode ter usado o código: rejeite e gere outro.',
  ),
  HelpTopic(
    title: 'O código venceu ou sumiu',
    body:
        'Cada código vale 15 minutos e só pode ser usado uma vez. Por segurança, o servidor não '
        'guarda o texto do código: se ele sumiu da tela, gere outro. O anterior deixa de valer.',
  ),
  HelpTopic(
    title: 'O que acontece depois de aprovar?',
    body:
        'O aparelho da criança pede as permissões do controle: acesso ao uso, acessibilidade e '
        'notificações. Sem elas o tempo não é contado e os apps não são bloqueados. As regras '
        'começam sem limite até você definir.',
  ),
];

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
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Cancelar o código?',
      message: 'O código deixa de valer na hora e não pode mais ser digitado no aparelho.',
      consequence: 'Para vincular depois, basta gerar outro código.',
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
    final String name = request.deviceName.isEmpty ? 'este aparelho' : '"${request.deviceName}"';
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Rejeitar o pedido?',
      message: 'O aparelho $name não será vinculado à sua conta.',
      consequence: 'Para tentar de novo, será preciso gerar outro código.',
      confirmLabel: 'Rejeitar pedido',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    context.read<DeviceLinkingBloc>().add(LinkRejectionSubmitted(request.id));
  }

  /// Sai da tela de sucesso para [location] (o painel, por padrao).
  void _finish({String location = GuardianPaths.home}) {
    context.read<DeviceLinkingBloc>().add(const ApprovedLinkDismissed());
    if (location == GuardianPaths.home && context.canPop()) {
      context.pop();
    } else {
      context.go(location);
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
          showAppSnackBar(context, message, tone: Tone.success);
        }
      case ActionFailed(:final failure):
        final String lead = switch (state.command) {
          LinkingCommand.generate => 'O código não foi gerado.',
          LinkingCommand.cancel => 'O código não foi cancelado e continua valendo.',
          LinkingCommand.approve => 'O vínculo não foi aprovado.',
          LinkingCommand.reject => 'O pedido não foi rejeitado.',
          null => '',
        };
        showAppSnackBar(context, '$lead ${failure.message}'.trim(), tone: Tone.danger);
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
        final bool firstCheck = !state.loaded && !state.offline && state.code == null;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Vincular aparelho'),
            actions: const <Widget>[
              HelpButton(
                title: 'Vinculação',
                subtitle: 'Como ligar o aparelho da criança à sua conta com segurança.',
                topics: _help,
              ),
            ],
          ),
          body: StateSwitcher(
            child: approved != null
                ? _SuccessView(
                    key: const ValueKey<String>('vinculado'),
                    device: approved,
                    onDone: _finish,
                    onRules: () => _finish(location: GuardianPaths.rules),
                    onAnother: () =>
                        context.read<DeviceLinkingBloc>().add(const ApprovedLinkDismissed()),
                  )
                : firstCheck
                ? const _CheckingView(key: ValueKey<String>('conferindo'))
                : AppPageBody(
                    key: const ValueKey<String>('vinculacao'),
                    children: _content(context, state),
                  ),
          ),
        );
      },
    );
  }

  List<Widget> _content(BuildContext context, DeviceLinkingState state) {
    final LinkCode? code = state.code;
    final int? otherCodeExpiresAt = state.otherCodeStillValidUntil;
    final String? busyRequestId = state.busyRequestId;
    final int step = state.requests.isNotEmpty
        ? 2
        : code != null
        ? 1
        : 0;
    final ({String title, String subtitle}) header = switch (step) {
      2 => (
        title: 'Confira o número de confirmação',
        subtitle: 'Ele precisa ser o mesmo que aparece na tela do aparelho da criança.',
      ),
      1 => (
        title: 'Digite o código no aparelho da criança',
        subtitle:
            'No ParentaLynx do aparelho dela, escolha "Este é o aparelho da criança". A tela '
            'muda sozinha quando o código for usado.',
      ),
      _ => (
        title: 'Gere um código de vinculação',
        subtitle:
            'O código vale por 15 minutos e só pode ser usado uma vez. Depois de digitado no '
            'aparelho da criança, você confirma o vínculo aqui.',
      ),
    };
    return <Widget>[
      AppPageHeader(
        eyebrow: 'Passo ${step + 1} de ${_steps.length}',
        title: header.title,
        subtitle: header.subtitle,
      ),
      if (state.offline) ...<Widget>[
        const AppBanner(
          tone: Tone.warning,
          icon: AppIcons.offline,
          title: 'Sem conexão com o servidor',
          message:
              'Os pedidos de vínculo não chegam enquanto isso. O app tenta de novo a cada '
              'poucos segundos.',
          liveRegion: true,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (state.codeExpired && code == null && state.requests.isEmpty) ...<Widget>[
        const AppBanner(
          tone: Tone.warning,
          icon: AppIcons.timeRunningOut,
          title: 'O código venceu',
          message: 'Ele não foi usado a tempo e não vale mais. Gere outro para continuar.',
          liveRegion: true,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      for (final LinkRequest request in state.requests) ...<Widget>[
        _RequestPanel(
          request: request,
          approving: busyRequestId == request.id && state.command == LinkingCommand.approve,
          rejecting: busyRequestId == request.id && state.command == LinkingCommand.reject,
          enabled: busyRequestId == null,
          onApprove: () => _approve(request),
          onReject: () => _reject(request),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (code != null)
        _CodePanel(
          code: code,
          remaining: state.remaining,
          lifetime: LinkRequestRules.codeLifetime,
          cancelling: state.cancelling,
          onCopy: () => _copy(code),
          onShare: () => _share(code),
          onCancel: _cancelCode,
        )
      else ...<Widget>[
        if (otherCodeExpiresAt != null) ...<Widget>[
          AppBanner(
            title: 'Já existe um código válido até as ${formatClockMs(otherCodeExpiresAt)}',
            message:
                'Ele foi gerado antes e, por segurança, não pode ser mostrado de novo. Gerar um '
                'novo cancela o anterior.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppButton(
          label: state.requests.isEmpty ? 'Gerar código' : 'Gerar código para outro aparelho',
          variant: state.requests.isEmpty ? AppButtonVariant.primary : AppButtonVariant.tertiary,
          icon: AppIcons.pinCode,
          expand: true,
          busy: state.generating,
          onPressed: () => context.read<DeviceLinkingBloc>().add(const LinkCodeRequested()),
        ),
      ],
      const SectionGap(),
      AppSection(
        title: 'Como vincular',
        child: AppPanel(
          child: StepList(steps: _steps, current: step),
        ),
      ),
    ];
  }
}

/// Primeira consulta ao servidor: pode haver um pedido esperando.
class _CheckingView extends StatelessWidget {
  const _CheckingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageBody(
      children: <Widget>[
        Skeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SkeletonBox(width: 80, height: 10),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 260, height: 26),
              SizedBox(height: AppSpacing.md),
              SkeletonBox(width: 300),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xl),
        SkeletonPanel(height: 120),
      ],
    );
  }
}

class _CodePanel extends StatelessWidget {
  const _CodePanel({
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
    final String formatted = PairingCode.format(code.code);
    final bool ending = remaining.inSeconds <= 60;
    final Tone tone = ending ? Tone.warning : Tone.info;
    final double fraction = (remaining.inMilliseconds / lifetime.inMilliseconds).clamp(0.0, 1.0);
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Código de vinculação',
            textAlign: TextAlign.center,
            style: context.textStyles.eyebrow,
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: 'Código ${formatted.split('').join(' ')}',
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatted,
                maxLines: 1,
                style: context.text.displayMedium?.copyWith(
                  fontFeatures: AppTypography.tabularFigures,
                  letterSpacing: AppSpacing.xs,
                  color: context.colors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          UsageBar(fraction: fraction, color: tone.foreground(context)),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: ending,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(AppIcons.dailyLimit, size: AppSizes.iconSm, color: tone.foreground(context)),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    'Expira em ${formatCountdown(remaining.inMilliseconds)}',
                    style: context.text.labelLarge?.copyWith(color: tone.onBackground(context)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Vale até as ${formatClockMs(code.expiresAt)}, uma única vez.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          CopyShareButtons(onCopy: onCopy, onShare: onShare),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: AppSizes.hairline),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              SizedBox.square(
                dimension: AppSizes.iconSm,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Aguardando o aparelho da criança usar o código',
                  style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.tertiary(
              label: 'Cancelar código',
              size: AppButtonSize.compact,
              busy: cancelling,
              onPressed: onCancel,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestPanel extends StatelessWidget {
  const _RequestPanel({
    required this.request,
    required this.approving,
    required this.rejecting,
    required this.enabled,
    required this.onApprove,
    required this.onReject,
  });

  final LinkRequest request;
  final bool approving;
  final bool rejecting;
  final bool enabled;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final DateTime now = context.read<Clock>().now();
    final String confirmCode = request.confirmCode ?? '';
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AppIconTile(icon: AppIcons.deviceRinging),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Pedido de vínculo', style: context.text.bodySmall),
                    Text(
                      request.deviceName.isEmpty ? 'Aparelho sem nome' : request.deviceName,
                      style: context.text.titleMedium,
                    ),
                    if (request.hardwareLabel.isNotEmpty)
                      Text(
                        request.hardwareLabel,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(formatRelativeMs(request.createdAt, now: now), style: context.text.bodySmall),
            ],
          ),
          if (request.relink) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            AppBanner(
              icon: AppIcons.history,
              message: request.childName.isEmpty
                  ? 'Este aparelho já foi vinculado a esta conta. Ao aprovar, as regras e o '
                        'histórico anteriores são mantidos.'
                  : 'Este aparelho já foi vinculado a esta conta como "${request.childName}". '
                        'Ao aprovar, as regras e o histórico anteriores são mantidos.',
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surfaceMuted,
              borderRadius: context.shapes.controlRadius,
            ),
            child: Padding(
              padding: AppSpacing.panel,
              child: Column(
                children: <Widget>[
                  Text('Número de confirmação', style: context.text.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    label: 'Número de confirmação ${confirmCode.split('').join(' ')}',
                    excludeSemantics: true,
                    child: Text(
                      confirmCode.split('').join(' '),
                      style: context.text.displaySmall?.copyWith(
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Confira se o mesmo número aparece na tela do aparelho da criança. Se for '
                    'diferente ou se você não reconhece o aparelho, rejeite.',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(color: context.colors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton.secondary(
                  label: 'Rejeitar',
                  busy: rejecting,
                  onPressed: enabled ? onReject : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton.primary(
                  label: 'Aprovar',
                  busy: approving,
                  onPressed: enabled ? onApprove : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.device,
    required this.onDone,
    required this.onRules,
    required this.onAnother,
    super.key,
  });

  final LinkRequest device;
  final VoidCallback onDone;
  final VoidCallback onRules;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    return AppPageBody(
      children: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        const Center(
          child: IconMedallion(
            icon: AppIcons.check,
            tone: Tone.success,
            size: AppSizes.illustration,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            'Aparelho de ${device.displayName} vinculado',
            textAlign: TextAlign.center,
            style: context.text.headlineSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          device.hardwareLabel,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
        ),
        const SectionGap(),
        AppSection(
          title: 'Falta pouco',
          child: AppPanel(
            child: StepList(
              steps: <String>[
                'No aparelho de ${device.displayName}, conceda as permissões pedidas: acesso ao '
                    'uso, acessibilidade e notificações. Sem elas o tempo não é contado.',
                'Defina o limite diário, os horários e os aplicativos. Até lá, o aparelho fica '
                    'sem limite.',
              ],
              current: 0,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton.primary(label: 'Concluir', expand: true, onPressed: onDone),
        const SizedBox(height: AppSpacing.sm),
        AppButton.secondary(
          label: 'Definir as regras agora',
          icon: AppIcons.rules,
          expand: true,
          onPressed: onRules,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton.tertiary(label: 'Vincular outro aparelho', expand: true, onPressed: onAnother),
      ],
    );
  }
}
