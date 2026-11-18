# Arquitetura de informação

Como as funcionalidades se organizam em telas e fluxos nos dois perfis. As telas seguem os
padrões do [Design System](design-system.md).

## Princípios

1. **A pergunta mais comum responde na primeira tela.** Responsável: "como está a criança agora
   e quanto tempo falta?". Criança: "quanto tempo eu tenho e o que posso usar?".
2. **No máximo dois toques até uma configuração.** Aba Regras → grupo de regras → editor.
3. **O contexto sempre visível.** Toda tela de regras, relatório e aparelho mostra de qual
   criança e de qual aparelho se trata.
4. **O mesmo caminho para o mesmo assunto.** Tempo extra fica no painel (ação rápida) e nos
   pedidos de tempo (alertas); limites ficam em Regras. Não há duas telas diferentes para
   editar a mesma regra.

## Responsável

```text
Boas-vindas ── escolha do perfil
Porta de entrada ── Criar conta ── Chave de recuperação ── Painel
                └── Entrar ── Painel
                └── Recuperar acesso
Painel bloqueado (senha) ── volta para onde estava

Painel (5 abas)
├── Início        criança e aparelho, tempo de hoje, ações rápidas (tempo extra, pausar,
│                 suspender regras), mais usados, alertas recentes, nível de proteção
├── Regras        visão geral com o estado de aplicação no aparelho
│   ├── Limite diário
│   ├── Horários permitidos
│   ├── Períodos de bloqueio
│   ├── Aplicativos ── folha do app (bloquear, liberar, limite próprio)
│   ├── Exceções e funções essenciais
│   ├── Navegação na internet
│   └── Proteção
├── Relatórios    resumo do período, gráficos, tabela
│   ├── Linha do tempo do dia
│   ├── Eventos
│   └── Histórico de navegação
├── Alertas       central de alertas, pedidos de tempo, preferências de aviso
└── Mais          cabeçalho da conta e grupos: Aparelhos (lista, vincular), Alertas
                  (preferências, pedidos de tempo), Conta e segurança (conta, sessões, bloqueio
                  do painel, senha), Dados (privacidade, auditoria) e Sobre; sair da conta com
                  confirmação
```

Aparelhos e vinculação ficam acessíveis pelo Início (quando não há aparelho) e por Mais.

## Criança

```text
Entrada (consulta o vínculo)
├── sem vínculo ── Vincular este aparelho (código) ── espera da confirmação
├── recém-vinculado ── O que este app faz (transparência) ── Permissões
└── vinculado e pronto
    Início        tempo para usar hoje, pedir mais tempo, pedidos feitos, uso de hoje,
                  sempre liberados, regras de hoje, responsável e sincronização
    ├── O que este app faz e o que ele não vê
    ├── Permissões do controle
    ├── Área do responsável (senha do responsável no aparelho)
    └── Navegador seguro (motor próprio)

Tela de bloqueio (nativa): motivo, quando volta, o que continua liberado, pedir tempo ou
liberação, chamada de emergência.
```

A criança vê as regras e o motivo de cada restrição, pode pedir tempo e falar com o
responsável, mas nenhuma tela do perfil infantil desativa ou contorna as regras.
