import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../../child_device/presentation/widgets/device_selector.dart';
import '../../../device_sync/presentation/widgets/policy_sync_status_view.dart';
import '../../domain/entities/policy.dart';
import '../bloc/policy_overview/policy_overview_bloc.dart';
import '../overview/rule_group.dart';
import '../widgets/rule_editor_scaffold.dart';

/// Ajuda da aba Regras: quando uma regra passa a valer, o fuso dos horarios e o que a crianca
/// ve.
const List<HelpTopic> _rulesHelp = <HelpTopic>[
  HelpTopic(
    title: 'Quando uma regra passa a valer?',
    body:
        'Ao salvar, a regra vai para o servidor e o aparelho da criança aplica assim que '
        'recebe. Até ele confirmar, a tela mostra "Aguardando o aparelho confirmar" e as regras '
        'anteriores continuam valendo. Sem internet, o aparelho recebe quando voltar a ficar '
        'online.',
  ),
  HelpTopic(
    title: 'Em que fuso valem os horários?',
    body:
        'A hora de dormir, os horários permitidos e o reinício do limite seguem o fuso que o '
        'aparelho informou quando foi vinculado. Mudar a hora ou o fuso no aparelho não altera '
        'a contagem do dia e gera um alerta para você.',
  ),
  HelpTopic(
    title: 'O que a criança vê?',
    body:
        'No aparelho dela aparecem as regras de hoje e o motivo de cada bloqueio, e ela pode '
        'pedir mais tempo. A criança não consegue mudar nem desligar as regras.',
  ),
];

/// Aba "Regras": escolhe o aparelho em foco e explica quando nao ha aparelho vinculado.
///
/// O conteudo de um aparelho e montado por [bodyBuilder], que recebe o aparelho e cria o
/// BLoC da visao geral com uma chave pelo identificador (recomeca ao trocar de aparelho).
class RulesOverviewGate extends StatelessWidget {
  const RulesOverviewGate({required this.bodyBuilder, super.key});

  final Widget Function(BuildContext context, ChildDevice device) bodyBuilder;

  @override
  Widget build(BuildContext context) {
    final DevicesState devices = context.watch<DevicesBloc>().state;
    final ChildDevice? device = devices.selected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regras'),
        actions: const <Widget>[HelpButton(title: 'Regras', topics: _rulesHelp)],
      ),
      body: device == null ? _NoDevice(state: devices) : bodyBuilder(context, device),
    );
  }
}

class _NoDevice extends StatelessWidget {
  const _NoDevice({required this.state});

  final DevicesState state;

  @override
  Widget build(BuildContext context) {
    return StateSwitcher(
      child: switch (state) {
        DevicesInitial() || DevicesLoading() => const KeyedSubtree(
          key: ValueKey<String>('carregando'),
          child: LoadingState(message: 'Carregando os aparelhos'),
        ),
        DevicesError(:final failure) => KeyedSubtree(
          key: const ValueKey<String>('erro'),
          child: ErrorState.fromError(
            failure,
            subject: 'os aparelhos',
            onRetry: () => context.read<DevicesBloc>().add(const DevicesRefreshRequested()),
          ),
        ),
        DevicesEmpty() || DevicesLoaded() => KeyedSubtree(
          key: const ValueKey<String>('vazio'),
          child: EmptyState(
            icon: AppIcons.rules,
            title: 'Nenhum aparelho vinculado',
            message:
                'As regras são definidas por aparelho. Vincule o celular da criança para '
                'começar.',
            actionLabel: 'Vincular aparelho',
            onAction: () => context.push(GuardianPaths.pairing),
          ),
        ),
      },
    );
  }
}

/// Visao geral das regras de um aparelho: o estado de aplicacao e o resumo de cada grupo,
/// organizados por assunto.
///
/// Espera um [PolicyOverviewBloc] acima na arvore. Os grupos vem das funcionalidades de
/// regras, na ordem em que devem aparecer.
class RulesOverviewBody extends StatelessWidget {
  const RulesOverviewBody({required this.device, required this.groups, super.key});

  final ChildDevice device;
  final List<RuleGroup> groups;

  Future<void> _refresh(BuildContext context) {
    final Completer<void> done = Completer<void>();
    context.read<PolicyOverviewBloc>().add(PolicyOverviewRefreshRequested(completer: done));
    return done.future;
  }

  @override
  Widget build(BuildContext context) {
    final String name = device.displayName;
    return BlocBuilder<PolicyOverviewBloc, PolicyOverviewState>(
      builder: (BuildContext context, PolicyOverviewState state) {
        return AppPageBody(
          onRefresh: () => _refresh(context),
          children: <Widget>[
            const DeviceSelector(),
            AppPageHeader(
              title: 'Regras de $name',
              subtitle: device.hardwareLabel,
              trailing: InitialAvatar(name: name, size: AppSizes.avatarLg),
            ),
            StateSwitcher(
              child: switch (state) {
                PolicyOverviewLoading() => const KeyedSubtree(
                  key: ValueKey<String>('carregando'),
                  child: _OverviewSkeleton(),
                ),
                PolicyOverviewError(:final failure) => KeyedSubtree(
                  key: const ValueKey<String>('erro'),
                  child: AppPanel(
                    child: ErrorState.fromError(
                      failure,
                      subject: 'as regras de $name',
                      compact: true,
                      onRetry: () {
                        context.read<PolicyOverviewBloc>().add(PolicyOverviewStarted(device.id));
                      },
                    ),
                  ),
                ),
                PolicyOverviewLoaded(:final policy) => KeyedSubtree(
                  key: const ValueKey<String>('regras'),
                  child: _Groups(
                    device: device,
                    policy: policy.policy,
                    version: policy.version,
                    groups: groups,
                  ),
                ),
              },
            ),
          ],
        );
      },
    );
  }
}

class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SkeletonListGroup(rows: 1),
        SectionGap(),
        SkeletonListGroup(),
        SectionGap(),
        SkeletonListGroup(rows: 2),
      ],
    );
  }
}

class _Groups extends StatelessWidget {
  const _Groups({
    required this.device,
    required this.policy,
    required this.version,
    required this.groups,
  });

  final ChildDevice device;
  final Policy policy;
  final int version;
  final List<RuleGroup> groups;

  @override
  Widget build(BuildContext context) {
    // Agrupa por assunto, na ordem em que os assuntos aparecem; sem assunto vai para o fim.
    final Map<RuleGroupTopic?, List<RuleGroup>> byTopic = <RuleGroupTopic?, List<RuleGroup>>{};
    for (final RuleGroup group in groups.where((RuleGroup g) => g.topic != null)) {
      byTopic.putIfAbsent(group.topic, () => <RuleGroup>[]).add(group);
    }
    final List<RuleGroup> loose = groups.where((RuleGroup g) => g.topic == null).toList();
    if (loose.isNotEmpty) {
      byTopic[null] = loose;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PolicySyncStatusView(status: effectivePolicySync(device, version)),
        for (final MapEntry<RuleGroupTopic?, List<RuleGroup>> topic in byTopic.entries) ...<Widget>[
          const SectionGap(),
          AppSection(
            title: topic.key?.title,
            child: AppListGroup(
              children: <Widget>[
                for (final RuleGroup group in topic.value)
                  _GroupRow(group: group, policy: policy, device: device),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            'Os horários seguem o fuso do aparelho de ${device.displayName} '
            '(${policy.timezone}).',
            style: context.text.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.policy, required this.device});

  final RuleGroup group;
  final Policy policy;
  final ChildDevice device;

  @override
  Widget build(BuildContext context) {
    final bool active = group.isActive?.call(policy, device) ?? true;
    return AppListRow(
      key: ValueKey<String>('rule-group-${group.path}'),
      leading: AppIconTile(icon: group.icon, tone: active ? group.tone : Tone.neutral),
      title: group.title,
      subtitle: group.summarize(policy, device),
      onTap: () => context.push(group.path),
    );
  }
}
