import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../foundations/app_icons.dart';
import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/spacing.dart';
import '../cards/app_list_group.dart';

/// Uma opcao de escolha: valor, rotulo e icone opcional.
@immutable
class AppChoice<T> {
  const AppChoice({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Opcoes prontas em chips (por exemplo, limites de 1h, 2h e 3h). Atalho para quem configura
/// sempre os mesmos valores, sem esconder a opcao de digitar um valor proprio.
class AppChoiceChips<T> extends StatelessWidget {
  const AppChoiceChips({
    required this.choices,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<AppChoice<T>> choices;

  /// Valor escolhido. Nulo quando nenhuma opcao corresponde ao valor atual.
  final T? selected;

  /// Nulo desabilita as opcoes.
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final AppChoice<T> choice in choices)
          ChoiceChip(
            label: Text(choice.label),
            avatar: choice.icon == null ? null : Icon(choice.icon),
            selected: choice.value == selected,
            showCheckmark: false,
            onSelected: onSelected == null
                ? null
                : (bool _) {
                    HapticFeedback.selectionClick();
                    onSelected!(choice.value);
                  },
          ),
      ],
    );
  }
}

/// Escolha unica entre poucas opcoes lado a lado (de 2 a 4).
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = true,
    super.key,
  });

  final List<AppChoice<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget control = SegmentedButton<T>(
      segments: <ButtonSegment<T>>[
        for (final AppChoice<T> segment in segments)
          ButtonSegment<T>(
            value: segment.value,
            label: Text(segment.label, textAlign: TextAlign.center),
            icon: segment.icon == null ? null : Icon(segment.icon),
          ),
      ],
      selected: <T>{selected},
      showSelectedIcon: false,
      onSelectionChanged: onChanged == null
          ? null
          : (Set<T> values) {
              HapticFeedback.selectionClick();
              onChanged!(values.first);
            },
    );
    return expand ? SizedBox(width: double.infinity, child: control) : control;
  }
}

/// Linha com chave liga/desliga. A linha inteira alterna a chave, e o leitor de tela anuncia
/// o titulo junto com o estado.
class AppSwitchRow extends StatelessWidget {
  const AppSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.tone = Tone.info,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;

  /// Nulo desabilita a chave.
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final Tone tone;

  void _toggle(bool next) {
    HapticFeedback.selectionClick();
    onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      title: title,
      subtitle: subtitle,
      leading: icon == null ? null : AppIconTile(icon: icon!, tone: tone),
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => _toggle(!value),
      showChevron: false,
      trailing: Switch(value: value, onChanged: onChanged == null ? null : _toggle),
    );
  }
}

/// Linha com caixa de selecao (por exemplo, "Guardei a chave em um lugar seguro"). A linha
/// inteira marca e desmarca.
class AppCheckboxRow extends StatelessWidget {
  const AppCheckboxRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;

  /// Nulo desabilita a caixa.
  final ValueChanged<bool>? onChanged;

  void _toggle(bool next) {
    HapticFeedback.selectionClick();
    onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      title: title,
      subtitle: subtitle,
      enabled: onChanged != null,
      showChevron: false,
      onTap: onChanged == null ? null : () => _toggle(!value),
      leading: Checkbox(
        value: value,
        onChanged: onChanged == null ? null : (bool? next) => _toggle(next ?? false),
      ),
    );
  }
}

/// Linha de escolha unica dentro de um grupo (por exemplo, o modo de protecao).
class AppRadioRow<T> extends StatelessWidget {
  const AppRadioRow({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final T value;
  final T? groupValue;

  /// Nulo desabilita a opcao.
  final ValueChanged<T>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bool selected = value == groupValue;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: AppListRow(
        title: title,
        subtitle: subtitle,
        enabled: onChanged != null,
        showChevron: false,
        trailing: trailing,
        onTap: onChanged == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onChanged!(value);
              },
        leading: ExcludeSemantics(
          child: Icon(
            selected ? AppIcons.radioOn : AppIcons.radioOff,
            color: selected ? context.colors.primary : context.colors.outline,
          ),
        ),
      ),
    );
  }
}
