import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';

/// Campo de texto do Design System.
///
/// O rotulo fica sempre visivel acima do texto digitado (nunca some ao comecar a digitar),
/// [isRequired] marca o campo como obrigatorio (com asterisco na tela e "obrigatorio" no
/// leitor de tela) e [hint]/[helper] mostram o formato esperado antes do erro acontecer.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.isRequired = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffix,
    this.inputFormatters,
    this.autofocus = false,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.onTap,
    this.textAlign = TextAlign.start,
    this.style,
    super.key,
  });

  final String label;
  final TextEditingController? controller;

  /// Exemplo do que digitar, mostrado com o campo vazio ("maria@exemplo.com").
  final String? hint;

  /// Regra ou formato esperado, sempre visivel abaixo do campo ("Minimo de 10 caracteres").
  final String? helper;
  final String? errorText;
  final bool isRequired;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final IconData? prefixIcon;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final VoidCallback? onTap;
  final TextAlign textAlign;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final Widget labelWidget = Semantics(
      label: isRequired ? '$label, obrigatório' : label,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            text: label,
            children: <TextSpan>[
              if (isRequired)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: context.colors.danger),
                ),
            ],
          ),
        ),
      ),
    );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      textAlign: textAlign,
      style: style,
      decoration: InputDecoration(
        label: labelWidget,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hint,
        helperText: helper,
        errorText: errorText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffix,
      ),
    );
  }
}
