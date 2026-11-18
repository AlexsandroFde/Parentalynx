# Avaliação de usabilidade por funcionalidade

Avaliação heurística das telas do ParentaLynx com as 10 heurísticas de Jakob Nielsen, feita
durante a implantação do Design System ([../design/design-system.md](../design/design-system.md)).
Cada arquivo desta pasta cobre uma funcionalidade: o que foi avaliado, os problemas encontrados
e como foram resolvidos.

## Método

1. Cada tela foi revisada nos estados que ela tem (carregando, conteúdo, vazio, erro, operação
   em andamento, sucesso), nos temas claro e escuro, com fonte normal e com fonte 2×.
2. Cada problema recebeu a heurística violada e uma gravidade:
   - **Alta**: impede ou engana (por exemplo, mostrar como aplicada uma regra que o aparelho
     não confirmou).
   - **Média**: atrapalha ou confunde, mas a pessoa consegue seguir.
   - **Baixa**: acabamento, consistência.
3. A correção foi feita na tela ou no Design System e conferida por teste (comportamento,
   captura de referência, acessibilidade ou fonte ampliada).
4. Pontos que dependem de validação em aparelho real ficaram marcados como pendentes.

## Heurísticas

| Nº | Heurística | Pergunta usada na revisão |
| --- | --- | --- |
| H1 | Visibilidade do estado do sistema | A pessoa sabe o que está acontecendo agora e se a mudança já vale no aparelho? |
| H2 | Correspondência com o mundo real | As palavras e os ícones são os de quem usa, sem termos internos? |
| H3 | Controle e liberdade | Dá para cancelar, voltar, desfazer ou corrigir? |
| H4 | Consistência e padrões | O mesmo conceito tem a mesma aparência e o mesmo comportamento em todo o app? |
| H5 | Prevenção de erros | A tela evita o erro antes de ele acontecer (valores válidos, confirmação, sem toque duplo)? |
| H6 | Reconhecimento em vez de memorização | O contexto (criança, aparelho, regra atual) está visível? |
| H7 | Flexibilidade e eficiência | Há atalhos para o uso frequente sem complicar o uso eventual? |
| H8 | Estética e minimalismo | Só o necessário, com hierarquia clara? |
| H9 | Reconhecer, diagnosticar e recuperar erros | A mensagem diz o que houve, o que foi salvo e o que fazer? |
| H10 | Ajuda e documentação | A explicação aparece onde e quando é útil? |

## Modelo de cada arquivo

```markdown
# <Funcionalidade>

Telas: <lista>. Perfil: responsável | criança.

## Heurísticas consideradas
<para cada heurística relevante, uma linha com como a tela atende>

## Problemas encontrados e soluções
| # | Tela | Problema | Heurística | Gravidade | Solução | Verificação |
| --- | --- | --- | --- | --- | --- | --- |

## Pendências
<o que depende de aparelho real ou de outra funcionalidade>
```

## Índice

| Funcionalidade | Arquivo | Problemas resolvidos | Gravidade alta |
| --- | --- | --- | --- |
| Acesso, configurações e primeiro uso | [acesso-e-configuracoes.md](acesso-e-configuracoes.md) | 52 | 2 |
| Painel, aparelhos e vinculação | [painel-e-aparelhos.md](painel-e-aparelhos.md) | 41 | 2 |
| Regras | [regras.md](regras.md) | 47 | 5 |
| Relatórios e alertas | [relatorios-e-alertas.md](relatorios-e-alertas.md) | 40 | 3 |
| Experiência da criança e navegador gerenciado | [crianca.md](crianca.md) | 33 | 1 |
| Design System e tela de bloqueio nativa | [design-system.md](design-system.md) | 14 | 2 |
| **Total** | | **227** | **15** |

Os problemas de gravidade alta eram, em geral, de visibilidade do estado (H1) e de prevenção
de erros (H5): regras mostradas como aplicadas antes da confirmação do aparelho, vinculação
aprovada sem comparar o número de confirmação, retenção de histórico encurtada sem aviso e uma
falha de conexão ao excluir a conta que parecia senha errada. Todos foram corrigidos e têm
teste.
