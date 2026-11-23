# Aplicativo ParentaLynx

Aplicativo Android com os dois modos (responsável e criança). A interface é Flutter e o controle
do aparelho é feito por módulos nativos em Kotlin.

A visão geral do projeto está em [../README.md](../README.md) e a arquitetura em
[../docs/02-arquitetura.md](../docs/02-arquitetura.md).

## Estrutura

```
lib/
  main.dart                entradas: main() e browserMain() (navegador gerenciado)
  app/                     raiz de composição: inicialização, injeção (get_it), roteador
  core/                    infraestrutura sem regra de negócio: Result, falhas, rede, JSON,
                           ponte nativa, armazenamento, tempo, segurança, base dos BLoCs
  shared/                  Design System (tokens, temas, componentes) e serviços de interface
  features/<nome>/         uma funcionalidade por pasta
    domain/                entidades, contratos de repositório e serviço, casos de uso
    data/                  DTOs, mapeadores, fontes de dados e repositórios
    presentation/          BLoCs, páginas e widgets
    <nome>_module.dart     registros da funcionalidade no get_it
    <nome>_routes.dart     rotas da funcionalidade
pigeons/                   definição da ponte Dart e Kotlin
android/                   agente nativo, manifesto e recursos
test/                      testes por camada, capturas de tela de referência e regras de arquitetura
```

Funcionalidades: `onboarding`, `user_role`, `authentication`, `device_sync`,
`child_device`, `device_policy`, `device_linking`, `screen_time`, `schedules`,
`app_management`, `blocking`, `activity_reports`, `notifications`, `settings`,
`managed_browser`, `guardian` (casca e início do painel) e `child_mode` (casca e telas do modo
criança). As decisões estão em [../docs/adr/0001-bloc-clean-architecture.md](../docs/adr/0001-bloc-clean-architecture.md).

## Comandos

```bash
flutter pub get
flutter analyze
flutter test                                  # todos os testes
flutter test --update-goldens --tags screenshot   # regenerar as capturas de referência
flutter build apk --debug
flutter build apk --release
```

O endereço do servidor é fixo no código, em `AppConfig.serverUrl`
([lib/app/config/app_config.dart](lib/app/config/app_config.dart)), e o app não oferece a troca.
Enquanto o servidor não está no VPS, ele aponta para `http://10.0.2.2:8080` (o computador visto
do emulador). O build de produção só fala HTTPS. O servidor no VPS está em
[../docs/08-servidor-vps.md](../docs/08-servidor-vps.md).

Testes do agente nativo (JVM), a partir de `android/`:

```bash
./gradlew :app:testDebugUnitTest
```

Depois de alterar `pigeons/native_api.dart`, gere a ponte de novo:

```bash
dart run pigeon --input pigeons/native_api.dart
```

## Convenções

- Interface com o Design System (`lib/shared/design_system/`, importado por
  `design_system.dart`): cores, textos, ícones, espaçamentos e raios vêm dos tokens, e as telas
  usam os componentes do Design System em vez dos do Material. Documentação em
  [../docs/design/design-system.md](../docs/design/design-system.md); as regras são conferidas por
  `test/architecture/design_system_test.dart` e o catálogo visual fica em
  `test/shared/design_system/`.
- O Material Design vem do pacote `material_ui`: importe `package:material_ui/material_ui.dart`,
  não `package:flutter/material.dart`.
- Estado da interface com BLoC (`flutter_bloc`): eventos e estados imutáveis e tipados. Um BLoC
  só chama casos de uso; HTTP, banco, preferências e ponte nativa ficam na camada `data`.
- Repositórios e casos de uso devolvem `Result<T>` com uma `AppFailure` tipada, em vez de lançar
  exceções para a interface.
- Injeção de dependências com `get_it`, registrada em `<nome>_module.dart`. Só `app/` e os
  arquivos de rotas consultam o contêiner; widgets recebem os BLoCs pela árvore. Os testes montam
  um contêiner próprio com dublês (`test/support/test_dependencies.dart`).
- As regras de camadas e de dependência entre funcionalidades são verificadas por
  `test/architecture/architecture_test.dart`.
- Sem `dynamic`. A leitura de JSON passa por `core/json/json_reader.dart`.
- Largura de linha de 100 colunas (`dart format`).
- Em testes de widget, não espere dentro de `testWidgets` por futuros que dependem de E/S real ou
  do cancelamento de assinaturas de stream: use `tester.runAsync`. Pelo mesmo motivo, fechar um
  BLoC que ainda escuta fluxos nunca termina no relógio simulado; o contêiner dos testes é
  descartado sem fechar as instâncias (`TestDependencies.dispose`).
