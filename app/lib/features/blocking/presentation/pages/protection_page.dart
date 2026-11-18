import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/widgets/rule_editor_scaffold.dart';
import '../../domain/entities/system_lock.dart';
import '../bloc/protection/protection_bloc.dart';
import '../texts/blocking_texts.dart';

/// Protecao contra adulteracao e travas do modo dispositivo gerenciado (Device Owner).
///
/// Espera um [ProtectionBloc] acima na arvore, ja iniciado para [device].
class ProtectionPage extends StatelessWidget {
  const ProtectionPage({required this.device, super.key});

  final ChildDevice device;

  @override
  Widget build(BuildContext context) {
    final ProtectionBloc bloc = context.read<ProtectionBloc>();
    final DeviceManagementMode mode = device.managementMode;
    final bool owner = SystemLock.availableIn(mode);
    return RuleEditorScaffold<ProtectionBloc, ProtectionPolicy>(
      title: 'Proteção',
      device: device,
      onSave: () => bloc.add(const ProtectionSaveRequested()),
      onDiscard: () => bloc.add(const ProtectionDiscardRequested()),
      onRetry: () => bloc.add(ProtectionStarted(device.id)),
      children: (BuildContext context, ProtectionPolicy protection) {
        ValueChanged<bool>? ownerOnly(SystemLock lock) {
          return owner
              ? (bool value) => bloc.add(ProtectionSystemLockChanged(lock: lock, enabled: value))
              : null;
        }

        return <Widget>[
          SectionCard(
            title: 'Modo deste aparelho: ${mode.label}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final String item in guaranteesOf(mode).guaranteed)
                  _Bullet(icon: Icons.check_circle_outline, tone: Tone.success, text: item),
                for (final String item in guaranteesOf(mode).notGuaranteed)
                  _Bullet(icon: Icons.report_gmailerrorred, tone: Tone.warning, text: item),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchCard(
            icon: Icons.gpp_maybe_outlined,
            title: 'Bloquear se a proteção for desativada',
            subtitle:
                'Se uma permissão essencial for revogada no aparelho e ainda houver como '
                'bloquear, tudo que não for exceção fica bloqueado. Desligado, você só recebe '
                'o alerta.',
            value: protection.lockOnTamper,
            onChanged: (bool value) => bloc.add(ProtectionLockOnTamperChanged(value)),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Travas do sistema',
            subtitle: owner
                ? 'Aplicadas pelo próprio Android neste aparelho.'
                : 'Disponíveis só no modo dispositivo gerenciado.',
            child: Column(
              children: <Widget>[
                if (!owner)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: NoticeBanner(
                      icon: Icons.info_outline,
                      message:
                          'Em uma instalação comum o Android não permite que um aplicativo '
                          'impeça a própria desinstalação nem trave as configurações. Para '
                          'usar estas travas, o aparelho precisa ser provisionado como '
                          'dispositivo gerenciado (veja a documentação de instalação).',
                    ),
                  ),
                SwitchRow(
                  title: 'Impedir a desinstalação do ParentaLynx',
                  value: protection.blockUninstall,
                  onChanged: ownerOnly(SystemLock.uninstall),
                ),
                SwitchRow(
                  title: 'Impedir o modo de segurança',
                  value: protection.blockSafeBoot,
                  onChanged: ownerOnly(SystemLock.safeBoot),
                ),
                SwitchRow(
                  title: 'Impedir a restauração de fábrica pelas Configurações',
                  value: protection.blockFactoryReset,
                  onChanged: ownerOnly(SystemLock.factoryReset),
                ),
                SwitchRow(
                  title: 'Impedir a alteração de data e hora',
                  value: protection.blockDateTimeChange,
                  onChanged: ownerOnly(SystemLock.dateTimeChange),
                ),
                SwitchRow(
                  title: 'Impedir a criação de outros usuários',
                  value: protection.blockAddUser,
                  onChanged: ownerOnly(SystemLock.addUser),
                ),
                SwitchRow(
                  title: 'Impedir a instalação de fontes desconhecidas',
                  value: protection.blockUnknownSources,
                  onChanged: ownerOnly(SystemLock.unknownSources),
                ),
                SwitchRow(
                  title: 'Impedir a depuração USB',
                  value: protection.blockUsbDebugging,
                  onChanged: ownerOnly(SystemLock.usbDebugging),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.tone, required this.text});

  final IconData icon;
  final Tone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: tone.foreground(context)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
