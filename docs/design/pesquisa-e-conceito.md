# Pesquisa de referências e conceito visual

Este documento registra as etapas 1 e 2 do processo de UI/UX: o que foi estudado em produtos
reconhecidos pelo design, o que foi aproveitado e evitado, e o conceito visual que orienta o
Design System do ParentaLynx ([design-system.md](design-system.md)).

A análise foi feita a partir dos padrões públicos desses produtos (telas oficiais, guias de
interface e o comportamento conhecido de cada um). Nenhuma interface, marca ou componente foi
reproduzido: as referências serviram para entender decisões, não como modelo visual.

## 1. Referências analisadas

| Produto | O que observamos | O que levamos para o ParentaLynx | O que evitamos |
| --- | --- | --- | --- |
| Apple Tempo de Uso | Resumo do dia em um número grande, barras por app com o tempo ao lado, limites agrupados por categoria, pedido de "mais tempo" direto na tela de bloqueio. | Um número principal por tela (tempo restante), lista de apps com barra fina e minutos alinhados à direita, pedido de tempo sempre a um toque. | Gráficos de barras empilhadas por categoria na tela inicial: densos demais para uma consulta rápida. |
| Google Family Link | Cartão por criança com aparelho, localização e tempo; ações rápidas (bloquear agora, tempo extra); limites por dia da semana; app da criança mostrando as regras. | Painel centrado na criança, ações rápidas com o valor no rótulo ("+ 15 min"), regras explicadas para a criança na tela dela. | Pilhas de cartões iguais com borda; cores fortes do Material padrão; linguagem técnica em permissões. |
| Linear | Hierarquia por tipografia e espaço, poucas bordas, neutros cuidadosos, estados com ícone e texto, atalhos para quem usa muito. | Seções separadas por espaço (não por bordas), títulos de seção pequenos e firmes, etiquetas de estado com ícone + texto, ações secundárias discretas. | Densidade de informação de ferramenta profissional e tema escuro como padrão. |
| Things 3 | Listas agrupadas em um único painel, títulos grandes no topo, muito espaço negativo, animações curtas que explicam a mudança. | `AppListGroup` (linhas em um só painel com divisórias recuadas), título grande da página com o contexto ("Regras de João"), transições suaves entre estados. | Gestos escondidos como única forma de agir: toda ação tem um botão visível. |
| Notion | Componentes simples e combináveis, conteúdo organizado em blocos, ajuda e explicações perto do conteúdo. | Componentes pequenos com uma responsabilidade cada, ajuda contextual ("?") ao lado da configuração que ela explica. | Flexibilidade ilimitada: o ParentaLynx precisa de fluxos previsíveis, não de páginas montáveis. |
| Arc e Raycast | Personalidade forte com acabamento preciso: marca presente, microinterações com propósito, cores usadas com intenção. | Uma marca reconhecível (o lince e o petróleo), cor de destaque reservada para a marca, retorno tátil em escolhas e em ações destrutivas. | Gradientes e cores múltiplas competindo; animações decorativas. |

### Padrões que se repetem nas referências

1. **Um número em destaque por contexto.** O tempo restante é a resposta à pergunta mais comum
   dos dois perfis ("quanto falta?").
2. **Espaço entre assuntos, contorno fino nas superfícies.** Os produtos mais bem acabados
   separam assuntos por espaço e delimitam superfícies com uma linha fina e neutra, sem sombra
   e sem fundo colorido (revisão da [ADR 0003](../adr/0003-revisao-visual-sobriedade.md)).
3. **Estado sempre visível e com texto.** "Aplicado", "Aguardando", "Sem conexão" aparecem com
   ícone e texto, nunca só com cor.
4. **Ações perto do que mudam.** Tempo extra fica junto do tempo de hoje; o pedido de tempo da
   criança fica junto do anel do tempo.
5. **Linguagem de quem usa, não de quem programa.** "Hora de dormir", não "período de
   bloqueio programado".

## 2. Conceito: "Lince — atenção serena"

O lince enxerga longe e no escuro, sem alarde. O ParentaLynx deve transmitir a mesma ideia:
**cuidado atento e calmo**, sem clima de vigilância nem de punição.

| Atributo | No responsável | Na criança |
| --- | --- | --- |
| Tom | Confiança, controle, clareza | Acolhimento, simplicidade, transparência |
| Forma | Raios contidos (8 a 16), contornos finos | Raios um pouco maiores (12 a 20) |
| Texto | Escala padrão, hierarquia forte | Corpo e títulos 8% maiores, frases curtas |
| Restrição | Estado com nome e regra que o causou | Explicação gentil do motivo e de quando volta |
| Cor de restrição | Coral para erro e tentativa bloqueada; anil para descanso | Anil (descanso), nunca vermelho |

Os dois perfis usam os mesmos tokens e componentes; a diferença vem do tema do perfil
(`AppExperienceScope`), não de componentes diferentes.

### Princípios visuais

1. **Calma antes de alarme.** Fundo grafite neutro, superfícies brancas com contorno fino e uma
   única cor de ação. Cores de estado só em ícones e textos curtos; vermelho só para erro e para
   o que é destrutivo.
2. **Uma cor, um significado.** Petróleo é ação e marca; verde é permitido/aplicado; ocre é
   atenção/pendente; coral é erro; anil é descanso. Âmbar aparece só no logotipo.
3. **Hierarquia pela tipografia.** Título grande da página, títulos de seção pequenos e firmes,
   números com algarismos tabulares.
4. **Espaço separa, superfície agrupa.** Seções separadas por 32 pontos; itens relacionados em
   um único painel.
5. **Movimento explica.** Valores crescem até o lugar (anel, barras), estados trocam com um
   leve deslize; nada se move só para enfeitar, e tudo para quando o sistema pede menos
   animação.

## 3. Decisões de identidade

### Cor

- **Petróleo (`#136874`)** como cor da marca e de tudo que é interativo. Fica entre o azul da
  confiança e o verde da calma, e se diferencia do azul genérico dos templates. Contraste de
  6,4:1 com texto branco.
- **Grafite** nos neutros do tema claro (`#F6F6F7` no fundo): neutros levemente frios, sem
  puxar para o bege, que deixam o petróleo como a única cor da interface. A primeira versão
  usava areia quente; a [ADR 0003](../adr/0003-revisao-visual-sobriedade.md) trocou por grafite
  para um visual mais sóbrio.
- **Noite** nos neutros do tema escuro, da mesma família do grafite. O tema escuro não é uma
  inversão: cada papel tem o seu valor próprio (por exemplo, petróleo claro `#6DBAC3` para
  ações).
- **Anil para descanso.** Hora de dormir e pausas são combinados, não erros; por isso têm uma
  cor própria, distinta do vermelho.
- Todos os textos pequenos têm contraste de pelo menos 4,5:1 sobre o fundo e sobre a superfície
  do seu tom (conferido no teste de acessibilidade do catálogo).

### Tipografia

**Manrope**, embutida no app (licença SIL OFL 1.1, sem download em tempo de execução).
Geométrica e humana: firme no painel e amigável para a criança. Títulos em 600 e texto corrido
em 500: a hierarquia vem do tamanho e da cor, não do excesso de peso. Tem algarismos tabulares
(`tnum`), usados em tempos e contagens para os números não "pularem" quando mudam, e todos os
caracteres do português.

### Marca

O símbolo é a cabeça de um lince em silhueta branca (orelhas com tufos, colar de pelos nas
bochechas, olhos vazados com pupilas em fenda e sobrancelhas âmbar) sobre um quadrado
arredondado de petróleo. O ícone do app e o `BrandMark` desenham as mesmas formas, em vetor; o
ícone tem também uma versão de uma cor só para os ícones temáticos do Android. Usa cores fixas,
iguais nos temas claro e escuro, para ser sempre reconhecido.

### Iconografia

Material Icons em um único estilo (contornado), com nomes por significado em `AppIcons`. A
versão preenchida aparece só no item selecionado da navegação. Nenhum emoji no lugar de ícone.

### Voz

- Frases curtas, na segunda pessoa, com a ação no começo ("Peça mais tempo", "Confira as
  permissões").
- Sem termos internos (política, versão, sincronização) quando houver palavra comum: "regras",
  "enviadas ao aparelho", "aplicadas".
- Para a criança, explicar o motivo e quando volta, sem culpa: "Hora de descansar. O celular
  volta às 07:00." em vez de "Bloqueado pelo responsável".
- Mensagens de erro dizem o que aconteceu, o que foi ou não salvo e o que fazer.
