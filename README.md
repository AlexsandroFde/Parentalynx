# ParentaLynx

Controle parental para Android. O mesmo aplicativo é instalado no aparelho do responsável e no
aparelho da criança. O responsável define o tempo de uso, os aplicativos permitidos e os horários,
e acompanha relatórios. A criança vê, com clareza, as regras que valem e quanto tempo resta.

O controle é transparente por princípio: o app nunca fica escondido, não lê mensagens, não
registra o que é digitado e não captura a tela.

## O que tem aqui

| Pasta | Conteúdo |
| --- | --- |
| [app/](app/) | Aplicativo Flutter (interface dos dois modos) e o agente nativo Android em Kotlin |
| [backend/](backend/) | Servidor Node 24 com SQLite: contas, vínculo, política, sincronização, relatórios, alertas |
| [docs/](docs/) | Análise do Android, arquitetura, protocolo, instalação, Device Owner, privacidade e testes |
| [scripts/e2e/](scripts/e2e/) | Ferramentas de teste de ponta a ponta (cliente do responsável e utilitários de adb) |

## Funcionalidades

**Responsável**
- Conta com senha administrativa (Argon2id), chave de recuperação e bloqueio do painel por senha.
- Vinculação por código de uso único, com número de confirmação conferido nos dois aparelhos.
- Limite diário em horas e minutos, por dia da semana, com horário de reinício.
- Horários permitidos e períodos de bloqueio (semanais ou pontuais).
- Aplicativos com três estados: permitido, bloqueado e exceção. Limite próprio por app.
- Tempo extra, pausa imediata e suspensão temporária de regras.
- Painel com tempo usado e restante, estado do bloqueio, conexão e confirmação das regras.
- Relatórios por período com gráficos, linha do tempo de sessões, eventos e navegação.
- Alertas e preferências de notificação. Pedidos de tempo da criança.
- Auditoria, exportação e exclusão de dados.

**Aparelho da criança**
- Contagem de tempo efetivo de uso pelo registro de eventos do Android, com retomada após falhas.
- Bloqueio real de aplicativos: interceptação com tela de bloqueio nativa no modo padrão, e
  suspensão pelo sistema no modo Device Owner.
- Funciona sem internet e sincroniza depois. Persiste após reinicialização.
- Chamadas de emergência e funções essenciais nunca são bloqueadas.
- Tela inicial com tempo restante, regras em vigor, responsável e pedido de mais tempo.
- Navegador gerenciado com histórico visível ao responsável e filtro de sites.
- Área do responsável com senha ou código de acesso offline.

## Começar

1. Servidor:
   ```bash
   cd backend
   npm install
   npm start
   ```
2. Aplicativo de desenvolvimento:
   ```bash
   cd app
   flutter pub get
   flutter build apk --debug
   ```
3. Instale o APK nos dois aparelhos e siga [docs/04-instalacao.md](docs/04-instalacao.md).

Para testar sem um segundo aparelho, o backend traz um simulador de aparelho da criança
(`npm run simulate`, descrito em [backend/README.md](backend/README.md)).

## Documentação

1. [Capacidades do Android por modo de instalação](docs/01-capacidades-android.md): o que é
   garantido, o que é só detectado e o que não é possível em cada modo.
2. [Arquitetura](docs/02-arquitetura.md) e a decisão sobre o app Flutter com BLoC e Clean
   Architecture ([ADR 0001](docs/adr/0001-bloc-clean-architecture.md))
   - Interface: [Design System "Lince"](docs/design/design-system.md), com a
     [pesquisa e o conceito visual](docs/design/pesquisa-e-conceito.md), a
     [arquitetura de informação](docs/design/arquitetura-de-informacao.md), a
     [avaliação de usabilidade por funcionalidade](docs/usabilidade/README.md) e o
     [ADR 0002](docs/adr/0002-identidade-visual-e-design-system.md)
3. [Protocolo: API, política, eventos e sincronização](docs/03-protocolo.md)
4. [Instalação](docs/04-instalacao.md)
5. [Modo Device Owner](docs/05-device-owner.md)
6. [Privacidade, segurança e LGPD](docs/06-privacidade-lgpd.md)
7. [Testes e validação](docs/07-testes.md): o que foi testado automaticamente, o que foi validado
   em emulador e o que ainda depende de aparelhos físicos.

## Limites que você precisa conhecer

- **Modo padrão é contornável.** Em uma instalação comum, quem está com o aparelho consegue
  desligar as permissões ou desinstalar o app. O ParentaLynx detecta e avisa o responsável, mas
  não impede. O bloqueio imposto pelo sistema exige o modo Device Owner, que só pode ser ativado
  em um aparelho sem contas (na prática, recém-restaurado).
- **Alertas com o app do responsável fechado levam até cerca de 15 minutos.** Não há push de
  terceiros nesta versão. Com o app aberto, os alertas chegam na hora.
- **Navegação só é registrada e filtrada no navegador gerenciado**, não em outros navegadores ou
  apps. No modo Device Owner há também filtro DNS no sistema inteiro.
- **Só Android.** Não há versão para iOS.
- **Não foi testado em aparelhos físicos.** A validação prática foi feita em emulador com
  Android 16. Fabricantes com economia de bateria agressiva exigem verificação em campo.

## Tecnologia

Flutter 3.47 e Dart 3.13 (BLoC, get_it, go_router, fl_chart, Pigeon), Kotlin (OkHttp, WorkManager),
Node 24 com TypeScript executado diretamente (Fastify, `node:sqlite`, Argon2 de `node:crypto`).
