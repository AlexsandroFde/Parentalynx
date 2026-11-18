import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/child_layout.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../domain/entities/management_level.dart';
import '../../domain/entities/permission_plan.dart';
import '../../domain/entities/permission_step.dart';
import '../bloc/permissions/permissions_bloc.dart';
import '../texts/permission_texts.dart';

/// Assistente das permissoes de que o controle parental depende.
///
/// O estado e reconsultado sempre que o app volta ao primeiro plano, porque cada permissao e
/// concedida em uma tela do sistema. Na configuracao inicial ([setup]) termina com "Concluir".
///
/// Precisa de um [PermissionsBloc] acima na arvore.
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({required this.setup, super.key});

  final bool setup;

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<PermissionsBloc>().add(const PermissionsRefreshRequested());
    }
  }

  void _finish() {
    context.read<PermissionsBloc>().add(const PermissionsSetupFinished());
  }

  Future<void> _finishAnyway() async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Continuar sem as permissões?',
      message:
          'Sem as permissões obrigatórias o controle fica incompleto: o tempo pode não ser '
          'contado e apps bloqueados podem abrir. O responsável é avisado de que a proteção '
          'está incompleta.',
      confirmLabel: 'Continuar assim',
      cancelLabel: 'Voltar',
    );
    if (confirmed && mounted) {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final PermissionsBloc bloc = context.read<PermissionsBloc>();
    return Scaffold(
      appBar: widget.setup ? null : AppBar(title: const Text('Permissões do controle')),
      body: SafeArea(
        child: BlocConsumer<PermissionsBloc, PermissionsState>(
          listenWhen: (PermissionsState previous, PermissionsState current) {
            return current is PermissionsLoaded &&
                (previous is! PermissionsLoaded || previous.action != current.action);
          },
          listener: (BuildContext context, PermissionsState state) {
            switch ((state as PermissionsLoaded).action) {
              case ActionFailed(:final failure):
                showFailure(context, failure);
              case ActionSucceeded(:final String message?):
                showAppSnackBar(context, message, tone: Tone.info);
              case ActionIdle() || ActionRunning() || ActionSucceeded():
                break;
            }
          },
          builder: (BuildContext context, PermissionsState state) {
            return switch (state) {
              PermissionsLoading() => const LoadingView(message: 'Verificando as permissões...'),
              PermissionsLoadFailure(:final failure) => FailureView(
                error: failure,
                onRetry: () => bloc.add(const PermissionsLoadRequested()),
              ),
              PermissionsLoaded() => _Content(
                plan: state.plan,
                setup: widget.setup,
                opening: state.opening,
                onOpen: (PermissionKind kind) => bloc.add(PermissionsStepOpened(kind)),
                onOpenAppDetails: () => bloc.add(const PermissionsAppDetailsOpened()),
                onFinish: _finish,
                onFinishAnyway: _finishAnyway,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.plan,
    required this.setup,
    required this.opening,
    required this.onOpen,
    required this.onOpenAppDetails,
    required this.onFinish,
    required this.onFinishAnyway,
  });

  final PermissionPlan plan;
  final bool setup;
  final PermissionKind? opening;
  final ValueChanged<PermissionKind> onOpen;
  final VoidCallback onOpenAppDetails;
  final VoidCallback onFinish;
  final VoidCallback onFinishAnyway;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<PermissionStep> steps = plan.steps;
    final PermissionStep? next = plan.next;
    final int total = plan.requiredTotal;
    final int granted = plan.requiredGranted;
    final bool complete = plan.isComplete;
    return Column(
      children: <Widget>[
        Expanded(
          child: ChildPageBody(
            padding: EdgeInsets.fromLTRB(20, setup ? 28 : 8, 20, 24),
            children: <Widget>[
              if (setup) ...<Widget>[
                const ChildHeader(
                  icon: Icons.verified_user_outlined,
                  title: 'Permissões do controle',
                  message:
                      'Para o controle funcionar, o Android precisa de algumas permissões. '
                      'Faça este passo junto com o responsável.',
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              Semantics(
                liveRegion: true,
                child: Text(
                  complete
                      ? 'Tudo certo: as permissões obrigatórias estão ligadas.'
                      : '$granted de $total permissões obrigatórias ligadas',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: total == 0 ? 1 : granted / total,
                  color: complete ? StatusColors.of(context).success : null,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ManagementCard(level: plan.management),
              const SizedBox(height: AppSpacing.lg),
              for (int index = 0; index < steps.length; index++) ...<Widget>[
                _StepCard(
                  number: index + 1,
                  step: steps[index],
                  highlighted: next != null && next.kind == steps[index].kind,
                  busy: opening == steps[index].kind,
                  enabled: opening == null,
                  showRestrictedHint: plan.needsRestrictedSettingsHint(steps[index]),
                  onOpen: () => onOpen(steps[index].kind),
                  onOpenAppDetails: onOpenAppDetails,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
        if (setup)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  BusyButton(label: 'Concluir', onPressed: complete ? onFinish : null),
                  if (!complete)
                    TextButton(
                      onPressed: onFinishAnyway,
                      child: const Text('Continuar mesmo assim'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({required this.level});

  final ManagementLevel level;

  @override
  Widget build(BuildContext context) {
    final ManagementText text = managementText(level);
    final StatusColors colors = StatusColors.of(context);
    return SectionCard(
      title: text.title,
      subtitle: 'Nível de proteção deste aparelho',
      child: Column(
        children: <Widget>[
          BulletLine(
            icon: Icons.check_circle_outline,
            color: colors.success,
            text: text.guaranteed,
          ),
          BulletLine(icon: Icons.info_outline, color: colors.warning, text: text.notGuaranteed),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.step,
    required this.highlighted,
    required this.busy,
    required this.enabled,
    required this.showRestrictedHint,
    required this.onOpen,
    required this.onOpenAppDetails,
  });

  final int number;
  final PermissionStep step;
  final bool highlighted;
  final bool busy;
  final bool enabled;
  final bool showRestrictedHint;
  final VoidCallback onOpen;
  final VoidCallback onOpenAppDetails;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PermissionStepText text = permissionStepText(step.kind);
    final bool granted = step.granted == true;
    final bool showAction = !granted;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: highlighted
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: granted
                        ? StatusColors.of(context).successContainer
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    granted ? Icons.check_rounded : text.icon,
                    color: granted
                        ? StatusColors.of(context).success
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('$number. ${text.title}', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      _StepPill(step: step),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              text.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (step.kind == PermissionKind.accessibility && !granted) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              const NoticeBanner(
                icon: Icons.privacy_tip_outlined,
                title: 'O que este serviço faz',
                message: accessibilityDisclosure,
              ),
            ],
            if (showRestrictedHint) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              NoticeBanner(
                tone: Tone.warning,
                title: 'A opção está apagada?',
                message: restrictedSettingsHint,
                actionLabel: 'Abrir informações do app',
                onAction: enabled ? onOpenAppDetails : null,
              ),
            ],
            if (showAction) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              BusyButton(
                label: text.actionLabel,
                busy: busy,
                tonal: !highlighted,
                onPressed: enabled ? onOpen : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.step});

  final PermissionStep step;

  @override
  Widget build(BuildContext context) {
    if (step.granted == true) {
      return const StatusPill(label: 'Ligada', tone: Tone.success, icon: Icons.check_rounded);
    }
    if (step.granted == null) {
      return const StatusPill(label: 'Passo manual', icon: Icons.touch_app_outlined);
    }
    return switch (step.importance) {
      PermissionImportance.required => const StatusPill(
        label: 'Obrigatória, falta ligar',
        tone: Tone.warning,
        icon: Icons.priority_high_rounded,
      ),
      PermissionImportance.recommended => const StatusPill(
        label: 'Recomendada',
        tone: Tone.info,
        icon: Icons.thumb_up_alt_outlined,
      ),
      PermissionImportance.optional => const StatusPill(
        label: 'Opcional',
        icon: Icons.add_circle_outline,
      ),
    };
  }
}
