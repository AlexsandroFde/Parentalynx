import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../agent/domain/child_models.dart';
import '../../agent/presentation/child_session.dart';
import '../../shared/child_widgets.dart';
import '../domain/permission_steps.dart';
import 'permission_texts.dart';
import 'permissions_controller.dart';

/// Assistente das permissoes de que o controle parental depende.
///
/// O estado e reconsultado sempre que o app volta ao primeiro plano, porque cada permissao e
/// concedida em uma tela do sistema. Na configuracao inicial ([setup]) termina com "Concluir".
class PermissionsPage extends ConsumerStatefulWidget {
  const PermissionsPage({required this.setup, super.key});

  final bool setup;

  @override
  ConsumerState<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends ConsumerState<PermissionsPage> with WidgetsBindingObserver {
  PermissionKind? _opening;

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
      unawaited(ref.read(permissionsControllerProvider.notifier).refresh());
    }
  }

  Future<void> _open(PermissionKind kind) async {
    if (_opening != null) {
      return;
    }
    setState(() => _opening = kind);
    try {
      final PermissionActionResult result = await ref
          .read(permissionsControllerProvider.notifier)
          .open(kind);
      if (mounted && result == PermissionActionResult.fallbackToAppDetails) {
        showAppSnackBar(
          context,
          'Não achamos a tela de início automático deste aparelho. Procure por "Início '
          'automático" ou "Bateria" nas informações do app.',
          tone: Tone.info,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _opening = null);
      }
    }
  }

  Future<void> _openAppDetails() async {
    try {
      await ref.read(permissionsControllerProvider.notifier).openAppDetails();
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    }
  }

  void _finish() {
    ref.read(childLinkProvider.notifier).finishOnboarding();
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
    final AsyncValue<PermissionsView> view = ref.watch(permissionsControllerProvider);
    return Scaffold(
      appBar: widget.setup ? null : AppBar(title: const Text('Permissões do controle')),
      body: SafeArea(
        child: AsyncValueView<PermissionsView>(
          value: view,
          onRetry: () => ref.invalidate(permissionsControllerProvider),
          loadingMessage: 'Verificando as permissões...',
          data: (PermissionsView data) => _Content(
            view: data,
            setup: widget.setup,
            opening: _opening,
            onOpen: _open,
            onOpenAppDetails: _openAppDetails,
            onFinish: _finish,
            onFinishAnyway: _finishAnyway,
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.view,
    required this.setup,
    required this.opening,
    required this.onOpen,
    required this.onOpenAppDetails,
    required this.onFinish,
    required this.onFinishAnyway,
  });

  final PermissionsView view;
  final bool setup;
  final PermissionKind? opening;
  final ValueChanged<PermissionKind> onOpen;
  final VoidCallback onOpenAppDetails;
  final VoidCallback onFinish;
  final VoidCallback onFinishAnyway;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<PermissionStep> steps = view.steps;
    final PermissionStep? next = nextPendingStep(steps);
    final int total = requiredCount(steps);
    final int granted = grantedRequiredCount(steps);
    final bool complete = view.requiredGranted;
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
              _ManagementCard(level: view.management),
              const SizedBox(height: AppSpacing.lg),
              for (int index = 0; index < steps.length; index++) ...<Widget>[
                _StepCard(
                  number: index + 1,
                  step: steps[index],
                  highlighted: next != null && next.kind == steps[index].kind,
                  busy: opening == steps[index].kind,
                  enabled: opening == null,
                  showRestrictedHint:
                      steps[index].kind == PermissionKind.accessibility &&
                      steps[index].isPending &&
                      view.facts.restrictedSettingsLikely,
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
