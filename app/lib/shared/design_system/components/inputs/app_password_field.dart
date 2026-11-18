import 'package:material_ui/material_ui.dart';

import '../../foundations/app_icons.dart';
import 'app_text_field.dart';

/// Campo de senha com botao para mostrar e ocultar o texto (a pessoa confere o que digitou
/// em vez de memorizar).
///
/// O botao de mostrar fica fora da ordem do teclado: a acao "proximo" vai direto para o
/// campo seguinte, sem parar no botao (que continua acessivel pelo toque e pelo leitor de tela).
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    required this.controller,
    this.label = 'Senha administrativa',
    this.hint,
    this.errorText,
    this.helper,
    this.isRequired = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
    this.autofillHints = const <String>[AutofillHints.password],
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final String? errorText;
  final String? helper;
  final bool isRequired;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final bool autofocus;
  final bool enabled;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscured = true;
  final FocusNode _toggleFocus = FocusNode(skipTraversal: true);

  @override
  void dispose() {
    _toggleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      label: widget.label,
      hint: widget.hint,
      helper: widget.helper,
      errorText: widget.errorText,
      isRequired: widget.isRequired,
      obscureText: _obscured,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      suffix: IconButton(
        focusNode: _toggleFocus,
        tooltip: _obscured ? 'Mostrar senha' : 'Ocultar senha',
        icon: Icon(_obscured ? AppIcons.show : AppIcons.hide),
        onPressed: () => setState(() => _obscured = !_obscured),
      ),
    );
  }
}
