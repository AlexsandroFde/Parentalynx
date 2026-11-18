import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../domain/entities/time_request.dart';
import '../bloc/time_requests/time_requests_bloc.dart';

/// Pedidos de tempo adicional: responder os pendentes e consultar os ja respondidos.
///
/// Espera um [TimeRequestsBloc] acima na arvore, ja iniciado.
class TimeRequestsPage extends StatelessWidget {
  const TimeRequestsPage({super.key});

  Future<void> _approve(BuildContext context, TimeRequest request) async {
    final TimeRequestsBloc bloc = context.read<TimeRequestsBloc>();
    final int? minutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => _GrantSheet(request: request),
    );
    if (minutes != null) {
      bloc.add(TimeRequestApproved(request: request, minutes: minutes));
    }
  }

  Future<void> _deny(BuildContext context, TimeRequest request) async {
    final TimeRequestsBloc bloc = context.read<TimeRequestsBloc>();
    final bool confirmed = await confirmAction(
      context,
      title: 'Negar o pedido?',
      message: '${_who(request)} será avisado de que o pedido de mais tempo foi negado.',
      confirmLabel: 'Negar',
    );
    if (confirmed) {
      bloc.add(TimeRequestDenied(request));
    }
  }

  static String _who(TimeRequest request) {
    return request.childName.isEmpty ? 'A criança' : request.childName;
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
        showFailure(context, failure);
      case ActionIdle() || ActionRunning():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos de tempo')),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: BlocConsumer<TimeRequestsBloc, TimeRequestsState>(
          listenWhen: (TimeRequestsState previous, TimeRequestsState current) {
            return current is TimeRequestsLoaded &&
                (previous is! TimeRequestsLoaded || previous.action != current.action);
          },
          listener: _onAction,
          builder: (BuildContext context, TimeRequestsState state) {
            return switch (state) {
              TimeRequestsLoading() => const LoadingView(),
              TimeRequestsError(:final failure) => FailureView(
                error: failure,
                onRetry: () => context.read<TimeRequestsBloc>().add(const TimeRequestsStarted()),
              ),
              TimeRequestsEmpty() => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const <Widget>[
                  SizedBox(
                    height: 420,
                    child: EmptyState(
                      icon: Icons.more_time,
                      title: 'Nenhum pedido de tempo',
                      message:
                          'Quando a criança pedir mais tempo pelo aparelho dela, o pedido '
                          'aparece aqui para você aprovar ou negar.',
                    ),
                  ),
                ],
              ),
              TimeRequestsLoaded() => _Requests(
                state: state,
                onApprove: (TimeRequest request) => _approve(context, request),
                onDeny: (TimeRequest request) => _deny(context, request),
              ),
            };
          },
        ),
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
    return PageBody(
      children: <Widget>[
        Text('Aguardando resposta', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (pending.isEmpty)
          const NoticeBanner(tone: Tone.success, message: 'Nenhum pedido aguardando resposta.')
        else
          for (final TimeRequest request in pending) ...<Widget>[
            _PendingRequestCard(
              request: request,
              busy: resolving == request.id,
              enabled: resolving == null,
              onApprove: () => onApprove(request),
              onDeny: () => onDeny(request),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        if (resolved.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text('Respondidos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int index = 0; index < resolved.length; index++) ...<Widget>[
                  if (index > 0) const Divider(height: 1),
                  _ResolvedRequestTile(request: resolved[index]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({
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
    final ThemeData theme = Theme.of(context);
    final int? minutes = request.minutes;
    final String? message = request.message;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.more_time, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        request.childName.isEmpty ? 'Pedido de tempo' : request.childName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        minutes == null
                            ? 'Pediu mais tempo, ${formatRelativeMs(request.createdAt)}'
                            : 'Pediu ${formatMinutes(minutes)}, '
                                  '${formatRelativeMs(request.createdAt)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (message != null && message.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text('"${message.trim()}"', style: theme.textTheme.bodyMedium),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: enabled ? onDeny : null,
                    child: const Text('Negar'),
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

class _ResolvedRequestTile extends StatelessWidget {
  const _ResolvedRequestTile({required this.request});

  final TimeRequest request;

  @override
  Widget build(BuildContext context) {
    final int? granted = request.grantedMinutes;
    final (String label, Tone tone, IconData icon) = switch (request.status) {
      TimeRequestStatus.approved => (
        granted == null ? 'Aprovado' : 'Aprovado: ${formatMinutes(granted)}',
        Tone.success,
        Icons.check_circle_outline,
      ),
      TimeRequestStatus.denied => ('Negado', Tone.danger, Icons.cancel_outlined),
      TimeRequestStatus.expired => ('Expirou sem resposta', Tone.neutral, Icons.timer_off_outlined),
      TimeRequestStatus.pending => ('Aguardando', Tone.info, Icons.hourglass_empty),
    };
    final int? minutes = request.minutes;
    return ListTile(
      title: Text(request.childName.isEmpty ? 'Pedido de tempo' : request.childName),
      subtitle: Text(
        <String>[
          if (minutes != null) 'Pediu ${formatMinutes(minutes)}',
          formatRelativeMs(request.createdAt),
        ].join(' · '),
      ),
      trailing: StatusPill(label: label, tone: tone, icon: icon),
    );
  }
}

/// Folha para escolher quantos minutos conceder ao aprovar um pedido.
class _GrantSheet extends StatefulWidget {
  const _GrantSheet({required this.request});

  final TimeRequest request;

  @override
  State<_GrantSheet> createState() => _GrantSheetState();
}

class _GrantSheetState extends State<_GrantSheet> {
  static const List<int> _options = <int>[15, 30, 45, 60, 90, 120];

  late int _minutes = widget.request.suggestedGrantMinutes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<int> options = <int>{..._options, _minutes}.toList()..sort();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Quanto tempo conceder?', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'O tempo é somado ao limite de hoje e vale só para hoje.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final int option in options)
                ChoiceChip(
                  label: Text(formatMinutes(option)),
                  selected: option == _minutes,
                  onSelected: (_) => setState(() => _minutes = option),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_minutes),
              child: Text('Conceder ${formatMinutes(_minutes)}'),
            ),
          ),
        ],
      ),
    );
  }
}
