import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../foundations/app_icons.dart';
import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/colors.dart';
import '../../tokens/elevation.dart';
import '../../tokens/motion.dart';
import '../../tokens/sizes.dart';
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

/// Escolha unica entre poucas opcoes lado a lado (de 2 a 4): um trilho neutro com a opcao
/// escolhida destacada sobre ele.
///
/// Cada opcao ocupa a altura toda do trilho (48), entao a area de toque e completa mesmo com o
/// destaque visual menor. O leitor de tela anuncia cada opcao como botao, com o estado
/// "selecionado".
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
    final AppColors c = context.colors;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final double radius = context.shapes.control;
    final Widget control = Container(
      decoration: BoxDecoration(
        color: dark ? c.surfaceMuted : c.surfaceStrong,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final AppChoice<T> segment in segments)
              _wrap(
                expand,
                _Segment(
                  label: segment.label,
                  icon: segment.icon,
                  selected: segment.value == selected,
                  radius: radius,
                  thumb: dark ? c.surfaceStrong : c.surface,
                  onTap: onChanged == null
                      ? null
                      : () {
                          if (segment.value == selected) {
                            return;
                          }
                          HapticFeedback.selectionClick();
                          onChanged!(segment.value);
                        },
                ),
              ),
          ],
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: control) : control;
  }

  static Widget _wrap(bool expand, Widget child) => expand ? Expanded(child: child) : child;
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.radius,
    required this.thumb,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final double radius;
  final Color thumb;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color foreground = selected ? c.textPrimary : c.textSecondary;
    final TextStyle? style = context.text.titleSmall?.copyWith(color: foreground);
    // O destaque fica 3 pontos para dentro do trilho; o toque vale na altura toda.
    const double inset = AppSpacing.xxs + 1;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.all(inset),
            child: AnimatedContainer(
              duration: AppMotion.resolve(context, AppMotion.fast),
              curve: AppMotion.standard,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: selected ? thumb : Colors.transparent,
                borderRadius: BorderRadius.circular(radius - inset),
                boxShadow: selected ? AppElevation.raised(c) : AppElevation.none,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: AppSizes.iconSm, color: foreground),
                    const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                  ],
                  Flexible(
                    child: Text(label, textAlign: TextAlign.center, style: style),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
