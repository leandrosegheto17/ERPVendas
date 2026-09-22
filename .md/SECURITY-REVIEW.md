# SECURITY-REVIEW — ERP Vendas (Delphi)

Produzido pelo Validador (chapéu DevSecOps), depois da aprovação funcional
do chapéu QA (`QA-REPORT.md`, Lote 1: Aprovado). Base: `SDD.md` Seção 7
(Requisitos de Segurança), `GUARDRAILS.md` (regras 11-19), `PRD-TECNICO.md`.

## Lote 1 — Ambiente e infraestrutura externa (D1)

Escopo aplicável a este lote (sem código Delphi ainda): segredo/credencial
commitado (GUARDRAILS regra 16), exposição de dado pessoal em dado de demo
(regra 18), integridade dos artefatos de dados que servirão de 2ª barreira
para validação futura (regra 11/12), e consistência do que já foi
documentado sobre segurança operacional para as tarefas futuras.

### 1. Varredura de segredo/credencial commitado (GUARDRAILS regra 16)

Varredura por padrão de senha/host/token/chave/masterkey em todos os
artefatos produzidos pelo lote:

| Artefato | Resultado |
|---|---|
| `db/01_schema.sql` | Nenhuma credencial real. Menções a `SYSDBA`/`-password <senha>` são só comentário de exemplo de como *invocar* o `isql` externamente (placeholder `<senha>`, não valor real) — conforme já indicado pela própria nota de implementação de T03. Sem `CONNECT`/`CREATE DATABASE` embutido. |
| `db/02_seed.sql` | Idem acima; nenhuma credencial embutida; nenhuma linha de conexão. |
| `tools/mock-financeiro/mock_financeiro.py` | Nenhum segredo; servidor local (`127.0.0.1` padrão) sem autenticação no `_modo` — README já documenta essa limitação e recomenda não expor fora de localhost/rede de dev (adequado para ferramenta de desenvolvimento, ADR-009, fora do pacote de entrega). |
| `tools/mock-financeiro/README.md` | Nenhum segredo. |
| `docs/contrato-api-financeiro.md` | Nenhuma credencial; `X-Api-Key` tratado apenas como conceito (header opcional), sem valor de exemplo real. |
| `docs/ambiente-licencas.md` | Nenhuma chave de licença/número de série. Seção 10 do próprio arquivo já autodeclara essa confirmação; conferido de fato: nenhuma ocorrência de chave/serial nas ~470 linhas do arquivo — só nomes de arquivo de licença (`RB Professional (Trial) License.txt`) e texto de limitação, nunca o conteúdo secreto. Placeholders de senha em exemplos de código (`'<senha do painel>'`, `'<usuario do painel>'`) explicitamente marcados como não-reais, com nota "nunca commitar; só em INI/env, ADR-007/008". |

**Achado**: nenhum. Regra 16 respeitada em todos os artefatos do lote.

### 2. Exposição de dados sensíveis (GUARDRAILS regra 17/18, `sensitive-data-exposure-check`)

- `db/02_seed.sql`: dados pessoais (nome, CPF/CNPJ, endereço, telefone,
  e-mail) presentes, mas **claramente fictícios** (nomes "Exemplo",
  domínios `@example.com`/`@mailtrap-sandbox.test`) — conforme GUARDRAILS
  regra 18 ("dados de demo fictícios"). Não é exposição real de dado de
  titular.
- `tools/mock-financeiro/mock_financeiro.py`: log (`log_message`) registra
  apenas método/rota/status, sem corpo de requisição/resposta — não grava
  CPF/CNPJ, valores ou qualquer dado pessoal em log, alinhado à regra 17
  (ainda que a regra 17 seja escrita pensando no log da aplicação Delphi
  futura, o mock já nasce alinhado ao mesmo princípio).
- `docs/contrato-api-financeiro.md`: confirma que ao Financeiro só trafegam
  IDs, valores e itens — nenhum dado pessoal no payload de integração,
  conforme SDD.md §7 e GUARDRAILS regra 18.

**Achado**: nenhum.

### 3. Integridade/2ª barreira de dados (GUARDRAILS regra 11/12, SDD §7 "Injeção/integridade")

- `db/01_schema.sql` implementa CHECK/UNIQUE/FK como segunda barreira
  (`CK_VENDAS_STATUS`, `CK_ITENS_QTD`, `CK_PRODUTOS_PRECO`,
  `CK_CLIENTES_TIPO`, `CK_FILA_TIPO`, `CK_FILA_STATUS`, `UQ_CLIENTES_DOC`),
  consistente com a exigência de que validação de Service não seja a única
  barreira. `NUMERIC(15,2)` em todo valor monetário (nunca `Double`/`Float`),
  atendendo à regra 12. FK com `ON DELETE CASCADE` restrito a
  `VENDA_ITENS -> VENDAS` (não em cascata para CLIENTES/PRODUTOS, coerente
  com a regra de inativação em vez de exclusão física da regra 19 — a ser
  implementada em Service no Lote 6).

**Achado**: nenhum.

### 4. Compliance (LGPD básica, SDD §7)

- Seed com CPF/CNPJ de teste (dígitos verificadores válidos, mas titulares
  fictícios) e e-mails de sandbox — sem coleta de dado real de titular.
  Conforme.
- Nenhuma tarefa deste lote envolve tratamento de dado pessoal real (ainda
  não há aplicação rodando); compliance obrigatório aplicável a este lote
  está atendido.

**Achado**: nenhum compliance obrigatório em aberto.

### 5. Requisitos de segurança operacional para o próprio chapéu DevOps (preparação adiantada)

Registrado aqui para uso do próprio Validador (chapéu DevOps) quando
`infrastructure-as-code-provisioning`/`cicd-pipeline-configuration` rodar:

- Gestão de secrets: `erpvendas.ini` (real) nunca deve entrar em
  repositório nem em pipeline de CI/CD; usar variável de ambiente/secret
  manager do ambiente de deploy para senha SMTP/ApiKey (já é a diretriz do
  `TASK.md` Seção 1 e GUARDRAILS regra 16 — DevOps só precisa herdar, não
  criar exceção).
- `.gitignore` atual (raiz) ainda não lista `erpvendas.ini`/`*.FDB`/pasta de
  log/PDF temp — isso é esperado só a partir de T07 (Lote 2, esqueleto do
  projeto Delphi, que cria essas pastas); **não é achado deste lote**, só
  fica anotado aqui para o Validador conferir de novo na validação do
  Lote 2 (a Seção 1 do `TASK.md` já lista isso como parte do critério de
  aceite de T07).
- Mock do Financeiro (`tools/mock-financeiro/`) é ferramenta de dev/demo,
  fora do pacote de produção (ADR-009) — não deve ser incluído em nenhum
  artefato de deploy/build de produção; DevOps deve garantir que o
  pipeline de build (T61) não empacote a pasta `tools/`.

### 6. Achados de relevância estratégica (sinalização ao Gestor)

Nenhum achado deste lote atinge o critério de relevância estratégica
(nenhuma decisão de negócio/compliance em aberto). Os 3 riscos não
bloqueantes de T01 (runtime packages do DevExpress para T61, validade do
trial, milissegundos do `THTTPClient`) são de natureza técnica/operacional,
já documentados e rastreáveis em `docs/ambiente-licencas.md` — não exigem
decisão de negócio agora; serão revisitados quando T34/T61 forem
executadas.

### Veredito do lote (chapéu DevSecOps)

**Aprovado**, sem achado de severidade alta/crítica nem compliance
obrigatório em aberto, e sem débito registrado. Libera o lote para o
fechamento estrutural e, quando decidido pelo usuário, para `/deploy`
(quando aplicável — este lote não contém código executável a publicar; a
preparação de infraestrutura/CI-CD segue o timing padrão de `validador.md`,
assim que o `SDD.md`/próximos lotes com código estiverem prontos).
