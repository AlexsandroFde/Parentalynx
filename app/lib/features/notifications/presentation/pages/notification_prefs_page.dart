import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../domain/entities/alert_type.dart';
import '../../domain/entities/notification_preferences.dart';
import '../bloc/notification_permission/notification_permission_bloc.dart';
import '../bloc/notification_prefs/notification_prefs_bloc.dart';
import '../texts/notification_texts.dart';
import '../widgets/alert_icon.dart';
import '../widgets/notification_permission_prompt.dart';

/// Preferencias de notificacao: um interruptor por tipo de alerta.
///
/// Desligar um tipo nao apaga os alertas: eles continuam na central, so deixam de notificar.
/// Espera um [NotificationPrefsBloc] acima na arvore.
class NotificationPrefsPage extends StatelessWidget {
  const NotificationPrefsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool notificationsOff = context.select<NotificationPermissionBloc, bool>(
      (NotificationPermissionBloc bloc) => bloc.state.isDenied,
    );
    return BlocConsumer<NotificationPrefsBloc, NotificationPrefsState>(
      listenWhen: (NotificationPrefsState previous, NotificationPrefsState current) {
        return previous.action != current.action;
      },
      listener: (BuildContext context, NotificationPrefsState state) {
        if (state.action case ActionFailed(:final failure)) {
          showFailure(context, failure);
        }
      },
      builder: (BuildContext context, NotificationPrefsState state) {
        final NotificationPreferences? preferences = state.preferences;
        return Scaffold(
          appBar: AppBar(title: const Text('Preferências de notificação')),
          body: preferences == null
              ? const LoadingView()
              : PageBody(
                  children: <Widget>[
                    if (notificationsOff) ...<Widget>[
                      NoticeBanner(
                        tone: Tone.warning,
                        icon: Icons.notifications_off_outlined,
                        title: 'Notificações desativadas no sistema',
                        message:
                            'As escolhas abaixo só valem depois que você permitir as '
                            'notificações do ParentaLynx.',
                        actionLabel: 'Ativar notificações',
                        onAction: () => requestNotificationsWithExplanation(context),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    const NoticeBanner(message: alertDeliveryNote),
                    const SizedBox(height: AppSpacing.lg),
                    SectionCard(
                      title: 'Quais avisos notificar',
                      subtitle:
                          'Um tipo desligado continua aparecendo na central de alertas, só '
                          'não gera notificação.',
                      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
                      child: Column(
                        children: <Widget>[
                          for (final AlertType type in AlertType.values)
                            SwitchListTile(
                              value: preferences.notifies(type),
                              onChanged: state.saving.contains(type)
                                  ? null
                                  : (bool value) => context.read<NotificationPrefsBloc>().add(
                                      NotificationPreferenceToggled(type, enabled: value),
                                    ),
                              secondary: AlertIcon(type: type.code, size: 36),
                              title: Text(type.label),
                              subtitle: Text(type.description),
                              isThreeLine: type.description.length > 44,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
