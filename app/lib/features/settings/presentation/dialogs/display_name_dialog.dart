import 'package:material_ui/material_ui.dart';

import '../../domain/services/account_rules.dart';

/// Pede o nome de exibicao. Devolve o nome digitado, sem espacos nas pontas, ou nulo.
Future<String?> showDisplayNameDialog(BuildContext context, {required String initial}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => _DisplayNameDialog(initial: initial),
  );
}

class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog({required this.initial});

  final String initial;

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String? error = AccountRules.displayNameError(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seu nome'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: 'Nome', errorText: _error),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
