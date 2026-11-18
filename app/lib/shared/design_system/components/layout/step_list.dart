import 'package:material_ui/material_ui.dart';

import '../../foundations/app_icons.dart';
import '../../foundations/ds_context.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';

/// Lista numerada de passos ("1. Crie a conta", "2. Gere o codigo"...). Mostra o caminho
/// inteiro antes de comecar e, com [current], em que passo a pessoa esta.
class StepList extends StatelessWidget {
  const StepList({required this.steps, this.current, super.key});

  final List<String> steps;

  /// Indice do passo atual (comeca em 0). Os anteriores aparecem como concluidos.
  final int? current;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : AppSpacing.md),
            child: _Step(
              number: i + 1,
              total: steps.length,
              text: steps[i],
              state: current == null
                  ? _StepState.upcoming
                  : i < current!
                  ? _StepState.done
                  : i == current
                  ? _StepState.current
                  : _StepState.upcoming,
            ),
          ),
      ],
    );
  }
}

enum _StepState { done, current, upcoming }

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.total, required this.text, required this.state});

  final int number;
  final int total;
  final String text;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final bool active = state != _StepState.upcoming;
    final String status = switch (state) {
      _StepState.done => ', concluído',
      _StepState.current => ', passo atual',
      _StepState.upcoming => '',
    };
    return MergeSemantics(
      child: Semantics(
        label: 'Passo $number de $total$status',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: Container(
                width: AppSizes.iconXl,
                height: AppSizes.iconXl,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? context.colors.primary : context.colors.surfaceMuted,
                ),
                child: state == _StepState.done
                    ? Icon(AppIcons.check, size: AppSizes.iconSm, color: context.colors.onPrimary)
                    : Text(
                        '$number',
                        style: context.text.labelLarge?.copyWith(
                          color: active ? context.colors.onPrimary : context.colors.textPrimary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(text, style: context.text.bodyLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
