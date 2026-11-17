# Aplicativo ParentaLynx

Aplicativo Android com os dois modos (responsável e criança). A interface é Flutter e o controle
do aparelho é feito por módulos nativos em Kotlin.

A visão geral do projeto está em [../README.md](../README.md) e a arquitetura em
[../docs/02-arquitetura.md](../docs/02-arquitetura.md).

## Estrutura

```
lib/
  main.dart            entradas: main() e browserMain() (navegador gerenciado)
  app/                 composição: inicialização, roteador, tema
  core/                infraestrutura: rede, JSON, ponte nativa, segurança, tempo
  shared/              modelo da política e componentes visuais comuns
  features/
    onboarding/        boas-vindas e escolha do modo
    guardian/          modo responsável
    child/             modo criança e navegador gerenciado
pigeons/               definição da ponte Dart e Kotlin
android/               agente nativo, manifesto e recursos
test/                  testes de unidade, de widget e capturas de tela de referência
```

## Comandos

```bash
flutter pub get
flutter analyze
flutter test                                  # todos os testes
flutter test --update-goldens --tags screenshot   # regenerar as capturas de referência
flutter build apk --debug
flutter build apk --release --dart-define=API_BASE_URL=https://seu-servidor
```

Testes do agente nativo (JVM), a partir de `android/`:

```bash
./gradlew :app:testDebugUnitTest
```

Depois de alterar `pigeons/native_api.dart`, gere a ponte de novo:

```bash
dart run pigeon --input pigeons/native_api.dart
```

## Convenções

- O Material Design vem do pacote `material_ui`: importe `package:material_ui/material_ui.dart`,
  não `package:flutter/material.dart`.
- Injeção de dependências por provedores Riverpod. Os testes trocam dependências com `overrides`.
- Sem `dynamic`. A leitura de JSON passa por `core/json/json_reader.dart`.
- Largura de linha de 100 colunas (`dart format`).
- Em testes de widget, não espere dentro de `testWidgets` por futuros que dependem de E/S real ou
  do cancelamento de assinaturas de stream: use `tester.runAsync`.
