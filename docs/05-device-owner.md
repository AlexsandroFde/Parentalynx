# Modo Device Owner: provisionamento, efeitos e remoção

O modo Device Owner (dono do dispositivo, "totalmente gerenciado") é o nível em que o próprio
Android impõe o controle parental: suspende os apps bloqueados, impede a desinstalação e mantém o
bloqueio mesmo se o processo do ParentaLynx morrer. A comparação com os outros níveis está em
`01-capacidades-android.md`.

**Estado de validação.** O provisionamento por `adb` (seção 2) e os efeitos das seções 4 e 6 foram
exercitados em emulador com Android 16 (API 36, imagem AOSP): suspensão dos apps bloqueados e do
bloqueio geral, desinstalação recusada, forçar parada sem efeito, restrições de usuário, DNS
privado e a liberação do modo ao revogar o vínculo. O provisionamento por QR code (seção 3) está
implementado, mas **não foi validado**. Nada foi testado em aparelho físico. O resultado de cada
verificação está em `07-testes.md`.

## 1. Pré-requisitos

- Android 9 ou superior.
- O aparelho **não pode ter nenhuma conta** (Google ou outra) nem usuários ou perfis adicionais no
  momento do provisionamento. Na prática: aparelho recém-restaurado, com a configuração inicial
  concluída sem entrar em conta. As contas podem ser adicionadas depois.
- Não pode existir outro dono do dispositivo nem perfil de trabalho.
- Componente administrador do ParentaLynx: `com.parentalynx.app/.service.AdminReceiver`.

O sistema recusa o provisionamento se houver conta. A mensagem do `adb` nesse caso é
`Not allowed to set the device owner because there are already some accounts on the device`.

## 2. Provisionamento por adb

Indicado para desenvolvimento, testes e instalações feitas por quem tem um computador à mão.

1. Restaure o aparelho de fábrica e conclua a configuração inicial **sem** entrar em conta.
2. Ative as opções do desenvolvedor e a depuração USB.
3. Instale o app:
   ```
   adb install app-release.apk
   ```
4. Torne o ParentaLynx o dono do dispositivo:
   ```
   adb shell dpm set-device-owner com.parentalynx.app/.service.AdminReceiver
   ```
   Resposta esperada (a redação varia com a versão do Android):
   `Success: Device owner set to package com.parentalynx.app/.service.AdminReceiver`.
5. Abra o app, escolha o modo criança e faça a vinculação com o código do responsável.

### 2.1 Comandos opcionais de reforço

Nenhum é obrigatório. Eles poupam passos manuais e fecham caminhos de contorno.

| Comando | Efeito |
| --- | --- |
| `adb shell appops set com.parentalynx.app GET_USAGE_STATS allow` | Concede o "Acesso ao uso" sem passar pelas Configurações. |
| `adb shell pm grant com.parentalynx.app android.permission.POST_NOTIFICATIONS` | Concede as notificações (Android 13 ou superior). |
| `adb shell cmd deviceidle whitelist +com.parentalynx.app` | Isenta o app da otimização de bateria. |
| `adb shell settings put secure enabled_accessibility_services com.parentalynx.app/com.parentalynx.app.service.ParentalAccessibilityService` e `adb shell settings put secure accessibility_enabled 1` | Liga o serviço de acessibilidade (detecção imediata e tela de bloqueio para os poucos pacotes que o sistema não suspende). |
| `adb shell pm grant com.parentalynx.app android.permission.WRITE_SECURE_SETTINGS` | Permite que o app **religue sozinho** o serviço de acessibilidade se ele for desativado. Sem este comando o app só detecta e alerta. |

Sobre `WRITE_SECURE_SETTINGS`: é uma permissão que o Android só concede por `adb` (ou a apps de
sistema). O ParentaLynx a usa em um único ponto, `PermissionChecker.tryRestoreAccessibility`, e
somente para recolocar o próprio serviço na lista de serviços de acessibilidade ativos.

Depois do provisionamento, o responsável pode ligar na política a opção "bloquear depuração USB".
A partir daí o `adb` deixa de funcionar no aparelho. Execute os comandos de reforço antes.

## 3. Provisionamento por QR code

Indicado para quem não tem computador. Disponível a partir do Android 10 neste app (as telas
`ProvisioningModeActivity` e `PolicyComplianceActivity` respondem ao fluxo do sistema).

**Não validado.** Este fluxo está implementado conforme a documentação do Android, mas não foi
exercitado em aparelho.

1. Hospede o APK de produção em um endereço HTTPS acessível pelo aparelho.
2. Calcule o checksum do certificado de assinatura (SHA-256 em Base64 para URL, sem `=`):
   ```
   apksigner verify --print-certs app-release.apk
   ```
   Pegue o valor de `Signer #1 certificate SHA-256 digest` (hexadecimal) e converta:
   ```
   echo "<hexadecimal>" | xxd -r -p | openssl base64 | tr -d '=' | tr '+/' '-_'
   ```
3. Gere um QR code com este JSON:
   ```json
   {
     "android.app.extra.PROVISIONING_DEVICE_ADMIN_COMPONENT_NAME": "com.parentalynx.app/.service.AdminReceiver",
     "android.app.extra.PROVISIONING_DEVICE_ADMIN_PACKAGE_DOWNLOAD_LOCATION": "https://seu-servidor.exemplo/parentalynx.apk",
     "android.app.extra.PROVISIONING_DEVICE_ADMIN_SIGNATURE_CHECKSUM": "<checksum do passo 2>",
     "android.app.extra.PROVISIONING_LEAVE_ALL_SYSTEM_APPS_ENABLED": true,
     "android.app.extra.PROVISIONING_WIFI_SSID": "<rede>",
     "android.app.extra.PROVISIONING_WIFI_PASSWORD": "<senha>",
     "android.app.extra.PROVISIONING_WIFI_SECURITY_TYPE": "WPA"
   }
   ```
   As três chaves de Wi-Fi são opcionais: sem elas o assistente pede a rede. Com
   `LEAVE_ALL_SYSTEM_APPS_ENABLED` os apps de sistema do fabricante continuam instalados.
4. No aparelho recém-restaurado, na primeira tela do assistente de configuração, toque **6 vezes**
   no mesmo ponto da tela. O leitor de QR code abre. Leia o código.
5. O sistema baixa o APK, confere a assinatura, instala e define o ParentaLynx como dono.
6. Abra o app, escolha o modo criança e faça a vinculação.

Observações:
- O checksum é do **certificado**, não do arquivo. Ele não muda entre versões assinadas com a
  mesma chave. O build de produção precisa da chave própria (`android/key.properties`), não da
  chave de debug.
- Alguns fabricantes exigem acesso aos serviços do Google para abrir o leitor de QR code.

## 4. O que muda no aparelho

Com o app como dono do dispositivo e o aparelho vinculado:

| Efeito | Onde no código | Controlado por |
| --- | --- | --- |
| Apps bloqueados ficam suspensos pelo sistema: ícone esmaecido, não abrem, sem notificações | `DeviceOwnerController.syncSuspended` | Regras de apps, limite diário, horários, bloqueio manual |
| Durante um bloqueio geral, todos os apps com ícone que não são essenciais nem exceção ficam suspensos | `EnforcementEngine.syncSuspension` | Idem |
| Ao tocar em um app suspenso, o sistema mostra a mensagem do controle parental | `setShortSupportMessage` | Sempre |
| Desinstalar, forçar parada e limpar dados do ParentaLynx ficam impedidos | `setUninstallBlocked`, `setUserControlDisabledPackages` (Android 11+) | `protection.blockUninstall` |
| Modo de segurança bloqueado | `DISALLOW_SAFE_BOOT` | `protection.blockSafeBoot` |
| Restauração de fábrica pelas Configurações bloqueada | `DISALLOW_FACTORY_RESET` | `protection.blockFactoryReset` |
| Data e hora automáticas e sem alteração manual | `DISALLOW_CONFIG_DATE_TIME`, `setAutoTimeEnabled` | `protection.blockDateTimeChange` |
| Criação de usuários bloqueada | `DISALLOW_ADD_USER` | `protection.blockAddUser` |
| Instalação de fontes desconhecidas bloqueada | `DISALLOW_INSTALL_UNKNOWN_SOURCES` | `protection.blockUnknownSources` (desligado por padrão) |
| Depuração USB bloqueada | `DISALLOW_DEBUGGING_FEATURES` | `protection.blockUsbDebugging` (desligado por padrão) |
| DNS privado do sistema apontado para o resolvedor familiar e sem alteração manual | `setGlobalPrivateDnsModeSpecifiedHost`, `DISALLOW_CONFIG_PRIVATE_DNS` (Android 10+) | `web.safeDns` |

Pacotes que o Android se recusa a suspender (o próprio dono, o launcher ativo, o discador padrão,
instalador e verificador de pacotes e, no emulador testado, as Configurações) continuam cobertos
pela interceptação: a tela de bloqueio do ParentaLynx abre por cima do app. Chamadas de emergência
nunca são bloqueadas.

Ao tocar em um app suspenso, o diálogo é do próprio Android. O título é fixo do sistema ("Blocked
by work policy" em inglês, ou o equivalente no idioma do aparelho) e não pode ser trocado por um
app. O texto abaixo dele é a mensagem do ParentaLynx: "Bloqueado pelo controle parental
ParentaLynx. Fale com o seu responsável."

O conjunto suspenso é recalculado a cada mudança de estado e, por garantia, a cada 30 segundos.
Ele fica gravado no sistema: sobrevive a reinicializações e à morte do processo. O lado inverso
disso é que a liberação (fim do período, reinício da cota, tempo extra) depende de o motor rodar.
Há três caminhos para isso: o alarme de fronteira, a tela ligando e a tarefa periódica.

O DNS privado só é definido com rede disponível, porque o Android testa a conexão com o resolvedor
antes de aceitar. Sem rede, o app tenta de novo na próxima aplicação da política.

## 5. O que este modo não garante

- A restauração de fábrica pelo **modo de recuperação** (botões físicos) continua possível.
- O "Acesso ao uso" pode ser revogado nas Configurações. O bloqueio por suspensão continua
  valendo, mas a contagem de tempo passa para a fonte de acessibilidade ou fica indisponível, e o
  responsável é alertado.
- Não verificado: se o Android concede "Acesso ao uso" automaticamente ao dono do dispositivo (no
  teste em emulador o acesso já tinha sido concedido antes do provisionamento). O app não depende
  disso: confere a permissão e pede ao usuário se faltar. Use o comando da seção 2.1 para não
  depender do passo manual.

## 6. Como remover

Há três caminhos, todos pelo próprio app:

1. **Revogar o vínculo no painel do responsável.** Na próxima sincronização o aparelho recebe
   `device_revoked`, remove suspensões e restrições, **abre mão do modo Device Owner** e apaga os
   dados locais. O app volta a ser um app comum e pode ser desinstalado.
2. **Desvincular no aparelho** (área do responsável, com a senha administrativa ou o código de
   acesso offline). Mesmo efeito do item 1, e funciona sem internet com o código offline.
3. **Sair só do modo Device Owner**, mantendo o vínculo: `DeviceApi.releaseDeviceOwner`, que exige
   autenticação do responsável. O aparelho continua vinculado no modo padrão.

Decisão de projeto: a revogação remota abre mão do modo Device Owner de propósito. Se o app
continuasse dono do dispositivo sem vínculo, não haveria quem se autenticar para liberá-lo e ele
não poderia ser desinstalado. O custo é que voltar ao modo Device Owner exige novo provisionamento
(seções 2 ou 3), ou seja, aparelho sem contas.

Se o servidor deixar de existir, o caminho é o item 2 com o código de acesso offline, que o app do
responsável mostra para cada aparelho. Sem servidor e sem o app do responsável, resta a
restauração de fábrica pelo modo de recuperação.

`adb shell dpm remove-active-admin` **não** remove este app: o comando só vale para apps marcados
como `testOnly`, o que o ParentaLynx não é.

## 7. Roteiro de validação em aparelho ou emulador

Emulador com imagem AOSP (sem conta) aceita o provisionamento por `adb` diretamente.

```
adb install -r app-debug.apk
adb shell dpm set-device-owner com.parentalynx.app/.service.AdminReceiver
adb shell dumpsys device_policy | grep -A3 "Device Owner"
adb shell appops get com.parentalynx.app GET_USAGE_STATS        # ver se o dono recebe o acesso sozinho
```

Depois de vincular e de receber uma política com um app bloqueado:

```
adb shell dumpsys package <pacote-bloqueado> | grep -i suspended  # esperado: suspended=true
adb shell am start -n <pacote-bloqueado>/<atividade>              # esperado: diálogo do sistema com a mensagem do ParentaLynx
adb shell dumpsys device_policy | grep -i -A20 "userRestrictions"  # restrições aplicadas
adb shell settings get global private_dns_specifier                # family.cloudflare-dns.com quando safeDns
adb uninstall com.parentalynx.app                                  # esperado: falha
adb shell am force-stop com.parentalynx.app                        # esperado: sem efeito (Android 11+)
adb reboot                                                         # depois: o app continua suspenso antes de o serviço subir
```

Remoção:

```
# depois de revogar o vínculo no painel e de o aparelho sincronizar
adb shell dumpsys device_policy | grep "Device Owner"              # esperado: nada
adb shell dumpsys package <pacote-bloqueado> | grep -i suspended   # esperado: suspended=false
adb uninstall com.parentalynx.app                                  # esperado: sucesso
```
