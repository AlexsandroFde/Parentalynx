import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../agent/data/child_agent_repository.dart';

/// Abre a folha para pedir mais tempo ao responsavel. Devolve verdadeiro se o pedido foi
/// registrado.
Future<bool> showTimeRequestSheet(BuildContext context, {required String guardianName}) async {
  final bool? sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => _TimeRequestSheet(guardianName: guardianName),
  );
  return sent ?? false;
}

class _TimeRequestSheet extends ConsumerStatefulWidget {
  const _TimeRequestSheet({required this.guardianName});

  final String guardianName;

  @override
  ConsumerState<_TimeRequestSheet> createState() => _TimeRequestSheetState();
}

class _TimeRequestSheetState extends ConsumerState<_TimeRequestSheet> {
  static const List<int> _options = <int>[15, 30, 60];

  final TextEditingController _message = TextEditingController();
  int _minutes = 30;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String text = _message.text.trim();
      await ref
          .read(childAgentRepositoryProvider)
          .submitTimeRequest(minutes: _minutes, message: text.isEmpty ? null : text);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failure.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String guardian = widget.guardianName.isEmpty ? 'o responsável' : widget.guardianName;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Pedir mais tempo', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'O pedido vai para $guardian, que decide se aprova.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Quanto tempo?', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: <ButtonSegment<int>>[
              for (final int option in _options)
                ButtonSegment<int>(value: option, label: Text(formatMinutes(option))),
            ],
            selected: <int>{_minutes},
            onSelectionChanged: _busy
                ? null
                : (Set<int> selection) => setState(() => _minutes = selection.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _message,
            enabled: !_busy,
            maxLength: 140,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Recado (opcional)',
              hintText: 'Por exemplo: falta pouco para terminar a tarefa',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          BusyButton(
            label: 'Enviar pedido',
            icon: Icons.send_rounded,
            busy: _busy,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
