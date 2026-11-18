# ADR 0003: Revisão visual, sobriedade e minimalismo

- **Status:** aceito
- **Data:** 18/11/2026
- **Relacionado:** [ADR 0002](0002-identidade-visual-e-design-system.md) (identidade e Design
  System), [design-system.md](../design/design-system.md)

## Contexto

A identidade "Lince" (ADR 0002) tirou o app do visual de template, mas a execução acumulou
sinais típicos de interface gerada automaticamente:

- fundos pastel em quase tudo: botão secundário, avisos, etiquetas, quadrados atrás de cada
  ícone de lista, avatares, indicador da navegação, seleção de chips e segmentos;
- cinco cores de estado convivendo na mesma tela, cada uma com o seu fundo claro;
- cantos muito arredondados (20 a 28 nos painéis) e pílulas em etiquetas e chips;
- sobretítulos em maiúsculas com espaçamento largo ("HOJE", "PRIMEIRO ACESSO");
- pesos 700 e 800 em quase todos os títulos e números;
- fundo de areia quente com superfícies brancas sem contorno;
- rótulo dos campos recortando a borda (o desenho padrão do Material).

O responsável usa o app para decisões sérias (limites, bloqueios, desvinculação). A aparência
precisa transmitir precisão e confiança, com menos ruído e a mesma clareza de estado.

## Decisão

1. **Neutros grafite** (levemente frios) no lugar da areia: fundo `#F6F6F7`, superfície branca,
   texto `#17171A`, texto de apoio `#5C5C66` (6:1). Tema escuro na mesma família.
2. **Contorno fino separa, cor não decora.** Painéis, listas, avisos e a barra de ação fixa têm
   contorno de 1 ponto (`hairline`), sem sombra e sem fundo colorido.
3. **Petróleo só no que é interativo** (botão primário, links, seleção, foco) e na marca. O
   primário é o único botão preenchido; o secundário é contornado.
4. **Cor de estado só em ícones e textos curtos.** `StatusBadge` vira ponto (ou ícone) e texto,
   sem caixa; avisos ficam na superfície neutra, com o contorno do tom só em atenção e erro;
   ícones de linha ficam em cinza, coloridos só para confirmação, atenção e erro.
5. **Raios contidos:** controles 8, painéis 12, folhas 16 (criança: 12, 16 e 20).
6. **Tipografia:** Manrope continua. Títulos, rótulos e números em 600, texto corrido em 500,
   nada acima de 700; sobretítulo em caixa normal.
7. **Componentes:** `IconMedallion` (quadro com contorno) para ícones de destaque em estados
   vazios, diálogos e cabeçalhos; controle segmentado com trilho neutro e seletor; rótulo do
   campo acima do contorno, anunciado como nome do campo; navegação sem pílula, com linha fina
   no topo; marcadores de passos contornados.
8. **Painel do responsável:** o tempo de hoje aparece como número e barra de uso, no lugar do
   anel; o anel fica só na tela da criança, mais fino. O cabeçalho perde o avatar, que repetia
   o nome.
9. **Tela de bloqueio nativa:** fundo sólido (sem degradê), cantos de 12 a 16, ícone em quadro
   contornado e título em Bold. A Manrope ExtraBold nativa deixou de ser usada e saiu do APK.

## Alternativas avaliadas

| Alternativa | Por que não |
| --- | --- |
| Manter a paleta e só reduzir os raios | Os fundos pastel e as pílulas eram a maior parte do ruído. |
| Botões primários em preto (monocromático) | Perderia a cor da marca, que é reconhecível e tem bom contraste. |
| Texto corrido em peso 400 | A medição de contraste dos testes (`textContrastGuideline`) usa uma imagem em 1x e, com hastes finas, mede o serrilhado no lugar da cor do texto: reprova textos com contraste real acima de 6:1. Em 500 a leitura continua leve e a medição é estável. |
| Trocar a fonte (Inter ou a do sistema) | Mais uma mudança de identidade sem ganho claro: a Manrope com pesos menores resolve. |

## Consequências

- As capturas de referência mudaram em todas as telas, nos dois temas.
- Testes que procuravam sobretítulos em caixa alta passaram a procurar o texto em caixa normal.
- Restrições da medição de contraste viram regra da escala: textos de até 13 pontos usam 600, e
  rótulos curtos de chips usam 700.
- `Tone.background` e os papéis `*Container` ficam para o raro painel que precisa se destacar
  como bloco (e para a seleção de chips); componentes novos não devem usar fundo de tom.
- A validação em aparelhos reais continua pendente (ver `docs/07-testes.md`).
