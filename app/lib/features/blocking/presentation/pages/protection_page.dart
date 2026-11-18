import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/widgets/rule_editor_scaffold.dart';
import '../../domain/entities/system_lock.dart';
import '../bloc/protection/protection_bloc.dart';
import '../texts/blocking_texts.dart';

const List<HelpTopic> _protectionHelp = <HelpTopic>[
  HelpTopic(
    title: 'O que são os níveis de proteção?',
    body:
        'Padrão: o controle funciona com permissões do Android que a criança consegue desligar, '
        'e você é avisado quando isso acontece. Padrão com administrador: desinstalar exige '
        'desligar o administrador antes, o que também gera alerta. Dispositivo gerenciado: o '
        'próprio Android aplica os bloqueios e as travas do sistema.',
  ),
  HelpTopic(
    title: 'Como ter o modo dispositivo gerenciado?',
    body:
        'O aparelho precisa ser configurado assim durante a instalação, seguindo o guia do '
        'ParentaLynx. Não dá para ligar esse modo pelo app.',
  ),
  HelpTopic(
    title: 'O que é bloquear se a proteção for desativada?',
    body:
        'Se uma permissão essencial for desligada no aparelho e ainda houver como bloquear, '
        'tudo o que não for exceção fica bloqueado até a permissão voltar. Desligado, você só '
        'recebe o alerta.',
  ),
];

String _lockTitle(SystemLock lock) {
  return switch (lock) {
    SystemLock.uninstall => 'Impedir a desinstalação do ParentaLynx',
    SystemLock.safeBoot => 'Impedir o modo de segurança',
    SystemLock.factoryReset => 'Impedir a restauração de fábrica pelas Configurações',
    SystemLock.dateTimeChange => 'Impedir a alteração de data e hora',
    SystemLock.addUser => 'Impedir a criação de outros usuários',
    SystemLock.unknownSources => 'Impedir a instalação de fontes desconhecidas',
    SystemLock.usbDebugging => 'Impedir a depuração USB',
  };
}

IconData _lockIcon(SystemLock lock) {
  return switch (lock) {
    SystemLock.uninstall => AppIcons.delete,
    SystemLock.safeBoot => AppIcons.security,
    SystemLock.factoryReset => AppIcons.reset,
    SystemLock.dateTimeChange => AppIcons.clock,
    SystemLock.addUser => AppIcons.personAdd,
    SystemLock.unknownSources => AppIcons.install,
    SystemLock.usbDebugging => AppIcons.admin,
  };
}

({Tone tone, IconData icon}) _modeStyle(DeviceManagementMode mode) {
  return switch (mode) {
    DeviceManagementMode.deviceOwner => (tone: Tone.success, icon: AppIcons.protectionGood),
    DeviceManagementMode.deviceAdmin => (tone: Tone.info, icon: AppIcons.protection),
    DeviceManagementMode.standard => (tone: Tone.neutral, icon: AppIcons.protectionWeak),
  };
}

/// Protecao contra adulteracao e travas do modo dispositivo gerenciado (Device Owner).
///
/// Espera um [ProtectionBloc] acima na arvore, ja iniciado para [device].
class ProtectionPage extends StatelessWidget {
  const ProtectionPage({required this.device, super.key});

  final ChildDevice device;

  Future<void> _showLocks(BuildContext context) {
    return showAppSheet<void>(
      context,
      title: 'Travas do sistema',
      subtitle: 'Disponíveis só quando o aparelho é um dispositivo gerenciado.',
      builder: (BuildContext context) {
        return AppListGroup(
          children: <Widget>[
            for (final SystemLock lock in SystemLock.values)
              AppListRow(
                leading: AppIconTile(icon: _lockIcon(lock), tone: Tone.neutral),
                title: _lockTitle(lock),
                titleStyle: context.text.bodyLarge,
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProtectionBloc bloc = context.read<ProtectionBloc>();
    final DeviceManagementMode mode = device.managementMode;
    final bool owner = SystemLock.availableIn(mode);
    final String name = device.displayName;
    final ({List<String> guaranteed, List<String> notGuaranteed}) guarantees = guaranteesOf(mode);
    final ({Tone tone, IconData icon}) style = _modeStyle(mode);
    return RuleEditorScaffold<ProtectionBloc, ProtectionPolicy>(
      title: 'Proteção',
      description: 'O que acontece se alguém tentar desativar o controle no celular de $name.',
      device: device,
      helpTopics: _protectionHelp,
      onSave: () => bloc.add(const ProtectionSaveRequested()),
      onDiscard: () => bloc.add(const ProtectionDiscardRequested()),
      onRetry: () => bloc.add(ProtectionStarted(device.id)),
      onRestoreRejected: () => bloc.add(const ProtectionRejectedChangesRestored()),
      children: (BuildContext context, ProtectionPolicy protection) {
        return <Widget>[
          AppSection(
            title: 'Nível de proteção deste aparelho',
            child: AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  StatusBadge(label: mode.label, tone: style.tone, icon: style.icon),
                  const SizedBox(height: AppSpacing.md),
                  for (final String item in guarantees.guaranteed)
                    BulletLine(text: item, icon: AppIcons.check, tone: Tone.success),
                  for (final String item in guarantees.notGuaranteed)
                    BulletLine(text: item, icon: AppIcons.attention, tone: Tone.warning),
                ],
              ),
            ),
          ),
          const SectionGap(),
          AppSection(
            title: 'Se a proteção for desativada',
            child: AppListGroup(
              footer: 'Você sempre recebe um alerta quando uma permissão essencial é desligada.',
              children: <Widget>[
                AppSwitchRow(
                  icon: AppIcons.lock,
                  title: 'Bloquear se a proteção for desativada',
                  subtitle: protection.lockOnTamper
                      ? 'Tudo o que não for exceção fica bloqueado até a permissão voltar.'
                      : 'Desligado: você só recebe o alerta.',
                  value: protection.lockOnTamper,
                  onChanged: (bool value) => bloc.add(ProtectionLockOnTamperChanged(value)),
                ),
              ],
            ),
          ),
          const SectionGap(),
          AppSection(
            title: 'Travas do sistema',
            subtitle: owner
                ? 'Aplicadas pelo próprio Android neste aparelho.'
                : 'Disponíveis só no modo dispositivo gerenciado.',
            child: owner
                ? AppListGroup(
                    children: <Widget>[
                      for (final SystemLock lock in SystemLock.values)
                        AppSwitchRow(
                          icon: _lockIcon(lock),
                          title: _lockTitle(lock),
                          value: lock.valueIn(protection),
                          onChanged: (bool value) {
                            bloc.add(ProtectionSystemLockChanged(lock: lock, enabled: value));
                          },
                        ),
                    ],
                  )
                : AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Em uma instalação comum o Android não deixa um app impedir a própria '
                          'desinstalação nem travar as configurações. Para usar estas travas, o '
                          'aparelho precisa ser configurado como dispositivo gerenciado.',
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppButton.tertiary(
                          label: 'Ver o que as travas fazem',
                          icon: AppIcons.list,
                          size: AppButtonSize.compact,
                          onPressed: () => _showLocks(context),
                        ),
                      ],
                    ),
                  ),
          ),
        ];
      },
    );
  }
}
