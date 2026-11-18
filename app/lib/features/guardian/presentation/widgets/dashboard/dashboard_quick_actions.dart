import 'package:material_ui/material_ui.dart';

import '../../../../../shared/design_system/design_system.dart';
import '../../../../child_device/domain/entities/child_device.dart';
import '../../../domain/entities/active_commands.dart';
import '../../bloc/dashboard/guardian_dashboard_bloc.dart';

/// Pausar o aparelho e suspender regras, cada acao com a consequencia escrita logo abaixo.
///
/// Pausar e suspender passam por uma confirmacao (com o prazo) antes de serem enviados;
/// retomar e encerrar a suspensao devolvem as regras e sao enviados na hora. O botao tocado
/// mostra o andamento ate o servidor responder.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({
    required this.device,
    required this.commands,
    required this.running,
    required this.onPause,
    required this.onResume,
    required this.onSuspend,
    required this.onEndSuspension,
    super.key,
  });

  final ChildDevice device;
  final ActiveCommands commands;
  final DashboardCommand? running;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSuspend;
  final VoidCallback onEndSuspension;

  bool _is(DashboardCommandKind kind) => running?.kind == kind;

  @override
  Widget build(BuildContext context) {
    final bool idle = running == null;
    final String name = device.displayName;
    return AppSection(
      title: 'Ações rápidas',
      subtitle: 'Valem no aparelho de $name assim que ele receber.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (commands.paused)
            _QuickAction(
              button: AppButton.secondary(
                label: 'Retomar agora',
                icon: AppIcons.resume,
                expand: true,
                busy: _is(DashboardCommandKind.resume),
                onPressed: idle ? onResume : null,
              ),
              consequence: 'Encerra a pausa e libera o aparelho de $name.',
            )
          else
            _QuickAction(
              button: AppButton.secondary(
                label: 'Pausar agora',
                icon: AppIcons.pause,
                expand: true,
                busy: _is(DashboardCommandKind.pause),
                onPressed: idle ? onPause : null,
              ),
              consequence: 'Bloqueia tudo, menos as exceções e as chamadas de emergência.',
            ),
          const SizedBox(height: AppSpacing.lg),
          if (commands.suspended)
            _QuickAction(
              button: AppButton.secondary(
                label: 'Encerrar suspensão',
                icon: AppIcons.lock,
                expand: true,
                busy: _is(DashboardCommandKind.endSuspension),
                onPressed: idle ? onEndSuspension : null,
              ),
              consequence: 'O limite, os horários e os bloqueios voltam a valer.',
            )
          else
            _QuickAction(
              button: AppButton.secondary(
                label: 'Suspender regras',
                icon: AppIcons.unlock,
                expand: true,
                busy: _is(DashboardCommandKind.suspend),
                onPressed: idle ? onSuspend : null,
              ),
              consequence: 'Limite, horários ou bloqueios deixam de valer por um tempo.',
            ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.button, required this.consequence});

  final Widget button;
  final String consequence;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        button,
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(consequence, style: context.text.bodySmall),
        ),
      ],
    );
  }
}
