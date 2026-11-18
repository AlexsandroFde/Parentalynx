import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/management_level.dart';
import '../../domain/entities/permission_plan.dart';
import '../../domain/entities/permission_step.dart';
import '../bloc/permissions/permissions_bloc.dart';
import '../texts/permission_texts.dart';

/// Assistente das permissoes de que o controle parental depende.
///
/// Mostra um passo de cada vez (o proximo a ligar, com o porque e o como) e a lista completa
/// logo abaixo. O estado e reconsultado sempre que o app volta ao primeiro plano, porque cada
/// permissao e concedida em uma tela do sistema. Na configuracao inicial ([setup]) termina com
/// "Concluir".
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
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Continuar sem as permissões?',
      message:
          'Sem as permissões obrigatórias o controle fica incompleto: o tempo pode não ser '
          'contado e apps bloqueados podem abrir.',
      consequence: 'O responsável é avisado de que a proteção está incompleta.',
      confirmLabel: 'Continuar assim',
      cancelLabel: 'Voltar e ligar',
    );
    if (confirmed && mounted) {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final PermissionsBloc bloc = context.read<PermissionsBloc>();
    return BlocConsumer<PermissionsBloc, PermissionsState>(
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
        final PermissionPlan? plan = state is PermissionsLoaded ? state.plan : null;
        return Scaffold(
          appBar: widget.setup ? null : AppBar(title: const Text('Permissões do controle')),
          bottomNavigationBar: widget.setup && plan != null
              ? _FinishBar(complete: plan.isComplete, onFinish: _finish, onAnyway: _finishAnyway)
              : null,
          body: SafeArea(
            child: StateSwitcher(
              child: switch (state) {
                PermissionsLoading() => const KeyedSubtree(
                  key: ValueKey<String>('carregando'),
                  child: LoadingState(message: 'Conferindo as permissões...'),
                ),
                PermissionsLoadFailure(:final failure) => KeyedSubtree(
                  key: const ValueKey<String>('erro'),
                  child: ErrorState.fromError(
                    failure,
                    subject: 'as permissões',
                    onRetry: () => bloc.add(const PermissionsLoadRequested()),
                  ),
                ),
                PermissionsLoaded() => KeyedSubtree(
                  key: const ValueKey<String>('conteudo'),
                  child: _Content(
                    plan: state.plan,
                    setup: widget.setup,
                    opening: state.opening,
                    onOpen: (PermissionKind kind) => bloc.add(PermissionsStepOpened(kind)),
                    onOpenAppDetails: () => bloc.add(const PermissionsAppDetailsOpened()),
                  ),
                ),
              },
            ),
          ),
        );
      },
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
  });

  final PermissionPlan plan;
  final bool setup;
  final PermissionKind? opening;
  final ValueChanged<PermissionKind> onOpen;
  final VoidCallback onOpenAppDetails;

  @override
  Widget build(BuildContext context) {
    final PermissionStep? next = plan.next;
    final int total = plan.requiredTotal;
    final int granted = plan.requiredGranted;
    final bool complete = plan.isComplete;
    final bool enabled = opening == null;
    return ChildPageBody(
      children: <Widget>[
        if (setup) ...<Widget>[
          Text('Primeiros passos · 2 de 2'.toUpperCase(), style: context.textStyles.eyebrow),
          const SizedBox(height: AppSpacing.md),
          const ChildHeader(
            icon: AppIcons.protection,
            title: 'Permissões do controle',
            message:
                'Para o controle funcionar, o Android pede algumas autorizações. Faça este passo '
                'junto com o responsável.',
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        Semantics(
          liveRegion: true,
          child: Text(
            complete
                ? 'Tudo certo: as permissões obrigatórias estão ligadas.'
                : '$granted de $total permissões obrigatórias ligadas',
            style: context.text.titleSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        UsageBar(
          fraction: total == 0 ? 1 : granted / total,
          color: complete ? context.colors.success : null,
        ),
        const SectionGap(),
        if (next != null) ...<Widget>[
          AppSection(
            title: 'Próximo passo',
            child: _NextStep(
              step: next,
              busy: opening == next.kind,
              enabled: enabled,
              showRestrictedHint: plan.needsRestrictedSettingsHint(next),
              onOpen: () => onOpen(next.kind),
              onOpenAppDetails: onOpenAppDetails,
            ),
          ),
          const SectionGap(),
        ],
        AppSection(
          title: 'Todas as permissões',
          child: AppListGroup(
            children: <Widget>[
              for (final PermissionStep step in plan.steps)
                _StepRow(
                  step: step,
                  onOpen: enabled && step.granted != true ? () => onOpen(step.kind) : null,
                ),
            ],
          ),
        ),
        const SectionGap(),
        AppSection(
          title: 'Nível de proteção',
          child: _ManagementPanel(level: plan.management),
        ),
      ],
    );
  }
}

/// O proximo passo, em destaque: para que serve, o que o servico faz e como ligar.
class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.step,
    required this.busy,
    required this.enabled,
    required this.showRestrictedHint,
    required this.onOpen,
    required this.onOpenAppDetails,
  });

  final PermissionStep step;
  final bool busy;
  final bool enabled;
  final bool showRestrictedHint;
  final VoidCallback onOpen;
  final VoidCallback onOpenAppDetails;

  @override
  Widget build(BuildContext context) {
    final PermissionStepText text = permissionStepText(step.kind);
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppIconTile(icon: text.icon, size: AppSizes.avatarLg - AppSpacing.sm),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(text.title, style: context.text.titleMedium),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _StepBadge(step: step),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            text.description,
            style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary),
          ),
          if (step.kind == PermissionKind.accessibility) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            const AppBanner(
              icon: AppIcons.privacy,
              title: 'O que este serviço faz',
              message: accessibilityDisclosure,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          StepList(steps: permissionHowTo(step.kind)),
          if (showRestrictedHint) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            AppBanner(
              tone: Tone.warning,
              title: 'A opção está apagada?',
              message: restrictedSettingsHint,
              actionLabel: 'Abrir informações do app',
              onAction: enabled ? onOpenAppDetails : null,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton.primary(
            label: text.actionLabel,
            busy: busy,
            expand: true,
            onPressed: enabled ? onOpen : null,
          ),
        ],
      ),
    );
  }
}

/// Uma permissao na lista completa. As que faltam ligar abrem a tela do Android com um toque.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.onOpen});

  final PermissionStep step;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final PermissionStepText text = permissionStepText(step.kind);
    final bool granted = step.granted == true;
    return AppListRow(
      leading: AppIconTile(
        icon: granted ? AppIcons.check : text.icon,
        tone: granted
            ? Tone.success
            : step.isRequired
            ? Tone.warning
            : Tone.info,
      ),
      title: text.title,
      subtitle: granted ? null : text.description,
      below: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _StepBadge(step: step),
      ),
      onTap: onOpen,
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.step});

  final PermissionStep step;

  @override
  Widget build(BuildContext context) {
    if (step.granted == true) {
      return const StatusBadge(label: 'Ligada', tone: Tone.success, icon: AppIcons.check);
    }
    if (step.granted == null) {
      return const StatusBadge(label: 'Passo manual', icon: AppIcons.touch);
    }
    return switch (step.importance) {
      PermissionImportance.required => const StatusBadge(
        label: 'Obrigatória, falta ligar',
        tone: Tone.warning,
        icon: AppIcons.attention,
      ),
      PermissionImportance.recommended => const StatusBadge(
        label: 'Recomendada',
        tone: Tone.info,
        icon: AppIcons.approve,
      ),
      PermissionImportance.optional => const StatusBadge(
        label: 'Opcional',
        icon: AppIcons.addCircle,
      ),
    };
  }
}

/// O que o nivel de gerenciamento deste aparelho garante e o que nao garante.
class _ManagementPanel extends StatelessWidget {
  const _ManagementPanel({required this.level});

  final ManagementLevel level;

  @override
  Widget build(BuildContext context) {
    final ManagementText text = managementText(level);
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(text.title, style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          BulletLine(icon: AppIcons.success, tone: Tone.success, text: text.guaranteed),
          BulletLine(icon: AppIcons.info, tone: Tone.neutral, text: text.notGuaranteed),
        ],
      ),
    );
  }
}

/// Barra fixa da configuracao inicial: concluir quando tudo o que e obrigatorio esta ligado,
/// ou seguir assim mesmo depois de uma confirmacao.
class _FinishBar extends StatelessWidget {
  const _FinishBar({required this.complete, required this.onFinish, required this.onAnyway});

  final bool complete;
  final VoidCallback onFinish;
  final VoidCallback onAnyway;

  @override
  Widget build(BuildContext context) {
    return StickyActionBar(
      message: complete
          ? 'Tudo pronto para o controle funcionar.'
          : 'Ligue as permissões obrigatórias para concluir.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppButton.primary(label: 'Concluir', onPressed: complete ? onFinish : null),
          if (!complete) AppButton.tertiary(label: 'Continuar mesmo assim', onPressed: onAnyway),
        ],
      ),
    );
  }
}
