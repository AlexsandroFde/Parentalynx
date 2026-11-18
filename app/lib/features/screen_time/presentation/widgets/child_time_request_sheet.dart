import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/child_time_request.dart';
import '../bloc/time_request_sheet/time_request_sheet_bloc.dart';
import '../texts/child_time_request_texts.dart';

/// Abre a folha para pedir mais tempo ao responsavel. Devolve verdadeiro se o pedido foi
/// registrado.
///
/// [pending] e um pedido ainda sem resposta: a folha avisa antes de a crianca mandar outro.
/// [now] e a hora do agente, para o tempo relativo do aviso. Usa o [TimeRequestSheetBloc] de
/// quem chama, que precisa estar acima na arvore.
Future<bool> showChildTimeRequestSheet(
  BuildContext context, {
  required String guardianName,
  ChildTimeRequest? pending,
  DateTime? now,
}) async {
  final TimeRequestSheetBloc bloc = context.read<TimeRequestSheetBloc>()
    ..add(const TimeRequestSheetOpened());
  final String guardian = guardianName.isEmpty ? 'seu responsável' : guardianName;
  final bool? sent = await showAppSheet<bool>(
    context,
    title: 'Pedir mais tempo',
    subtitle: 'O pedido vai para $guardian, que decide se aprova.',
    builder: (BuildContext context) {
      return BlocProvider<TimeRequestSheetBloc>.value(
        value: bloc,
        child: _TimeRequestForm(guardian: guardian, pending: pending, now: now),
      );
    },
  );
  return sent ?? false;
}

class _TimeRequestForm extends StatefulWidget {
  const _TimeRequestForm({required this.guardian, required this.pending, required this.now});

  final String guardian;
  final ChildTimeRequest? pending;
  final DateTime? now;

  @override
  State<_TimeRequestForm> createState() => _TimeRequestFormState();
}

class _TimeRequestFormState extends State<_TimeRequestForm> {
  final TextEditingController _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _send() {
    FocusScope.of(context).unfocus();
    context.read<TimeRequestSheetBloc>().add(TimeRequestSheetSubmitted(message: _message.text));
  }

  @override
  Widget build(BuildContext context) {
    final ChildTimeRequest? pending = widget.pending;
    return BlocConsumer<TimeRequestSheetBloc, TimeRequestSheetState>(
      listenWhen: (TimeRequestSheetState previous, TimeRequestSheetState current) {
        return previous.status != current.status && current.status == FormStatus.succeeded;
      },
      listener: (BuildContext context, TimeRequestSheetState state) {
        Navigator.of(context).pop(true);
      },
      builder: (BuildContext context, TimeRequestSheetState state) {
        final bool busy = state.status != FormStatus.editing;
        final String? error = state.error;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (pending != null) ...<Widget>[
              AppBanner(
                icon: AppIcons.pending,
                tone: Tone.warning,
                message: pendingRequestNotice(pending, guardian: widget.guardian, now: widget.now),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Semantics(header: true, child: Text('Quanto tempo?', style: context.text.titleSmall)),
            const SizedBox(height: AppSpacing.sm),
            AppSegmentedControl<int>(
              segments: <AppChoice<int>>[
                for (final int option in TimeRequestSheetBloc.minuteOptions)
                  AppChoice<int>(value: option, label: formatMinutes(option)),
              ],
              selected: state.minutes,
              onChanged: busy
                  ? null
                  : (int minutes) {
                      context.read<TimeRequestSheetBloc>().add(TimeRequestMinutesSelected(minutes));
                    },
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _message,
              enabled: !busy,
              label: 'Recado para ${widget.guardian} (opcional)',
              hint: 'Ex.: falta pouco para terminar a tarefa',
              maxLength: 140,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              AppBanner(
                tone: Tone.danger,
                title: 'O pedido não foi enviado',
                message: error,
                liveRegion: true,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: 'Enviar pedido',
              icon: AppIcons.send,
              busy: busy,
              expand: true,
              onPressed: _send,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sem internet, o pedido fica guardado e vai assim que o aparelho se conectar.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ],
        );
      },
    );
  }
}
