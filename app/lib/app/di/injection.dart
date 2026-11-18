import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/activity_reports/activity_reports_module.dart';
import '../../features/app_management/app_management_child_module.dart';
import '../../features/app_management/app_management_module.dart';
import '../../features/authentication/authentication_module.dart';
import '../../features/blocking/blocking_child_module.dart';
import '../../features/blocking/blocking_module.dart';
import '../../features/child_device/child_device_module.dart';
import '../../features/child_mode/child_mode_module.dart';
import '../../features/device_linking/device_linking_child_module.dart';
import '../../features/device_linking/device_linking_module.dart';
import '../../features/device_policy/device_policy_module.dart';
import '../../features/device_sync/device_sync_module.dart';
import '../../features/guardian/guardian_module.dart';
import '../../features/managed_browser/managed_browser_module.dart';
import '../../features/notifications/notifications_module.dart';
import '../../features/onboarding/onboarding_module.dart';
import '../../features/schedules/schedules_module.dart';
import '../../features/screen_time/screen_time_child_module.dart';
import '../../features/screen_time/screen_time_module.dart';
import '../../features/server_config/server_config_module.dart';
import '../../features/settings/settings_module.dart';
import '../../features/user_role/domain/entities/user_role.dart';
import '../../features/user_role/user_role_module.dart';
import '../config/app_config.dart';
import 'core_module.dart';

/// Valores lidos antes do primeiro quadro e necessarios para montar as dependencias.
final class AppBootValues {
  const AppBootValues({required this.role, required this.serverUrl, this.sessionToken});

  /// Perfil gravado pelo lado nativo.
  final UserRole role;

  /// Endereco do servidor gravado, ou o padrao do build.
  final String serverUrl;

  /// Token da sessao do responsavel gravado, quando ha.
  final String? sessionToken;
}

/// Raiz de composicao: registra o nucleo e o modulo de cada funcionalidade.
///
/// A ordem segue o grafo de dependencias: primeiro o nucleo e as funcionalidades de base,
/// depois as de dominio e por fim as de composicao (painel do responsavel e modo crianca).
/// Os registros sao preguicosos, entao registrar os dois modos nao cria nada que nao seja usado.
void configureDependencies(
  GetIt di, {
  required AppBootValues values,
  required GlobalKey<NavigatorState> navigatorKey,
}) {
  registerCoreModule(
    di,
    CoreBootValues(serverUrl: values.serverUrl, sessionToken: values.sessionToken),
  );
  registerFeatureModules(
    di,
    initialRole: values.role,
    allowInsecureHttp: AppConfig.allowInsecureHttp,
    navigatorKey: navigatorKey,
  );
}

/// Raiz de composicao do motor do navegador gerenciado (`browserMain`): o nucleo e so o modulo
/// do navegador.
///
/// O navegador nao fala com o servidor nem trata acoes de abertura; isso fica com o motor do
/// app principal. Os registros do nucleo sao preguicosos, entao so a ponte nativa usada pelo
/// navegador chega a ser criada.
void configureBrowserDependencies(GetIt di) {
  registerCoreModule(di, CoreBootValues(serverUrl: AppConfig.defaultServerUrl));
  registerManagedBrowserModule(di);
}

/// Modulos das funcionalidades, sem o nucleo. Os testes de integracao registram o nucleo com
/// dubles e chamam esta funcao.
void registerFeatureModules(
  GetIt di, {
  required UserRole initialRole,
  required bool allowInsecureHttp,
  required GlobalKey<NavigatorState> navigatorKey,
}) {
  // Base.
  registerUserRoleModule(di, initialRole: initialRole);
  registerServerConfigModule(di, allowInsecureHttp: allowInsecureHttp);
  registerAuthenticationModule(di, navigatorKey: navigatorKey);
  registerDeviceSyncModule(di);
  registerChildDeviceModule(di);
  registerDevicePolicyModule(di);

  // Dominio.
  registerOnboardingModule(di);
  registerScreenTimeModule(di);
  registerScreenTimeChildModule(di);
  registerSchedulesModule(di);
  registerAppManagementModule(di);
  registerAppManagementChildModule(di);
  registerBlockingModule(di);
  registerBlockingChildModule(di);
  registerActivityReportsModule(di);
  registerNotificationsModule(di);
  registerDeviceLinkingModule(di);
  registerDeviceLinkingChildModule(di);
  registerSettingsModule(di);
  registerManagedBrowserModule(di);

  // Composicao.
  registerGuardianModule(di);
  registerChildModeModule(di);
}
