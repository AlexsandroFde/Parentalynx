# ADR 0002: Identidade visual própria e Design System "Lince"

- **Status:** aceito
- **Data:** 17/11/2026
- **Relacionado:** [ADR 0001](0001-bloc-clean-architecture.md) (arquitetura), diretriz de UI/UX
  com as 10 heurísticas de Nielsen

## Contexto

A interface usava o tema Material 3 gerado a partir de uma cor (índigo), a fonte padrão e um
cartão com borda para cada bloco de conteúdo. Funcionava, mas tinha aparência de template, sem
identidade, com ações secundárias que pareciam desabilitadas e com a tela da criança igual ao
painel do responsável. A diretriz de UI/UX exige identidade própria, um Design System
centralizado e documentado, as 10 heurísticas aplicadas aos fluxos, temas claro e escuro,
acessibilidade e experiências distintas para responsável e criança.

## Decisão

1. **Design System próprio em `app/lib/shared/design_system/`**, com tokens (cores,
   tipografia, espaçamentos, raios, elevação, movimento, opacidade, dimensões), temas, fundações
   (ícones, tom, marca) e componentes. As telas importam só `design_system.dart`. Documentação em
   [../design/design-system.md](../design/design-system.md).
2. **Identidade "Lince — atenção serena"**: petróleo como marca e cor de ação, neutros de areia,
   âmbar só no logotipo, anil para descanso (nunca vermelho para restrições combinadas), símbolo
   do lince. Pesquisa e justificativa em
   [../design/pesquisa-e-conceito.md](../design/pesquisa-e-conceito.md).
3. **Manrope embutida** (OFL 1.1) em vez de baixada em tempo de execução: identidade tipográfica
   sem rede e sem expor dados a terceiros; algarismos tabulares para tempos.
4. **Perfis pelo tema**: o mesmo conjunto de componentes atende aos dois perfis;
   `AppExperienceScope` aplica as formas e a escala de texto da criança.
5. **Regras conferidas por teste** (`test/architecture/design_system_test.dart`): sem cores,
   estilos de texto, ícones, espaçamentos e raios soltos, e sem os componentes do Material
   diretamente nas telas.
6. **Catálogo com capturas** (`test/shared/design_system/catalog_test.dart`) nos dois temas e
   perfis, com as diretrizes de acessibilidade do Flutter e fonte 2×.
7. **Fonte até 2×** (o máximo do Android), em vez do limite anterior de 1,6×.
8. **Tela de bloqueio nativa e ícone do app** alinhados à identidade (cores dos tokens, Manrope
   como recurso de fonte do Android, textos não punitivos).

## Alternativas avaliadas

| Alternativa | Por que não |
| --- | --- |
| Manter o Material 3 padrão com uma cor de marca | Continua com aparência de template; a diretriz pede identidade própria. |
| `google_fonts` | Baixa as fontes em tempo de execução: depende de rede e envia requisições a terceiros a partir de um app de controle parental. |
| Biblioteca de componentes de terceiros | Traria outra linguagem visual e mais dependência; os componentes necessários são poucos e simples. |
| Dois Design Systems (um por perfil) | Duplicaria componentes e quebraria a consistência; a diferença entre os perfis cabe no tema. |

## Consequências

- Uma mudança de token vale para o app inteiro; o teste de regras impede que telas novas fujam
  dos tokens.
- As capturas de referência mudaram em todas as telas e passaram a existir no tema escuro.
- O APK cresce com a fonte embutida (cerca de 480 KB no Flutter e 290 KB no recurso nativo).
- A avaliação heurística por funcionalidade fica em [../usabilidade/](../usabilidade/README.md).
- A validação em aparelhos reais continua pendente (ver `docs/07-testes.md`).
