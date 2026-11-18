import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/clock.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/audit_entry.dart';
import '../bloc/audit_log/audit_log_bloc.dart';
import '../texts/settings_texts.dart';

/// Registro de alteracoes administrativas da conta, do mais novo para o mais antigo.
///
/// Espera um [AuditLogBloc] acima na arvore.
class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key});

  void _reload(BuildContext context) {
    context.read<AuditLogBloc>().add(const AuditLogLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de alterações')),
      body: BlocBuilder<AuditLogBloc, AuditLogState>(
        builder: (BuildContext context, AuditLogState state) {
          return StateSwitcher(
            child: switch (state) {
              AuditLogLoading() => const KeyedSubtree(
                key: ValueKey<String>('carregando'),
                child: AppPageBody(children: <Widget>[SkeletonListGroup(rows: 6)]),
              ),
              AuditLogError(:final failure) => KeyedSubtree(
                key: const ValueKey<String>('erro'),
                child: ErrorState.fromError(
                  failure,
                  subject: 'o registro de alterações',
                  onRetry: () => _reload(context),
                ),
              ),
              AuditLogEmpty() => const KeyedSubtree(
                key: ValueKey<String>('vazio'),
                child: EmptyState(
                  icon: AppIcons.history,
                  title: 'Nenhuma alteração registrada',
                  message:
                      'Mudanças de regras, vínculos e acessos à conta aparecem aqui, com quem '
                      'fez e quando.',
                ),
              ),
              AuditLogLoaded() => KeyedSubtree(
                key: const ValueKey<String>('lista'),
                child: _AuditList(state: state),
              ),
            },
          );
        },
      ),
    );
  }
}

class _AuditList extends StatelessWidget {
  const _AuditList({required this.state});

  final AuditLogLoaded state;

  static IconData _iconFor(AuditEntry entry) {
    if (auditIsFailure(entry)) {
      return AppIcons.warning;
    }
    return switch (auditTopicOf(entry)) {
      AuditTopic.access => AppIcons.signIn,
      AuditTopic.rules => AppIcons.rules,
      AuditTopic.devices => AppIcons.device,
      AuditTopic.account => AppIcons.person,
      AuditTopic.other => AppIcons.history,
    };
  }

  void _loadMore(BuildContext context) {
    context.read<AuditLogBloc>().add(const AuditLogMoreRequested());
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = context.read<Clock>().now();
    final List<AuditEntry> entries = state.entries;
    return AppPageBody(
      children: <Widget>[
        AppSection(
          title: 'Do mais recente para o mais antigo',
          subtitle: 'Tentativas recusadas, como senha errada, aparecem em destaque.',
          child: AppListGroup(
            footer: 'O registro guarda as alterações dos últimos 365 dias.',
            children: <Widget>[
              for (final AuditEntry entry in entries)
                AppListRow(
                  leading: AppIconTile(
                    icon: _iconFor(entry),
                    tone: auditIsFailure(entry) ? Tone.danger : Tone.neutral,
                  ),
                  title: auditTitle(entry),
                  titleStyle: context.text.bodyLarge,
                  subtitle: auditSubtitle(entry, now: now),
                ),
            ],
          ),
        ),
        if (state.moreFailure != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppBanner(
            tone: Tone.danger,
            title: 'Não foi possível carregar os registros mais antigos',
            message: 'Os registros acima continuam na tela. Confira a internet e tente de novo.',
            actionLabel: 'Tentar de novo',
            onAction: () => _loadMore(context),
            liveRegion: true,
          ),
        ],
        if (state.hasMore && state.moreFailure == null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Center(
            child: AppButton.tertiary(
              label: 'Carregar mais antigos',
              icon: AppIcons.expand,
              busy: state.loadingMore,
              onPressed: () => _loadMore(context),
            ),
          ),
        ],
      ],
    );
  }
}
