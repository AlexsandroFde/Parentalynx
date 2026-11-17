# Privacidade, segurança e proteção de dados

O ParentaLynx trata dados de crianças e adolescentes. Este documento descreve quais dados são
tratados, para quê, onde ficam, por quanto tempo e como são protegidos, e relaciona as decisões do
projeto com a LGPD (Lei 13.709/2018).

> Este documento é técnico. Ele não substitui orientação jurídica. Quem for operar o serviço para
> outras famílias deve validar a conformidade com um profissional habilitado.

## 1. Princípios adotados

1. **Melhor interesse da criança.** O controle serve para limitar tempo e proteger, não para
   vigiar. O que não é necessário para isso não é coletado.
2. **Transparência com a criança.** O aplicativo nunca fica escondido: o ícone permanece no
   launcher, há uma notificação permanente no aparelho monitorado, e a tela inicial da criança
   mostra as regras em vigor, o que é coletado e quem é o responsável. Não existe modo oculto.
3. **Minimização.** Só são coletados dados de uso de aplicativos e, opcionalmente, o histórico do
   navegador gerenciado. A lista do que não é coletado está na seção 3.
4. **Controle do responsável.** O responsável vê tudo o que é coletado, define a retenção, exporta
   e apaga os dados quando quiser.
5. **Segurança desde o projeto.** Senhas com Argon2id, tokens guardados só como hash, tráfego por
   HTTPS, campos sensíveis cifrados em repouso, auditoria das ações administrativas.

## 2. Dados tratados

### 2.1 Conta do responsável

| Dado | Finalidade | Onde fica | Retenção |
| --- | --- | --- | --- |
| Nome de exibição | Identificar o responsável para a criança e nas telas | Servidor | Até excluir a conta |
| E-mail | Identificador de login. Não é usado para envio de mensagens | Servidor | Até excluir a conta |
| Senha administrativa | Autenticação | Servidor, só o resumo Argon2id | Até trocar ou excluir |
| Chave de recuperação | Recuperar o acesso | Servidor, só o resumo | Até gerar outra ou excluir |
| Sessões (nome do aparelho, IP, datas) | Segurança e lista de aparelhos conectados | Servidor | Até expirar ou revogar |
| Registro de auditoria | Rastrear alterações administrativas | Servidor | 365 dias |

### 2.2 Aparelho monitorado

| Dado | Finalidade | Onde fica | Retenção padrão |
| --- | --- | --- | --- |
| Nome da criança (livre, pode ser apelido) | Identificar o aparelho no painel | Servidor | Até apagar o aparelho |
| Modelo, fabricante, versão do Android, fuso | Suporte e cálculo do dia | Servidor | Até apagar o aparelho |
| Identificador do aparelho (resumo SHA-256 do `ANDROID_ID`) | Reconhecer o mesmo aparelho em uma nova vinculação | Servidor | Até apagar o aparelho |
| Lista de apps instalados (nome, pacote, categoria, ícone) | Permitir que o responsável escolha o que liberar | Servidor | Até apagar o aparelho |
| Sessões de uso (app, início, fim) | Contagem de tempo e relatórios | Aparelho até sincronizar, depois servidor | 90 dias |
| Totais diários de uso | Limite diário e relatórios | Aparelho (35 dias) e servidor | 400 dias |
| Eventos (bloqueios, tentativas, limite atingido, permissões, relógio, reinicialização) | Alertas e relatórios | Servidor | 90 dias |
| Estado atual (app em primeiro plano, tela ligada, bateria, permissões) | Painel em tempo real | Servidor, só o último retrato | Substituído a cada sincronização |
| Pedidos de tempo adicional e a mensagem opcional | Fluxo de pedido e resposta | Servidor | 90 dias |
| Histórico do navegador gerenciado (endereço, título, horário, se foi bloqueado) | Relatório de navegação, se o responsável deixar ligado | Servidor, cifrado | 90 dias |

A retenção de 90 dias é configurável pelo responsável entre 30 e 365 dias.

## 3. O que não é coletado

O aplicativo não coleta e não tem meios técnicos de acessar:

- o que é digitado (não há registro de teclas);
- senhas e credenciais;
- conteúdo de mensagens, de e-mails ou de qualquer tela;
- capturas ou gravação de tela;
- áudio, câmera, fotos e arquivos;
- localização;
- contatos e registro de chamadas;
- a navegação feita em outros navegadores ou dentro de outros apps.

O serviço de acessibilidade é declarado sem permissão de ler o conteúdo das janelas
(`canRetrieveWindowContent="false"`) e recebe apenas o aviso de troca de janela, usado para saber
qual app está aberto.

## 4. Compartilhamento com terceiros

Por padrão não há nenhum. O backend é hospedado por quem opera o serviço e não envia dados a
terceiros. Não há publicidade, análise de uso nem SDKs de rastreamento.

Exceção opcional, controlada pelo responsável: com o **filtro DNS familiar** ligado, os nomes de
domínio abertos no navegador gerenciado são consultados no resolvedor Cloudflare for Families
(`family.cloudflare-dns.com`). No modo Device Owner, o mesmo resolvedor passa a atender todo o
tráfego DNS do aparelho. O resolvedor recebe nomes de domínio e o endereço IP de origem, não a
identidade da criança. Desligar o filtro encerra esse envio.

## 5. Segurança

| Medida | Implementação |
| --- | --- |
| Tráfego cifrado | HTTPS. O build de produção do app recusa conexões sem TLS |
| Senhas | Argon2id (19 MiB, 2 passagens), nunca gravadas nem registradas em log |
| Tokens | Aleatórios de 256 bits. O servidor guarda só o SHA-256 |
| Tokens no aparelho | Cifrados com AES-256-GCM e chave não exportável do Android Keystore |
| Dados no aparelho | Área privada do app, sob a criptografia de arquivos do Android. Backup do sistema desligado |
| Campos sensíveis no servidor | Endereços e títulos de navegação, detalhes de eventos e o segredo do código offline cifrados com AES-256-GCM |
| Controle de acesso | Cada rota verifica que o aparelho pertence à conta autenticada |
| Operações administrativas | Exigem senha confirmada recentemente (elevação) |
| Força bruta | Bloqueio progressivo por conta e por aparelho, limite por IP |
| Vinculação | Código de uso único com validade de 15 minutos e confirmação no aparelho do responsável |
| Revogação | O responsável revoga aparelhos e sessões. O aparelho revogado desativa o controle |
| Auditoria | Toda alteração de regra, vínculo, senha e exclusão fica registrada |

Limites conhecidos: o servidor consegue ler os dados que guarda (não há criptografia de ponta a
ponta), então a segurança depende de quem o hospeda. A chave de cifra dos campos sensíveis fica em
variável de ambiente e deve ser guardada fora do backup do banco.

## 6. Direitos e como exercê-los no aplicativo

| Direito (LGPD, art. 18) | Como |
| --- | --- |
| Confirmação e acesso | Painel, relatórios e a tela "Dados e privacidade" |
| Correção | Editar nome do responsável e da criança |
| Portabilidade | Exportar os dados do aparelho em JSON (tela do aparelho) |
| Eliminação | Apagar o histórico de um aparelho, apagar o aparelho ou excluir a conta inteira |
| Informação sobre compartilhamento | Seção 4 deste documento e a tela "Dados e privacidade" |
| Revogação do consentimento | Desvincular o aparelho ou excluir a conta |

A exclusão é imediata no banco de dados. Cópias de segurança feitas por quem hospeda o servidor
seguem a política de backup dessa pessoa ou organização.

## 7. Relação com a LGPD

- **Uso doméstico.** O tratamento feito por pessoa natural para fins exclusivamente particulares
  e não econômicos está fora do alcance da LGPD (art. 4º, I). É o caso de uma família que hospeda
  o próprio servidor.
- **Operação para terceiros.** Quando uma organização oferece o serviço a outras famílias, ela é
  agente de tratamento e a lei se aplica por inteiro, com atenção ao art. 14: tratamento no melhor
  interesse da criança, consentimento específico e em destaque de um dos pais ou do responsável
  legal, informação clara e acessível sobre os dados coletados, e proibição de exigir mais dados do
  que o necessário.
- **Princípios do art. 6º** e onde aparecem no projeto: finalidade e adequação (seção 2),
  necessidade (seção 3), livre acesso e transparência (painel e tela da criança), segurança e
  prevenção (seção 5), responsabilização (auditoria).
- **Outras normas.** O Estatuto da Criança e do Adolescente e a legislação recente sobre proteção
  de crianças e adolescentes em ambientes digitais tratam de supervisão parental e de
  transparência. O projeto adota como princípio que a criança sempre sabe que o controle está
  ativo e quais regras valem. A verificação formal de conformidade cabe a quem opera o serviço.

### 7.1 Lista para quem vai operar o serviço para outras famílias

- [ ] Política de privacidade publicada, em linguagem simples, com versão adequada à criança.
- [ ] Registro do consentimento do responsável legal no cadastro.
- [ ] Encarregado pelo tratamento de dados indicado e canal de contato divulgado.
- [ ] Relatório de impacto à proteção de dados pessoais, dado o público infantil.
- [ ] Servidor e backups em local com garantias adequadas. Avaliar transferência internacional se
      a hospedagem ou o resolvedor DNS estiverem fora do país.
- [ ] Procedimento de resposta a incidentes, com comunicação à ANPD e aos titulares quando couber.
- [ ] Rotina de backup cifrado e teste de restauração.
- [ ] Revisão das permissões declaradas no Google Play (acessibilidade, consulta de todos os
      pacotes, uso de estatísticas), com as declarações e a divulgação destacada que a loja exige.

## 8. O que o aplicativo mostra a cada pessoa

- **À criança:** que o controle está ativo, o nome do responsável, o tempo restante, as regras em
  vigor, o motivo de cada bloqueio e o horário de liberação, a lista do que é coletado e do que
  não é, e o aviso de que o histórico do navegador gerenciado é visto pelo responsável.
- **Ao responsável:** tudo o que foi coletado, o modo de gerenciamento do aparelho com o que é e
  o que não é garantido nele, o estado de cada permissão, e a tela "Dados e privacidade" com a
  retenção, a exportação e a exclusão.
