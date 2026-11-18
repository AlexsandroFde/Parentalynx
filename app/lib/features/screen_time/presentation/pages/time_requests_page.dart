import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/time_request.dart';
import '../bloc/time_requests/time_requests_bloc.dart';

/// Atalhos de tempo ao aprovar um pedido, em minutos.
const List<int> _grantOptions = <int>[15, 30, 45, 60, 90, 120];

String _who(TimeRequest request) {
  return request.childName.isEmpty ? 'A criança' : request.childName;
}

String _askedLine(BuildContext context, TimeRequest request) {
  final int? minutes = request.minutes;
  return <String>[
    if (minutes == null) 'Pediu mais tempo' else 'Pediu ${formatMinutes(minutes)}',
    formatRelativeMs(request.createdAt, now: context.read<Clock>().now()),
  ].join(' · ');
}

/// Pedidos de tempo adicional: responder os pendentes e consultar os ja respondidos.
///
/// Espera um [TimeRequestsBloc] acima na arvore, ja iniciado.
class TimeRequestsPage extends StatelessWidget {
  const TimeRequestsPage({super.key});

  Future<void> _approve(BuildContext context, TimeRequest request) async {
    final TimeRequestsBloc bloc = context.read<TimeRequestsBloc>();
    final int? minutes = await showAppSheet<int>(
      context,
      title: 'Quanto tempo conceder?',
      subtitle: 'O tempo é somado ao limite de hoje de ${_who(request)} e vale só para hoje.',
      builder: (BuildContext context) => _GrantForm(request: request),
    );
    if (minutes != null) {
      bloc.add(TimeRequestApproved(request: request, minutes: minutes));
    }
  }

  Future<void> _deny(BuildContext context, TimeRequest request) async {
    final TimeRequestsBloc bloc = context.read<TimeRequestsBloc>();
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Negar o pedido?',
      message: '${_who(request)} recebe o aviso de que o pedido de mais tempo foi negado.',
      consequence: 'O limite de hoje continua o mesmo.',
      confirmLabel: 'Negar',
      icon: AppIcons.cancelled,
    );
    if (confirmed) {
      bloc.add(TimeRequestDenied(request));
    }
  }

  Future<void> _refresh(BuildContext context) {
    final Completer<void> done = Completer<void>();
    context.read<TimeRequestsBloc>().add(TimeRequestsRefreshRequested(completer: done));
    return done.future;
  }

  void _onAction(BuildContext context, TimeRequestsState state) {
    if (state is! TimeRequestsLoaded) {
      return;
    }
    switch (state.action) {
      case ActionSucceeded(:final String? message):
        if (message != null) {
          showAppSnackBar(context, message, tone: Tone.success);
        }
      case ActionFailed(:final failure):
        showAppSnackBar(
          context,
          'Não foi possível responder o pedido. ${failure.message}',
          tone: Tone.danger,
        );
      case ActionIdle() || ActionRunning():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos de tempo')),
      body: BlocConsumer<TimeRequestsBloc, TimeRequestsState>(
        listenWhen: (TimeRequestsState previous, TimeRequestsState current) {
          return current is TimeRequestsLoaded &&
              (previous is! TimeRequestsLoaded || previous.action != current.action);
        },
        listener: _onAction,
        builder: (BuildContext context, TimeRequestsState state) {
          return StateSwitcher(
            child: switch (state) {
              TimeRequestsLoading() => const KeyedSubtree(
                key: ValueKey<String>('carregando'),
                child: AppPageBody(
                  children: <Widget>[SkeletonPanel(height: 180), SectionGap(), SkeletonListGroup()],
                ),
              ),
              TimeRequestsError(:final failure) => KeyedSubtree(
                key: const ValueKey<String>('erro'),
                child: ErrorState.fromError(
                  failure,
                  subject: 'os pedidos de tempo',
                  onRetry: () => context.read<TimeRequestsBloc>().add(const TimeRequestsStarted()),
                ),
              ),
              TimeRequestsEmpty() => KeyedSubtree(
                key: const ValueKey<String>('vazio'),
                child: AppPageBody(
                  onRefresh: () => _refresh(context),
                  children: const <Widget>[
                    SizedBox(height: AppSpacing.xxxl),
                    EmptyState(
                      compact: true,
                      icon: AppIcons.timeRequest,
                      title: 'Nenhum pedido de tempo',
                      message:
                          'Quando a criança pedir mais tempo pelo aparelho dela, o pedido '
                          'aparece aqui para você aprovar ou negar.',
                    ),
                  ],
                ),
              ),
              TimeRequestsLoaded() => KeyedSubtree(
                key: const ValueKey<String>('pedidos'),
                child: AppPageBody(
                  onRefresh: () => _refresh(context),
                  children: <Widget>[
                    _Requests(
                      state: state,
                      onApprove: (TimeRequest request) => _approve(context, request),
                      onDeny: (TimeRequest request) => _deny(context, request),
                    ),
                  ],
                ),
              ),
            },
          );
        },
      ),
    );
  }
}

class _Requests extends StatelessWidget {
  const _Requests({required this.state, required this.onApprove, required this.onDeny});

  final TimeRequestsLoaded state;
  final ValueChanged<TimeRequest> onApprove;
  final ValueChanged<TimeRequest> onDeny;

  @override
  Widget build(BuildContext context) {
    final List<TimeRequest> pending = state.pending;
    final List<TimeRequest> resolved = state.resolved;
    final String? resolving = state.resolvingId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSection(
          title: 'Aguardando resposta',
          trailing: pending.isEmpty
              ? null
              : StatusBadge(
                  label: pending.length == 1 ? '1 pedido' : '${pending.length} pedidos',
                  tone: Tone.warning,
                  icon: AppIcons.pending,
                ),
          child: pending.isEmpty
              ? const AppBanner(
                  tone: Tone.success,
                  icon: AppIcons.checkAll,
                  message: 'Nenhum pedido aguardando resposta.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int i = 0; i < pending.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: AppSpacing.md),
                      _PendingRequest(
                        request: pending[i],
                        busy: resolving == pending[i].id,
                        enabled: resolving == null,
                        onApprove: () => onApprove(pending[i]),
                        onDeny: () => onDeny(pending[i]),
                      ),
                    ],
                  ],
                ),
        ),
        if (resolved.isNotEmpty) ...<Widget>[
          const SectionGap(),
          AppSection(
            title: 'Respondidos',
            child: AppListGroup(
              children: <Widget>[
                for (final TimeRequest request in resolved) _ResolvedRequest(request: request),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PendingRequest extends StatelessWidget {
  const _PendingRequest({
    required this.request,
    required this.busy,
    required this.enabled,
    required this.onApprove,
    required this.onDeny,
  });

  final TimeRequest request;
  final bool busy;
  final bool enabled;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final String? message = request.message?.trim();
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MergeSemantics(
            child: Row(
              children: <Widget>[
                InitialAvatar(name: _who(request)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        request.childName.isEmpty ? 'Pedido de tempo' : request.childName,
                        style: context.text.titleMedium,
                      ),
                      Text(
                        _askedLine(context, request),
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (message != null && message.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.surfaceMuted,
                borderRadius: context.shapes.controlRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Semantics(
                  label: 'Mensagem: $message',
                  excludeSemantics: true,
                  child: Text('"$message"', style: context.text.bodyMedium),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton.secondary(label: 'Negar', onPressed: enabled ? onDeny : null),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton.primary(
                  label: 'Aprovar',
                  icon: AppIcons.extraTime,
                  busy: busy,
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

class _ResolvedRequest extends StatelessWidget {
  const _ResolvedRequest({required this.request});

  final TimeRequest request;

  @override
  Widget build(BuildContext context) {
    final int? granted = request.grantedMinutes;
    final (String label, Tone tone, IconData icon) = switch (request.status) {
      TimeRequestStatus.approved => (
        granted == null ? 'Aprovado' : 'Aprovado: ${formatMinutes(granted)}',
        Tone.success,
        AppIcons.success,
      ),
      TimeRequestStatus.denied => ('Negado', Tone.neutral, AppIcons.cancelled),
      TimeRequestStatus.expired => ('Expirou sem resposta', Tone.neutral, AppIcons.history),
      TimeRequestStatus.pending => ('Aguardando', Tone.warning, AppIcons.pending),
    };
    final Widget badge = StatusBadge(label: label, tone: tone, icon: icon);
    final bool roomy = MediaQuery.textScalerOf(context).scale(AppSpacing.lg) <= AppSpacing.xl;
    return AppListRow(
      leading: InitialAvatar(name: _who(request), size: AppSizes.avatarMd),
      title: request.childName.isEmpty ? 'Pedido de tempo' : request.childName,
      subtitle: _askedLine(context, request),
      trailing: roomy ? badge : null,
      below: roomy ? null : Align(alignment: AlignmentDirectional.centerStart, child: badge),
    );
  }
}

/// Escolha de quantos minutos conceder ao aprovar um pedido: atalhos e um valor proprio.
class _GrantForm extends StatefulWidget {
  const _GrantForm({required this.request});

  final TimeRequest request;

  @override
  State<_GrantForm> createState() => _GrantFormState();
}

class _GrantFormState extends State<_GrantForm> {
  late int _minutes = widget.request.suggestedGrantMinutes;

  Future<void> _pickOther() async {
    final int? minutes = await showDurationPicker(
      context,
      title: 'Outro tempo',
      helper: 'Até ${formatMinutes(TimeRequest.maxGrantMinutes)} de uma vez.',
      initialMinutes: _minutes,
      minMinutes: 1,
      maxMinutes: TimeRequest.maxGrantMinutes,
    );
    if (minutes != null) {
      setState(() => _minutes = minutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? asked = widget.request.minutes;
    final List<int> options = <int>{..._grantOptions, _minutes}.toList()..sort();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (asked != null) ...<Widget>[
          Text(
            '${_who(widget.request)} pediu ${formatMinutes(asked)}.',
            style: context.text.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppChoiceChips<int>(
          choices: <AppChoice<int>>[
            for (final int option in options)
              AppChoice<int>(value: option, label: formatMinutes(option)),
          ],
          selected: _minutes,
          onSelected: (int value) => setState(() => _minutes = value),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.tertiary(
            label: 'Outro tempo',
            icon: AppIcons.edit,
            size: AppButtonSize.compact,
            onPressed: _pickOther,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton.primary(
          label: 'Conceder ${formatMinutes(_minutes)}',
          icon: AppIcons.extraTime,
          expand: true,
          onPressed: () => Navigator.of(context).pop(_minutes),
        ),
      ],
    );
  }
}
