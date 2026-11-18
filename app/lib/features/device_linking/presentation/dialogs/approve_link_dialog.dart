import 'package:material_ui/material_ui.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/link_request.dart';
import '../../domain/services/link_request_rules.dart';

/// Pede o nome da crianca antes de aprovar o vinculo. Devolve o nome, sem espacos nas pontas,
/// ou nulo quando a pessoa desiste.
Future<String?> showApproveLinkDialog(BuildContext context, LinkRequest request) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => _ApproveLinkDialog(request: request),
  );
}

class _ApproveLinkDialog extends StatefulWidget {
  const _ApproveLinkDialog({required this.request});

  final LinkRequest request;

  @override
  State<_ApproveLinkDialog> createState() => _ApproveLinkDialogState();
}

class _ApproveLinkDialogState extends State<_ApproveLinkDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.request.childName);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String? error = LinkRequestRules.childNameError(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Aprovar vínculo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'De quem é este aparelho? O nome aparece no painel e nos relatórios.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Nome da criança',
              errorText: _error,
              prefixIcon: const Icon(Icons.child_care_outlined),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: _submit,
          child: const Text('Aprovar'),
        ),
      ],
    );
  }
}
