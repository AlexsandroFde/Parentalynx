# Design System "Lince"

O Design System do ParentaLynx fica em `app/lib/shared/design_system/` e é importado por um único
arquivo:

```dart
import '../../../../shared/design_system/design_system.dart';
```

O conceito, as referências e as decisões de identidade estão em
[pesquisa-e-conceito.md](pesquisa-e-conceito.md); a revisão visual que deixou a interface mais
sóbria está na [ADR 0003](../adr/0003-revisao-visual-sobriedade.md). As capturas do catálogo,
nos temas claro e escuro, ficam em `app/test/shared/design_system/screenshots/` (`ds_*.png`).

```text
shared/design_system/
├── design_system.dart          ponto único de importação
├── tokens/                     cores, tipografia, espaçamentos, raios, elevação, movimento,
│                               opacidade e dimensões
├── themes/                     AppTheme (claro e escuro) e o perfil (responsável ou criança)
├── foundations/                ícones, tom semântico, marca, licenças, atalhos do contexto
└── components/
    ├── buttons/                AppButton, AppIconButton
    ├── inputs/                 campos, senha, seleção, chaves, duração
    ├── cards/                  AppPanel, AppListGroup e linhas
    ├── layout/                 corpo, cabeçalho, seção, passos, barra de ação fixa
    ├── indicators/             etiquetas, sincronização, anel do tempo, barras, métricas
    ├── feedback/               avisos, vazio, erro, carregamento, confirmações curtas
    ├── dialogs/                confirmação, folha inferior, ajuda contextual
    ├── charts/                 estilo dos gráficos
    └── child/                  estrutura das telas do modo criança
```

## 1. Tokens

Leia os tokens do tema atual com os atalhos de `BuildContext`:

```dart
context.colors.primary          // AppColors: papéis de cor
context.text.titleMedium        // TextTheme: escala de texto do perfil
context.textStyles.metricLarge  // AppTextStyles: números e sobretítulo
context.shapes.containerRadius  // AppShapes: raios do perfil
```

### Cores (`AppColors`)

Cada papel tem um único significado em todo o app. Use o papel, nunca a primitiva da paleta.

| Papel | Significado | Claro | Escuro |
| --- | --- | --- | --- |
| `canvas` | Fundo das páginas | grafite `#F6F6F7` | noite `#0F0F11` |
| `surface` | Painéis, listas, folhas, campos | `#FFFFFF` | `#18181B` |
| `surfaceMuted` | Trilhos, avatares, áreas de apoio | `#F0F0F2` | `#1F1F23` |
| `hairline` | Divisores e contorno de painéis e listas | `#E6E6EA` | `#26262B` |
| `border` | Contorno de controles que já têm texto (secundário, chips) | `#D8D8DE` | `#36363D` |
| `outline` | Contorno de campos e caixas de seleção (3:1) | `#8B8B94` | `#6E6E78` |
| `textPrimary` / `textSecondary` | Texto principal / de apoio (6:1 ou mais) | `#17171A` / `#5C5C66` | `#ECECEF` / `#A3A3AD` |
| `textTertiary` | Texto de exemplo dos campos (4,5:1) | `#73737D` | `#808089` |
| `primary` | Marca e tudo que é interativo | petróleo `#136874` | `#6DBAC3` |
| `primaryContainer` | Fundo leve da seleção (chip escolhido) | `#EDF5F6` | `#0F2629` |
| `success` | Permitido, aplicado, online | `#1A6E44` | `#7FD3A6` |
| `warning` | Atenção, pendente, pouco tempo | `#8A5100` | `#F2BF6C` |
| `danger` | Erro, destrutivo, tentativa bloqueada | `#B4372F` | `#FF9F93` |
| `rest` | Descanso combinado (dormir, pausa) | anil `#5248A8` | `#B7AFF3` |
| `brandAccent` | Só o logotipo | âmbar `#E59B32` | `#F6C46A` |
| `chart` | Séries de gráficos, em ordem fixa | 6 cores | 6 cores |

A interface é quase toda neutra. O petróleo aparece no que é interativo e na marca; as cores de
estado aparecem em ícones e textos curtos, nunca como fundo decorativo de botões, avisos,
etiquetas ou ícones.

### Tom semântico (`Tone`)

`neutral`, `info`, `success`, `warning`, `danger` e `rest`. O tom colore o ícone e o texto
curto (`tone.foreground`), não o fundo: avisos e etiquetas ficam sobre a superfície neutra, e
atenção e erro ganham também o contorno do tom (`tone.border`). Ícones que acompanham um título
(linhas de lista, marcadores) usam `tone.iconColor`: cinza para `neutral`, `info` e `rest`,
cor só para `success`, `warning` e `danger`. `tone.background` fica para o raro painel que
precisa se destacar como bloco. A cor nunca é o único sinal: sempre há um ícone ou marcador e um
texto.

Na tela da criança, restrições usam `Tone.rest` (descanso) ou `Tone.neutral`, nunca
`Tone.danger`.

### Tipografia (`AppTypography`, `AppTextStyles`)

Manrope, embutida. A hierarquia vem do tamanho e da cor: títulos, rótulos e números em 600,
texto corrido em 500, nada acima de 700. Escala do responsável (no perfil da criança, ×1,08):

| Estilo | Tamanho / altura | Uso |
| --- | --- | --- |
| `headlineMedium` | 24 / 30, 600 | Título da página (`AppPageHeader`) |
| `headlineSmall` | 20 / 26, 600 | Título de diálogo |
| `titleLarge` | 18 / 24, 600 | Barra superior, título de folha |
| `titleMedium` | 15 / 20, 600 | Título de seção |
| `titleSmall` | 14 / 20, 600 | Título de aviso, botões compactos |
| `bodyLarge` | 16 / 24, 500 | Texto principal, linhas de lista |
| `bodyMedium` | 14 / 20, 500 | Texto de apoio |
| `bodySmall` | 12,5 / 18, 500 | Legendas, rodapés de grupo |
| `labelLarge` | 15 / 20, 600 | Botões |
| `labelMedium` | 13 / 18, 600 | Indicadores de estado, rótulos de campo, abas |
| `metricHero` | 48, 600, tabular | Tempo restante na tela da criança |
| `metricLarge` | 34, 600, tabular | Valor principal de um painel |
| `metricMedium` | 20, 600, tabular | Linha de métricas |
| `metricSmall` | 14, 600, tabular | Minutos na lista de apps |
| `eyebrow` | 13, 600, caixa normal | Sobretítulo ("Hoje", "Passo 1 de 3") |

Textos de até 13 pontos usam 600 e rótulos curtos de chips usam 700: a medição de contraste dos
testes (`textContrastGuideline`) estima a cor do texto a partir dos pixels de uma imagem em 1x
e, com hastes finas, confunde o serrilhado com a cor do texto, mesmo quando o contraste real
passa de 6:1. Pelo mesmo motivo o texto corrido fica em 500, não em 400.

### Espaçamento (`AppSpacing`)

Escala de 4 em 4: `xxs 2`, `xs 4`, `sm 8`, `md 12`, `lg 16`, `xl 24`, `xxl 32`, `xxxl 48`.
Semânticos: `gutter 20` (margem lateral), `sectionGap 32` (entre seções),
`sectionHeaderGap 12`, `page` (margem do corpo), `panel` (16 dentro de painéis), `row`
(linhas), `maxContentWidth 640`, `maxFormWidth 480`.

### Raios (`AppRadius`, `AppShapes`)

Escala: `xs 4`, `sm 6`, `md 8`, `lg 12`, `xl 16`, `xxl 20`, `pill`. Componentes usam a forma do
perfil (`context.shapes`): controles 8 / 12, contêineres 12 / 16, folhas 16 / 20, ícones de app
8 / 12 (responsável / criança). Elementos dentro de um painel usam um raio menor que o dele.

### Elevação, movimento, opacidade e dimensões

- `AppElevation.none` para o conteúdo; `raised` para o seletor do controle segmentado;
  `overlay` para o que flutua. Painéis, listas, avisos e a barra de ação fixa se separam por um
  contorno fino (`hairline`), sem sombra.
- `AppMotion`: `fast 120ms`, `base 200ms`, `slow 320ms`, `emphasis 520ms`; curvas `standard`,
  `emphasized`, `exit`. Sempre passe por `AppMotion.resolve(context, ...)`, que zera a duração
  quando o sistema pede para reduzir animações.
- `AppOpacity`: desabilitado `0.38`, camadas de interação `0.08` a `0.12`, fundo de folha `0.40`.
- `AppSizes`: área de toque mínima `48`, botões e campos `48` (compactos `36` com toque de
  `48`), ícones `14` a `32`, ícone de linha `24` (`rowIcon`), ícone de app `36` (`iconTile`),
  medalhão `48`, avatares `32`/`36`/`48`, barra de uso `4`.

## 2. Temas e perfis

- `AppTheme.light()` / `AppTheme.dark()` montam o tema só a partir dos tokens. Os componentes
  do Material (barra superior, campos, chaves, folhas, diálogos, navegação) já saem com a
  identidade.
- `AppExperienceScope(experience: AppExperience.child, child: ...)` aplica o perfil da criança
  (formas mais arredondadas e texto maior) mantendo claro ou escuro. A área da criança e o
  navegador gerenciado ficam dentro dele.
- O tema escuro tem valores próprios para cada papel; nunca use `Colors.white`/`Colors.black`.

## 3. Componentes

| Componente | Quando usar |
| --- | --- |
| `AppButton.primary` | A ação principal da tela (no máximo uma visível). Único botão preenchido com a cor de ação. |
| `AppButton.secondary` | Ações de apoio com o mesmo peso entre si ("+ 15 min", "Pedir mais tempo" quando não é a principal). Contornado, sobre a superfície. |
| `AppButton.tertiary` | Ações discretas e links ("Cancelar", "Ver todos"). |
| `AppButton.danger` | Ação destrutiva, sempre depois de `showConfirmDialog`. |
| `busy: true` | Durante a operação: mostra o indicador e ignora toques (evita envio duplo) sem parecer desabilitado. |
| `AppIconButton` | Botão só com ícone; `tooltip` obrigatório (é o nome lido pelo leitor de tela). A variante `tonal` é contornada. |
| `AppTextField` / `AppPasswordField` | Campos com o rótulo acima do contorno, sempre visível e anunciado como nome do campo; `isRequired` marca obrigatório; `hint` e `helper` mostram o formato esperado antes do erro. |
| `AppChoiceChips` | Valores prontos (atalhos) sem esconder o valor próprio. |
| `AppSegmentedControl` | De 2 a 4 opções exclusivas lado a lado (períodos de relatório): trilho neutro com a opção escolhida destacada. |
| `AppSwitchRow` / `AppCheckboxRow` / `AppRadioRow` | Linhas de configuração; a linha inteira é tocável. |
| `showDurationPicker` / `pickTimeOfDay` | Duração e horário com rodas e atalhos. |
| `AppPageBody` | Corpo rolável da página (margem, largura máxima, puxar para atualizar). |
| `AppPageHeader` | Título grande com o contexto ("Regras de João", aparelho embaixo). |
| `AppSection` | Título de seção fora do conteúdo, ação à direita ("Ver todos"). |
| `SectionGap` | Espaço padrão entre seções. |
| `AppPanel` | Conteúdo de destaque de uma seção (tempo de hoje, resumo). Com `tone`, fundo do tom. |
| `AppListGroup` + `AppListRow` | Listas de itens em um único painel com contorno fino e divisores de ponta a ponta; `leading` com `AppIconTile` (ícone sem fundo) ou avatar, `trailing` com `AppRowValue`/`StatusBadge`, `below` com `UsageBar`. |
| `IconMedallion` | Ícone em destaque em um quadro com contorno: estados vazios, diálogos e cabeçalhos de telas curtas. Nunca dentro de listas. |
| `StatusBadge` | Estado curto: ponto (ou ícone) e texto na cor do tom, sem caixa em volta. |
| `SyncStatusLine` | Estado de uma configuração entre painel e aparelho: `applied`, `pending`, `sending`, `offline`, `failed`. |
| `TimeRing` | Tempo usado/restante com o valor no centro e `semanticLabel` completo. Só na tela da criança; no painel do responsável o tempo aparece como número e `UsageBar`. |
| `UsageBar` | Barra fina de uso relativo (o valor vem em texto ao lado). |
| `MetricTile` / `MetricRow` | Valores numéricos com rótulo. |
| `InitialAvatar` | Inicial de um nome (criança, aparelho). |
| `StepList` | Passos numerados de um processo (vinculação, primeiro acesso). |
| `StickyActionBar` | Ação principal fixa no rodapé de editores e formulários longos, com a consequência ("As mudanças são enviadas ao aparelho de João"). |
| `AppBanner` | Aviso dentro da página, com ação de recuperação. |
| `EmptyState` | Nada para mostrar: o que apareceria ali e o próximo passo. |
| `ErrorState` | Falha ao carregar: o que falhou, por quê e "Tentar de novo". `ErrorState.fromError(erro, subject: 'os relatórios')`. |
| `LoadingState` | Carregamento de tela inteira com frase opcional. |
| `Skeleton`, `SkeletonListGroup`, `SkeletonPanel` | Carregamento de conteúdo com forma conhecida. |
| `StateSwitcher` | Troca suave entre carregando, conteúdo, vazio e erro. |
| `showAppSnackBar` / `showFailure` | Confirmação curta depois que a operação terminou de fato. |
| `showConfirmDialog` | Confirmação antes de algo importante; `destructive` e `consequence`. |
| `showAppSheet` / `AppSheetFrame` | Folha inferior com cabeçalho e botão de fechar. |
| `HelpButton` / `showHelpSheet` | Ajuda contextual ao lado do que ela explica. |
| `AppChartStyle.of(context)` | Cores e textos dos gráficos. |
| `ChildPageBody`, `ChildHeader`, `BulletLine` | Estrutura das telas da criança. |
| `BrandMark`, `BrandLockup` | Símbolo e nome do app. |
| `AppIcons` | Todos os ícones, por significado. |

## 4. Padrões de tela

### Anatomia de uma página

```text
AppBar (título curto, voltar, ações com tooltip)
AppPageBody
  AppPageHeader      título grande com o contexto (raiz das abas e detalhes)
  [AppBanner]        só se houver algo a resolver
  AppSection         título + conteúdo
  SectionGap
  AppSection ...
StickyActionBar      só em editores e formulários longos
```

### Estados de uma tela

Toda tela que carrega dados trata os quatro estados com os componentes do Design System:

| Estado | Componente | Regra |
| --- | --- | --- |
| Carregando | `Skeleton*` (forma conhecida) ou `LoadingState` (tela inteira) | Nunca uma tela em branco. |
| Conteúdo | — | Atualizar sem apagar o conteúdo atual (puxar para atualizar). |
| Vazio | `EmptyState` | Diz o que apareceria e oferece o próximo passo. |
| Erro | `ErrorState` ou `AppBanner(tone: danger)` | O que falhou, se algo foi salvo, o que fazer, botão de tentar de novo. |

Use `StateSwitcher` com chaves distintas para a troca entre estados.

### Mensagens de erro (heurística 9)

Modelo: **o que aconteceu** + **o que foi ou não salvo / o que continua valendo** + **o que
fazer**. Exemplos:

- "Não foi possível salvar o limite. A configuração anterior continua ativa no aparelho." +
  "Tentar de novo".
- "O aparelho está sem conexão. As alterações serão enviadas quando ele voltar a ficar online."
- "Não foi possível aplicar o bloqueio. Confira as permissões do controle no aparelho." +
  "Ver permissões".

Nunca "Algo deu errado" nem códigos internos.

### Editores de regras

`AppPageHeader` com o nome da criança, conteúdo em seções, `SyncStatusLine` (pelo
`PolicySyncStatusView`) mostrando se a versão atual já vale no aparelho e `StickyActionBar` com
"Salvar" (ocupado enquanto envia). Depois de salvar: `showAppSnackBar` dizendo que foi salvo e
que o aparelho aplica em instantes; o estado só vira "aplicado" quando o aparelho confirma.

### Confirmações (heurísticas 3 e 5)

- Destrutivo ou que retira acesso (desvincular, excluir conta, encerrar sessões):
  `showConfirmDialog(destructive: true, consequence: 'Esta ação não pode ser desfeita.')`, com o
  rótulo nomeando a ação.
- Reversível: não pedir confirmação; mostrar o resultado e, quando possível, "Desfazer" no
  aviso.

### Ajuda (heurística 10)

`HelpButton` ao lado de configurações que precisam de explicação (modo de proteção, exceções,
filtro de sites, permissões do Android, código de vinculação). Textos curtos, em perguntas e
respostas (`HelpTopic`).

### Telas da criança

`AppExperienceScope(child)`, `ChildPageBody`, frases curtas, um número em destaque (o tempo),
uma ação principal ("Pedir mais tempo"), regras explicadas com `BulletLine` e o motivo de cada
restrição com `Tone.rest`. Nada que permita desativar ou contornar as regras.

## 5. Acessibilidade e responsividade

- Área de toque mínima de 48×48; botões compactos mantêm o toque de 48.
- Contraste de texto de 4,5:1 (3:1 para texto grande), conferido pelo `expectAccessible` dos
  testes.
- Todo controle só com ícone tem `tooltip`; imagens decorativas ficam fora da árvore de
  acessibilidade; estados mudam com `liveRegion` (avisos, sincronização, erros).
- Fonte até 2× (o máximo do Android): textos quebram linha em vez de cortar; números dentro do
  anel diminuem para caber e repetem o valor em texto.
- Largura máxima de 640 no conteúdo e 480 em formulários; nada depende de uma largura fixa de
  tela.
- Animações respeitam "remover animações" do sistema.

## 6. Regras conferidas por teste

`test/architecture/design_system_test.dart` confere, em cada funcionalidade e na composição:

- sem cores fora dos tokens (`Color(0x…)`, `Colors.*` exceto `transparent`);
- sem `TextStyle(` nem `fontSize`: use `context.text`/`context.textStyles` com `copyWith`;
- sem `Icons.*`: use `AppIcons`;
- sem números soltos em `EdgeInsets`, raios e espaçadores (`SizedBox` com só altura ou só
  largura);
- sem sombras soltas;
- sem botões, linhas e cartões do Material direto: use `AppButton`, `AppIconButton`,
  `AppListRow`/`AppSwitchRow`/`AppCheckboxRow`/`AppRadioRow`, `AppPanel`/`AppListGroup`;
- sem importar os caminhos antigos (`shared/theme/app_theme.dart`, `shared/widgets/`).

Exceção justificada: `// ds-ignore: <motivo>` na linha ou na linha de cima.

`test/shared/design_system/catalog_test.dart` gera as capturas do catálogo (claro e escuro,
dois perfis), confere as diretrizes de acessibilidade do Flutter e o funcionamento com fonte 2×.

## 7. Evoluindo o Design System

1. Um padrão que aparece em mais de uma funcionalidade vira componente aqui, com parâmetros
   tipados e uma responsabilidade.
2. Novo componente entra no catálogo (`catalog_test.dart`) nos dois temas.
3. Novo significado de cor ou de ícone entra nos tokens/`AppIcons` com nome semântico, nunca
   como valor solto na tela.

## 8. Candidatos a componente

Padrões que as funcionalidades montaram com as peças do Design System durante a avaliação
heurística e que devem virar componentes compartilhados (seguindo a seção 7):

| Padrão | Onde está hoje | Proposta |
| --- | --- | --- |
| Linha de lista destrutiva ou em andamento | `child_device` (`_ActionRow`), `authentication` (`InlineProgress`) | `AppListRow(destructive:, busy:)` |
| Aviso flutuante no topo (alerta em tempo real) | `guardian` (casca do painel) | `AppToast` |
| Diálogo com campo, no estilo de `showConfirmDialog` | `authentication` (`FormDialogFrame`) | `showFormDialog` |
| Exibição de segredos e códigos (agrupamento, quebra entre grupos) | chave de recuperação, código de vinculação | `SecretCode` |
| Grade de apps (ícone e nome, tocável) | `child_mode` | `AppGridTile` |
| Chips de múltipla escolha (filtros) | `app_management` | `AppFilterChips` |
| Lista agrupada construída sob demanda (listas longas) | `app_management` (`_GroupedRow`) | `AppListGroup.builder` |
| Botão terciário destrutivo | `schedules`, `blocking` | `AppButton.tertiary(destructive:)` |
| Botão sobre fundo invertido | `guardian` (aviso da casca) | tom `onInverse` no `AppButton` |
| Complemento da linha abaixo do texto com fonte ampliada | `app_management` | reflow automático no `AppListRow` |
| Subtítulo de seção sem título | `settings` | `AppSection` aceitar só o subtítulo |
| Sobretítulo no cabeçalho da criança | `child_mode` | `ChildHeader(eyebrow:)` |

Observação de teste: a diretriz de contraste do Flutter (`textContrastGuideline`) estima as cores
a partir dos pixels do retângulo do texto e pode acusar contraste baixo em parágrafos cuja
última linha é curta, mesmo com cores de 13:1 (caso visto em um aviso de tom `info`). As cores
dos tokens têm o contraste conferido na seção 1; quando o falso positivo aparece, o texto é
reescrito ou o teste confere o contraste em outro estado da tela.
