# Instalação

Este guia cobre o servidor, a compilação do aplicativo Android e a primeira configuração nos
aparelhos do responsável e da criança.

## 1. Visão geral

São três peças:

1. **Servidor** (`backend/`): um processo Node com um arquivo de banco SQLite. Os dois aparelhos
   precisam alcançá-lo pela internet (ou pela rede local, em testes).
2. **Aplicativo Android** (`app/`): o mesmo APK é instalado no aparelho do responsável e no da
   criança. O papel de cada aparelho é escolhido na primeira abertura.
3. **Modo de instalação no aparelho da criança**: padrão (instalação comum com permissões) ou
   Device Owner (bloqueio imposto pelo sistema). A diferença está em
   `01-capacidades-android.md`. O provisionamento do modo Device Owner está em
   `05-device-owner.md`.

## 2. Servidor

Requisito: Node.js 24.7 ou superior. Detalhes completos em `backend/README.md`.

### 2.1 Teste local

```bash
cd backend
npm install
npm start
```

O servidor sobe em `http://localhost:8080`. Sem a variável `DATA_ENCRYPTION_KEY`, o modo de
desenvolvimento gera uma chave ao lado do banco e avisa no console.

Conferir: `curl http://localhost:8080/health`.

### 2.2 Produção com HTTPS

O build de produção do aplicativo só aceita endereços `https://`. O `docker-compose.yml` sobe a
API e um proxy Caddy que obtém o certificado sozinho.

**Em um VPS Ubuntu ou Debian**, um script faz tudo a partir do seu computador (instala o Docker,
cria o `.env` com a chave, sobe os contêineres e agenda o backup):

```bash
bash backend/deploy/publicar.sh root@IP_DO_VPS api.exemplo.com.br
```

O passo a passo completo, com DNS, SSH, atualização e backups, está em
[08-servidor-vps.md](08-servidor-vps.md).

**Em outro servidor com Docker**, à mão:

1. Aponte o DNS de um domínio para o servidor e libere as portas 80 e 443.
2. Em `backend/`, copie `.env.example` para `.env` e preencha:
   - `DOMAIN`: o domínio público, por exemplo `controle.exemplo.com.br`.
   - `DATA_ENCRYPTION_KEY`: gere com
     `node -e "console.log(require('node:crypto').randomBytes(32).toString('base64'))"`.
3. `docker compose up -d --build`
4. Confira: `curl https://SEU_DOMINIO/health`.

Guarde a `DATA_ENCRYPTION_KEY` fora do servidor. Sem ela, os campos cifrados do banco não podem
ser lidos. O backup do banco está descrito em `backend/README.md`.

> Os arquivos Docker foram executados localmente (API e Caddy com certificado interno para
> `localhost`). A emissão de certificado pela Let's Encrypt depende de um domínio público e não
> foi testada. Detalhes em [08-servidor-vps.md](08-servidor-vps.md), "O que foi testado".

## 3. Compilar o aplicativo

Requisitos: Flutter 3.47 ou superior, Android SDK com a plataforma 36 e JDK 17 ou superior (o JDK
que acompanha o Android Studio serve).

```bash
cd app
flutter pub get
```

### 3.1 APK de desenvolvimento

```bash
flutter build apk --debug
```

Saída: `app/build/app/outputs/flutter-apk/app-debug.apk`.

O endereço do servidor é fixo no código, em `AppConfig.serverUrl`
(`app/lib/app/config/app_config.dart`). O app não oferece a troca, então nada é digitado nos
aparelhos. Enquanto o servidor não está no VPS, o valor é `http://10.0.2.2:8080`, que é o
computador visto de dentro do emulador Android. Com o servidor no ar, troque pelo domínio
(`https://api.exemplo.com.br`) e compile de novo.

O APK de depuração aceita HTTP sem TLS, para testes em rede local. Para testar um aparelho
físico contra o computador, troque o valor temporariamente pelo IP do computador
(`http://192.168.0.10:8080`, por exemplo).

### 3.2 APK de produção

1. Crie a chave de assinatura (uma única vez) e guarde-a em local seguro. Quem perde a chave não
   consegue publicar atualizações do mesmo app.

   ```bash
   keytool -genkeypair -v -keystore parentalynx-release.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias parentalynx
   ```

2. Crie o arquivo `app/android/key.properties` (ele não é versionado):

   ```properties
   storeFile=../parentalynx-release.jks
   storePassword=SENHA_DO_ARQUIVO
   keyAlias=parentalynx
   keyPassword=SENHA_DA_CHAVE
   ```

   `storeFile` é relativo à pasta `app/android`. No exemplo, o arquivo `.jks` fica em `app/`.

3. Confira se `AppConfig.serverUrl` tem o endereço `https://` do servidor. O build de produção
   só fala HTTPS: com o valor de testes (`http://10.0.2.2:8080`) o app não conecta.

4. Compile:

   ```bash
   flutter build apk --release
   ```

   Saída: `app/build/app/outputs/flutter-apk/app-release.apk`.

Sem o `key.properties`, o build de produção é assinado com a chave de depuração. Ele serve para
testar, mas não deve ser distribuído.

Para publicar na loja, gere o pacote com `flutter build appbundle --release` e veja as exigências
do Google Play na seção 7.

### 3.3 Trocar o identificador do aplicativo

O identificador é `com.parentalynx.app`. Para trocá-lo, altere `namespace` e `applicationId` em
`app/android/app/build.gradle.kts`, mova os arquivos Kotlin para a pasta do novo pacote, ajuste o
`package` deles e o `kotlinOptions` em `app/pigeons/native_api.dart`, e gere a ponte de novo com
`dart run pigeon --input pigeons/native_api.dart`. O pacote virtual do navegador gerenciado
(`com.parentalynx.app.browser`) aparece em `AppConfig.browserPackage` e no agente nativo.

## 4. Instalar nos aparelhos

Com o aparelho conectado por USB e a depuração ativada:

```bash
adb install -r app/build/app/outputs/flutter-apk/app-release.apk
```

Ou copie o APK para o aparelho e abra-o, permitindo a instalação por essa fonte quando o Android
perguntar.

**Android 13 ou superior, instalação por fora da loja:** o sistema bloqueia a ativação do serviço
de acessibilidade até o usuário liberar as "configurações restritas". No aparelho da criança, abra
Configurações, Apps, ParentaLynx, toque no menu de três pontos e escolha "Permitir configurações
restritas". O assistente de permissões do app mostra esse aviso quando necessário.

## 5. Primeira configuração

### 5.1 Aparelho do responsável

1. Abra o app e escolha **Sou o responsável**.
2. **Criar conta**: nome, e-mail (serve só de identificador de login) e uma senha administrativa
   forte (10 caracteres ou mais, com pelo menos três tipos de caractere).
3. Guarde a **chave de recuperação**. Ela aparece uma única vez e é o único meio de recuperar o
   acesso se a senha for esquecida.
4. Na aba Início, toque em **Vincular aparelho** e em **Gerar código**. O código vale 15 minutos
   e só pode ser usado uma vez.

Um segundo responsável entra com o mesmo e-mail e a mesma senha no aparelho dele, em "Já tenho
conta".

### 5.2 Aparelho da criança

1. Abra o app e escolha **Este é o aparelho da criança**.
2. Digite o código mostrado no aparelho do responsável e toque em **Vincular**.
3. O aparelho mostra um **número de confirmação**. Confira se o mesmo número aparece no aparelho
   do responsável e aprove lá, informando o nome da criança.
4. Leia com a criança a tela que explica o que o app controla, o que o responsável vê e o que não
   é coletado.
5. Conceda as permissões, na ordem pedida pelo assistente:
   - **Acesso ao uso** (obrigatória): contagem do tempo.
   - **Acessibilidade** (obrigatória no modo padrão): perceber qual app está aberto e fechar os
     bloqueados. O serviço não lê o conteúdo das telas.
   - **Notificações** (obrigatória): aviso permanente de controle ativo e avisos de pouco tempo.
   - **Bateria sem restrição** (recomendada): impede o sistema de encerrar o controle.
   - **Sobrepor a outros apps** (recomendada): camada de reserva para a tela de bloqueio.
   - **Administrador do dispositivo** (opcional): dificulta a desinstalação e avisa o responsável.
6. Em aparelhos Xiaomi, Redmi, POCO, OPPO, realme e vivo, ative também o **início automático** do
   ParentaLynx. O assistente tenta abrir a tela certa.

A partir daí as regras definidas pelo responsável valem no aparelho, com ou sem internet.

### 5.3 Definir as regras

No aparelho do responsável, aba **Regras**: limite diário (horas e minutos), horários permitidos,
períodos de bloqueio, estado de cada aplicativo (permitido, bloqueado ou exceção), navegação na
internet e proteção. Cada alteração é enviada ao aparelho da criança, e a tela mostra quando ele
confirma a aplicação.

## 6. Atualizar e remover

- **Atualizar:** instale o novo APK por cima (`adb install -r`). O controle volta sozinho depois
  da atualização.
- **Remover do aparelho da criança:** primeiro desvincule, pelo painel do responsável (Mais,
  Aparelhos vinculados, Desvincular) ou no próprio aparelho (Área do responsável, com a senha
  administrativa ou o código de acesso offline). Depois desinstale normalmente. No modo Device
  Owner a desinstalação só é possível depois de desvincular.
- **Sem acesso ao servidor:** use o código de acesso offline, mostrado no app do responsável na
  tela do aparelho, para entrar na Área do responsável do aparelho da criança e desvincular.

## 7. Publicação no Google Play

O aplicativo declara permissões que a loja trata como sensíveis. Antes de publicar:

- **Serviço de acessibilidade:** preencher a declaração de uso e manter a divulgação destacada que
  o app já mostra antes de pedir a permissão.
- **`QUERY_ALL_PACKAGES`:** justificar pela função central (listar os apps para o responsável).
- **`PACKAGE_USAGE_STATS`, `SYSTEM_ALERT_WINDOW`, isenção de otimização de bateria e serviço em
  primeiro plano do tipo `specialUse`:** justificar no formulário de permissões.
- **Política para famílias e dados de menores:** publicar a política de privacidade (base em
  `06-privacidade-lgpd.md`).

Nada disso foi submetido à loja neste projeto.

## 8. Problemas comuns

| Sintoma | Causa provável e solução |
| --- | --- |
| O app não consegue falar com o servidor | Servidor fora do ar, `AppConfig.serverUrl` errado ou, no build de produção, endereço sem `https://`. Abra `ENDERECO/health` no navegador do celular. |
| No emulador, o app não acha o servidor local | `AppConfig.serverUrl` precisa ser `http://10.0.2.2:8080`, não `localhost`. |
| A opção de acessibilidade aparece desabilitada | Android 13 ou superior: libere as "configurações restritas" (seção 4). |
| O controle para depois de um tempo com a tela apagada | Economia de bateria do fabricante. Conceda "bateria sem restrição" e o início automático. |
| O painel mostra "proteção degradada" | Alguma permissão foi desligada no aparelho da criança. Abra a Área do responsável e refaça as permissões. |
| "Aguardando o aparelho confirmar" não muda | O aparelho da criança está sem internet. As regras novas são aplicadas quando ele sincronizar. |
| Código de vinculação recusado | Vencido (15 minutos) ou já usado. Gere outro. |
