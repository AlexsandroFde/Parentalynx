import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../bloc/time_request_sheet/time_request_sheet_bloc.dart';

/// Abre a folha para pedir mais tempo ao responsavel. Devolve verdadeiro se o pedido foi
/// registrado.
///
/// Usa o [TimeRequestSheetBloc] de quem chama, que precisa estar acima na arvore.
Future<bool> showChildTimeRequestSheet(BuildContext context, {required String guardianName}) async {
  final TimeRequestSheetBloc bloc = context.read<TimeRequestSheetBloc>()
    ..add(const TimeRequestSheetOpened());
  final bool? sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) {
      return BlocProvider<TimeRequestSheetBloc>.value(
        value: bloc,
        child: _TimeRequestSheet(guardianName: guardianName),
      );
    },
  );
  return sent ?? false;
}

class _TimeRequestSheet extends StatefulWidget {
  const _TimeRequestSheet({required this.guardianName});

  final String guardianName;

  @override
  State<_TimeRequestSheet> createState() => _TimeRequestSheetState();
}

class _TimeRequestSheetState extends State<_TimeRequestSheet> {
  final TextEditingController _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _send() {
    context.read<TimeRequestSheetBloc>().add(TimeRequestSheetSubmitted(message: _message.text));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String guardian = widget.guardianName.isEmpty ? 'o responsável' : widget.guardianName;
    return BlocConsumer<TimeRequestSheetBloc, TimeRequestSheetState>(
      listenWhen: (TimeRequestSheetState previous, TimeRequestSheetState current) {
        return previous.status != current.status && current.status == FormStatus.succeeded;
      },
      listener: (BuildContext context, TimeRequestSheetState state) {
        Navigator.of(context).pop(true);
      },
      builder: (BuildContext context, TimeRequestSheetState state) {
        final bool busy = state.status != FormStatus.editing;
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Quanto tempo?', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: <ButtonSegment<int>>[
                  for (final int option in TimeRequestSheetBloc.minuteOptions)
                    ButtonSegment<int>(value: option, label: Text(formatMinutes(option))),
                ],
                selected: <int>{state.minutes},
                onSelectionChanged: busy
                    ? null
                    : (Set<int> selection) => context.read<TimeRequestSheetBloc>().add(
                        TimeRequestMinutesSelected(selection.first),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _message,
                enabled: !busy,
                maxLength: 140,
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Recado (opcional)',
                  hintText: 'Por exemplo: falta pouco para terminar a tarefa',
                  errorText: state.error,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              BusyButton(
                label: 'Enviar pedido',
                icon: Icons.send_rounded,
                busy: busy,
                onPressed: _send,
              ),
            ],
          ),
        );
      },
    );
  }
}
