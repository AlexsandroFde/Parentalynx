import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../auth/domain/guardian_account.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/api_alerts_repository.dart';
import '../domain/alert.dart';
import 'alert_visuals.dart';
import 'alerts_controller.dart';
import 'notification_permission.dart';

/// Preferencias de notificacao: um interruptor por tipo de alerta.
///
/// Desligar um tipo nao apaga os alertas: eles continuam na central, so deixam de notificar.
class NotificationPrefsPage extends ConsumerStatefulWidget {
  const NotificationPrefsPage({super.key});

  @override
  ConsumerState<NotificationPrefsPage> createState() => _NotificationPrefsPageState();
}

class _NotificationPrefsPageState extends ConsumerState<NotificationPrefsPage> {
  /// Tipos com gravacao em andamento, para desabilitar o interruptor correspondente.
  final Set<String> _saving = <String>{};

  Future<void> _toggle(GuardianAccount account, AlertType type, bool enabled) async {
    final Map<String, bool> previous = account.notificationPrefs;
    final Map<String, bool> next = <String, bool>{
      for (final AlertType item in AlertType.values) item.code: account.notifies(item.code),
      type.code: enabled,
    };
    final GuardianSessionController session = ref.read(guardianSessionProvider.notifier);
    // Mostra a mudanca na hora e desfaz se o servidor recusar.
    session.updateAccount(account.copyWith(notificationPrefs: next));
    setState(() => _saving.add(type.code));
    try {
      final Map<String, bool> saved = await ref
          .read(alertsRepositoryProvider)
          .updateNotificationPrefs(next);
      final GuardianAccount? current = ref.read(guardianAccountProvider);
      if (current != null) {
        session.updateAccount(current.copyWith(notificationPrefs: saved));
      }
    } on Object catch (error) {
      final GuardianAccount? current = ref.read(guardianAccountProvider);
      if (current != null) {
        session.updateAccount(current.copyWith(notificationPrefs: previous));
      }
      if (mounted) {
        showFailure(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving.remove(type.code));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final GuardianAccount? account = ref.watch(guardianAccountProvider);
    final bool notificationsOff = ref.watch(notificationsAllowedProvider).value == false;
    return Scaffold(
      appBar: AppBar(title: const Text('Preferências de notificação')),
      body: account == null
          ? const LoadingView()
          : PageBody(
              children: <Widget>[
                if (notificationsOff) ...<Widget>[
                  NoticeBanner(
                    tone: Tone.warning,
                    icon: Icons.notifications_off_outlined,
                    title: 'Notificações desativadas no sistema',
                    message:
                        'As escolhas abaixo só valem depois que você permitir as notificações '
                        'do ParentaLynx.',
                    actionLabel: 'Ativar notificações',
                    onAction: () => requestNotificationsWithExplanation(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const NoticeBanner(message: alertDeliveryNote),
                const SizedBox(height: AppSpacing.lg),
                SectionCard(
                  title: 'Quais avisos notificar',
                  subtitle:
                      'Um tipo desligado continua aparecendo na central de alertas, só não '
                      'gera notificação.',
                  padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
                  child: Column(
                    children: <Widget>[
                      for (final AlertType type in AlertType.values)
                        SwitchListTile(
                          value: account.notifies(type.code),
                          onChanged: _saving.contains(type.code)
                              ? null
                              : (bool value) => _toggle(account, type, value),
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
  }
}
