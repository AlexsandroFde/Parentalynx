import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/route_paths.dart';
import '../../../../../shared/design_system/design_system.dart';

/// Esqueleto do painel enquanto os dados chegam: a pagina ja mostra a sua forma (cabecalho,
/// tempo de hoje e lista), e a troca pelo conteudo e suave.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageBody(
      children: <Widget>[
        Skeleton(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SkeletonBox(width: 48, height: 10),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonBox(width: 140, height: 26),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonBox(width: 210),
                  ],
                ),
              ),
              SkeletonBox(
                width: AppSizes.avatarLg,
                height: AppSizes.avatarLg,
                radius: AppRadius.pill,
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xl),
        SkeletonPanel(height: 320),
        SectionGap(),
        SkeletonListGroup(),
      ],
    );
  }
}

/// Inicio sem aparelho ativo: explica o que o painel mostra, leva para a vinculacao e mostra
/// o caminho inteiro em passos. Com um pedido de vinculo esperando, leva direto a ele.
class DashboardNoDevice extends StatelessWidget {
  const DashboardNoDevice({required this.pending, required this.hasInactive, super.key});

  /// Pedidos de vinculo aguardando a aprovacao do responsavel.
  final int pending;

  /// A conta tem aparelhos desvinculados (nenhum ativo).
  final bool hasInactive;

  static const List<String> steps = <String>[
    'No aparelho da criança, instale o ParentaLynx e escolha "Este é o aparelho da criança".',
    'Gere aqui um código de vinculação e digite no aparelho da criança.',
    'Confira se o número de confirmação é o mesmo nos dois aparelhos e aprove.',
  ];

  @override
  Widget build(BuildContext context) {
    final bool waiting = pending > 0;
    final String title = waiting
        ? (pending == 1
              ? 'Um aparelho aguarda a sua aprovação'
              : '$pending aparelhos aguardam a sua aprovação')
        : hasInactive
        ? 'Nenhum aparelho ativo'
        : 'Nenhum aparelho vinculado';
    final String message = waiting
        ? 'Confira o número de confirmação mostrado nos dois aparelhos e aprove o vínculo.'
        : hasInactive
        ? 'Os aparelhos desta conta foram desvinculados. Vincule de novo para voltar a definir '
              'limites e acompanhar o uso.'
        : 'Vincule o celular da criança para definir limites e horários e acompanhar o uso de '
              'cada app.';
    return AppPageBody(
      children: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        _Lead(
          icon: waiting ? AppIcons.deviceRinging : AppIcons.deviceSetup,
          title: title,
          message: message,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton.primary(
          label: waiting ? 'Ver pedido de vínculo' : 'Vincular aparelho',
          icon: waiting ? AppIcons.deviceRinging : AppIcons.addLink,
          expand: true,
          onPressed: () => context.push(GuardianPaths.pairing),
        ),
        if (hasInactive) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          AppButton.tertiary(
            label: 'Ver aparelhos da conta',
            expand: true,
            onPressed: () => context.push(GuardianPaths.devices),
          ),
        ],
        const SectionGap(),
        AppSection(
          title: 'Como funciona',
          child: AppPanel(
            child: StepList(steps: steps, current: waiting ? 2 : null),
          ),
        ),
      ],
    );
  }
}

class _Lead extends StatelessWidget {
  const _Lead({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    const double blob = AppSizes.illustration + AppSpacing.lg;
    return Column(
      children: <Widget>[
        ExcludeSemantics(
          child: Container(
            width: blob,
            height: blob,
            decoration: BoxDecoration(color: Tone.info.background(context), shape: BoxShape.circle),
            child: Icon(icon, size: blob * 0.45, color: Tone.info.foreground(context)),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          child: Text(title, textAlign: TextAlign.center, style: context.text.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary),
        ),
      ],
    );
  }
}
