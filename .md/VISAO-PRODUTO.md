# VISAO-PRODUTO — ERP Vendas (Delphi)

> Desafio técnico CartSys · Programador Delphi e C# Sênior/Especialista
> Autor: Leandro Segheto Moraes · Versão do plano: 0.1 (fase de planejamento — sem código)
> Base: `Documento_de_Visao_ERP_Vendas_Delphi.pdf` v1.0 (21/09/2026) + briefing da sessão.

**Legenda usada em todo o documento**

| Marca | Significado |
|---|---|
| **[OBR]** | Requisito explícito do desafio (caixa azul do PDF) |
| **[SUG]** | Sugestão adicional do autor (caixa âmbar do PDF) |
| **[DEC]** | Decisão em aberto — precisa de validação (ver seção 8) |

---

## 1. Visão e escopo

O **ERP Vendas** é uma aplicação desktop Delphi para cadastro de clientes, produtos e vendas, emissão do relatório de confirmação de pedido e envio automático desse relatório por e-mail após a quitação. Ele **consome** a API REST do **ERP Financeiro (C#)**, que é quem quita/cancela a venda e devolve o status.

**Dentro do escopo:** CRUD de Clientes, Produtos e Vendas · relatório de confirmação (ReportBuilder) · e-mail automático pós-quitação · integração REST com o Financeiro.

**Fora do escopo:** autenticação/multiusuário · controle avançado de estoque · emissão fiscal (NF-e/NFC-e).

**Stack obrigatória [OBR]:** Delphi 13 / 12.x / 10.3 · FireDAC · Firebird 3.0 ou SQL Server 2020/2022 · DevExpress VCL · ReportBuilder · API REST (JSON).

**Critérios de avaliação:** padrão de desenvolvimento, linha de raciocínio, boas práticas, maturidade técnica. → Consequência prática: a separação em camadas e a documentação das decisões (este arquivo, ADRs curtos) pesam mais do que quantidade de telas.

### Fluxo principal

```
Cadastrar venda (status Pendente)
   └─ Confirmar ─► POST /api/vendas/quitacao ─► Financeiro
                      ├─ 200 "Quitada" ─► atualiza venda local ─► gera PDF ─► envia e-mail
                      ├─ falha/timeout  ─► venda permanece Pendente + item na fila de reenvio + msg clara
                      └─ recusa (4xx)   ─► msg ao usuário, venda permanece Pendente   [DEC-08]
   └─ Cancelar ─► POST /api/vendas/cancelamento ─► "Cancelada" ─► atualiza venda local
```

### Regras de negócio propostas (a validar)

| Regra | Origem |
|---|---|
| Venda nasce `Pendente`; só `Pendente` pode ser editada/excluída | [SUG] coerente com §4.3 do PDF |
| Venda `Quitada`/`Cancelada` é somente leitura | [SUG] |
| Venda exige cliente ativo e ≥ 1 item; quantidade > 0; produto ativo | [SUG] |
| `valorTotal` = Σ(quantidade × preço unitário) — calculado no servidor de regras, nunca digitado | [SUG] |
| Preço unitário do item é **copiado** do produto no momento da venda (snapshot) | [SUG] |
| Cliente/Produto com vendas vinculadas não é excluído fisicamente → inativado | [SUG] |
| E-mail só é disparado após confirmação de quitação pelo Financeiro | **[OBR]** |
| Falha de e-mail/Financeiro nunca trava o fluxo; fica registrada para reenvio | [SUG] |

---

## 2. Arquitetura e estrutura de pastas

Três camadas + núcleo transversal. Regra de dependência: **UI → Negócio → (Interfaces do Domínio) ← Dados/Integração**. O Negócio só conhece *interfaces*; FireDAC, HTTP e SMTP ficam atrás delas.

```
ERPVendas/
├─ VISAO-PRODUTO.md
├─ README.md                      # instalação, configuração, dependências   [OBR entregável]
├─ docs/
│  ├─ contrato-api-financeiro.md  # contrato + histórico de mudanças (fonte única com o lado C#)
│  ├─ decisoes.md                 # ADRs curtos (DEC-xx resolvidas)
│  └─ roteiro-testes-manuais.md   # [SUG]
├─ db/
│  ├─ 01_schema.sql               # DDL Firebird 3.0
│  ├─ 02_seed.sql                 # dados de exemplo p/ demonstração
│  └─ ERPVENDAS.FBK               # backup do banco                           [OBR entregável]
├─ config/
│  └─ erpvendas.ini.example       # conexão, URL do Financeiro, timeout, SMTP (o .ini real fica no .gitignore)
├─ src/
│  ├─ ERPVendas.dpr / .dproj
│  ├─ App/                        # composition root (monta dependências), Main form
│  ├─ Core/                       # transversal
│  │   ├─ ERPV.Core.Config        # leitura do INI
│  │   ├─ ERPV.Core.Log           # log técnico em arquivo
│  │   ├─ ERPV.Core.Erros         # hierarquia de exceções + tradutor p/ mensagem amigável
│  │   └─ ERPV.Core.Validadores   # CPF/CNPJ, e-mail
│  ├─ Dominio/                    # sem dependência de VCL/FireDAC
│  │   ├─ Entidades               # TCliente, TProduto, TVenda, TVendaItem
│  │   ├─ Enums                   # TStatusVenda, TTipoFila
│  │   └─ Contratos               # IClienteRepository, IProdutoRepository, IVendaRepository,
│  │                              # IFilaRepository, IFinanceiroGateway, IEmailSender, IRelatorioPedido
│  ├─ Negocio/                    # regras (serviços) — usa só interfaces
│  │   ├─ ClienteService / ProdutoService / VendaService
│  │   ├─ QuitacaoService         # orquestra: Financeiro → status local → PDF → e-mail
│  │   └─ FilaService             # reprocessa itens pendentes
│  ├─ Dados/                      # FireDAC atrás de Repository
│  │   ├─ ERPV.Dados.Conexao      # TFDConnection, transações, script de conexão via INI
│  │   └─ *Repository             # implementações das interfaces
│  ├─ Integracao/
│  │   ├─ FinanceiroClient        # implementa IFinanceiroGateway (HTTP + JSON)
│  │   ├─ FinanceiroDTOs          # records/classes do contrato
│  │   └─ EmailSender             # implementa IEmailSender (SMTP)
│  ├─ Relatorios/                 # ReportBuilder: layout + geração de PDF
│  └─ UI/                         # forms DevExpress finos: só coletam/exibem, chamam Services
│      ├─ Cadastros (Cliente, Produto)
│      ├─ Venda (lista + edição mestre/detalhe)
│      └─ Fila (pendências de integração/e-mail)
├─ tools/
│  └─ mock-financeiro/            # servidor fake do contrato p/ desenvolver sem o C#   [DEC-06]
└─ bin/                           # executável + DLLs (fbclient, OpenSSL) no pacote final
```

**Decisões de padrão (propostas):**
- DI manual via composition root (sem framework de DI — zero dependência extra).
- Repositórios devolvem **entidades** para edição e **`TDataSet` somente-leitura (TFDMemTable/TFDQuery)** para alimentar cxGrid/relatório; evita mapear milhares de linhas só para exibir grade. [DEC-10]
- Unit scopes com prefixo `ERPV.<Camada>.<Nome>`.
- Forms nunca contêm SQL nem chamada HTTP.
- Exceções: hierarquia própria (`EValidacao`, `ERegraNegocio`, `EIntegracao`, `EInfra`); um único handler (`Application.OnException`) traduz para mensagem amigável e grava o detalhe técnico em log. [SUG]

---

## 3. Modelo de dados inicial (Firebird 3.0)

Banco **segregado** do Financeiro (cada módulo tem o seu; a única ponte é a API). Charset UTF8. `ID` serve como "Código" exibido ao usuário e como identificador string no contrato (`vendaId = "42"`). [DEC-03] [DEC-05]

```sql
CREATE TABLE CLIENTES (
  ID              INTEGER GENERATED BY DEFAULT AS IDENTITY,
  NOME            VARCHAR(120)  NOT NULL,          -- Nome / Razão Social
  TIPO_PESSOA     CHAR(1)       NOT NULL,          -- 'F' | 'J'
  CPF_CNPJ        VARCHAR(14)   NOT NULL,          -- somente dígitos
  ENDERECO        VARCHAR(200),
  TELEFONE        VARCHAR(20),
  EMAIL           VARCHAR(120)  NOT NULL,          -- destino do relatório
  ATIVO           BOOLEAN       DEFAULT TRUE NOT NULL,
  DATA_CADASTRO   TIMESTAMP     DEFAULT CURRENT_TIMESTAMP NOT NULL,
  CONSTRAINT PK_CLIENTES PRIMARY KEY (ID),
  CONSTRAINT UQ_CLIENTES_DOC UNIQUE (CPF_CNPJ),
  CONSTRAINT CK_CLIENTES_TIPO CHECK (TIPO_PESSOA IN ('F','J'))
);

CREATE TABLE PRODUTOS (
  ID              INTEGER GENERATED BY DEFAULT AS IDENTITY,
  DESCRICAO       VARCHAR(120)  NOT NULL,
  UNIDADE         VARCHAR(6)    NOT NULL,          -- UN, KG, CX...
  PRECO_UNITARIO  NUMERIC(15,2) NOT NULL,
  CATEGORIA       VARCHAR(60),
  ATIVO           BOOLEAN       DEFAULT TRUE NOT NULL,
  CONSTRAINT PK_PRODUTOS PRIMARY KEY (ID),
  CONSTRAINT CK_PRODUTOS_PRECO CHECK (PRECO_UNITARIO >= 0)
);

CREATE TABLE VENDAS (
  ID                   INTEGER GENERATED BY DEFAULT AS IDENTITY,   -- "Número da Venda"
  CLIENTE_ID           INTEGER       NOT NULL,
  DATA_VENDA           TIMESTAMP     DEFAULT CURRENT_TIMESTAMP NOT NULL,
  VALOR_TOTAL          NUMERIC(15,2) DEFAULT 0 NOT NULL,
  STATUS               VARCHAR(10)   DEFAULT 'Pendente' NOT NULL,  -- mesmos literais do contrato
  DATA_QUITACAO        TIMESTAMP,                                  -- vem do Financeiro
  MOTIVO_CANCELAMENTO  VARCHAR(255),
  CONSTRAINT PK_VENDAS PRIMARY KEY (ID),
  CONSTRAINT FK_VENDAS_CLIENTE FOREIGN KEY (CLIENTE_ID) REFERENCES CLIENTES (ID),
  CONSTRAINT CK_VENDAS_STATUS CHECK (STATUS IN ('Pendente','Quitada','Cancelada'))
);

CREATE TABLE VENDA_ITENS (
  ID              INTEGER GENERATED BY DEFAULT AS IDENTITY,
  VENDA_ID        INTEGER       NOT NULL,
  PRODUTO_ID      INTEGER       NOT NULL,
  QUANTIDADE      INTEGER       NOT NULL,
  PRECO_UNITARIO  NUMERIC(15,2) NOT NULL,          -- snapshot do preço na data da venda
  SUBTOTAL        COMPUTED BY (QUANTIDADE * PRECO_UNITARIO),
  CONSTRAINT PK_VENDA_ITENS PRIMARY KEY (ID),
  CONSTRAINT FK_ITENS_VENDA   FOREIGN KEY (VENDA_ID)   REFERENCES VENDAS (ID) ON DELETE CASCADE,
  CONSTRAINT FK_ITENS_PRODUTO FOREIGN KEY (PRODUTO_ID) REFERENCES PRODUTOS (ID),
  CONSTRAINT CK_ITENS_QTD CHECK (QUANTIDADE > 0)
);

-- Fila simples de reenvio: chamadas ao Financeiro e e-mails que falharam   [SUG]
CREATE TABLE FILA_INTEGRACAO (
  ID                INTEGER GENERATED BY DEFAULT AS IDENTITY,
  VENDA_ID          INTEGER      NOT NULL,
  TIPO              VARCHAR(12)  NOT NULL,         -- QUITACAO | CANCELAMENTO | EMAIL
  STATUS            VARCHAR(10)  DEFAULT 'PENDENTE' NOT NULL,  -- PENDENTE | CONCLUIDO
  TENTATIVAS        SMALLINT     DEFAULT 0 NOT NULL,
  ULTIMO_ERRO       VARCHAR(500),
  PROXIMA_TENTATIVA TIMESTAMP,
  CRIADO_EM         TIMESTAMP    DEFAULT CURRENT_TIMESTAMP NOT NULL,
  CONCLUIDO_EM      TIMESTAMP,
  CONSTRAINT PK_FILA PRIMARY KEY (ID),
  CONSTRAINT FK_FILA_VENDA FOREIGN KEY (VENDA_ID) REFERENCES VENDAS (ID),
  CONSTRAINT CK_FILA_TIPO   CHECK (TIPO   IN ('QUITACAO','CANCELAMENTO','EMAIL')),
  CONSTRAINT CK_FILA_STATUS CHECK (STATUS IN ('PENDENTE','CONCLUIDO'))
);

CREATE INDEX IDX_VENDAS_CLIENTE ON VENDAS (CLIENTE_ID);
CREATE INDEX IDX_VENDAS_STATUS  ON VENDAS (STATUS);
CREATE INDEX IDX_ITENS_VENDA    ON VENDA_ITENS (VENDA_ID);
CREATE INDEX IDX_FILA_STATUS    ON FILA_INTEGRACAO (STATUS, PROXIMA_TENTATIVA);
```

Notas de modelagem:
- "Sincronização pendente" **não** vira um status novo da venda: a venda continua `Pendente` e o estado de integração é derivado da fila. Mantém os três status do contrato.
- Dinheiro: `NUMERIC(15,2)` no banco e `Currency` no Delphi; JSON com ponto decimal independente do locale.
- Saldo de estoque **omitido** de propósito (fora do escopo; ver [DEC-11] se quiser incluir).
- Log técnico em **arquivo** (não em tabela) para não acoplar erro de banco ao mecanismo de log.

---

## 4. Contrato de integração com o Financeiro

O ERP Vendas é **cliente**; o Financeiro expõe. Fonte única de verdade: `docs/contrato-api-financeiro.md`, espelhado no outro repositório.

### 4.1 Baseline v1.0 (recebido — não alterado)

| Método | Rota | Request | Response |
|---|---|---|---|
| POST | `/api/vendas/quitacao` | `{ vendaId:string, clienteId:string, valorTotal:decimal, itens:[{ produtoId:string, quantidade:int, precoUnitario:decimal }] }` | `{ status:"Quitada", dataQuitacao:ISO8601 }` |
| POST | `/api/vendas/cancelamento` | `{ vendaId:string, motivo?:string }` | `{ status:"Cancelada" }` |
| GET | `/api/vendas/{vendaId}/status` | — | `{ vendaId:string, status:string }` |

### 4.2 Lacunas do baseline → refinamentos **propostos** (v1.1, pendentes de alinhamento com o lado C#)

| # | Lacuna | Proposta | Por quê |
|---|---|---|---|
| C1 | Sem formato de erro | Corpo `{ "codigo": string, "mensagem": string }` nos 4xx/5xx | Vendas precisa distinguir "recusado" de "indisponível" |
| C2 | Sem códigos HTTP definidos | 200 ok · 400 payload inválido · 404 venda desconhecida (GET) · 409 transição inválida (ex.: cancelar já quitada) · 422 regra do Financeiro recusou · 5xx indisponível | Decide se reenfileira (5xx/timeout) ou não (4xx) |
| C3 | **Idempotência** | `POST /quitacao` repetido para o mesmo `vendaId` já quitada devolve 200 com o mesmo resultado (não duplica) | Retentativa após timeout é segura |
| C4 | Sem vendaId na resposta de quitação | Aceitar como está (Vendas já sabe o id); opcional acrescentar `vendaId` | Conveniência/log |
| C5 | Valores de `status` não enumerados no GET | Enum fechado: `Pendente`, `Quitada`, `Cancelada` (+ `Recusada`? → [DEC-08]) | Mapeamento 1:1 com `VENDAS.STATUS` |
| C6 | Sem autenticação | Nenhuma (fora do escopo), ou header `X-Api-Key` opcional | Simplicidade; ver [DEC-07] |
| C7 | Base URL/porta | `http://localhost:5000` configurável em `erpvendas.ini` | Externalização de endpoint [SUG] |
| C8 | Serialização | JSON UTF-8; `valorTotal`/`precoUnitario` como número com ponto (2 casas); datas ISO 8601 | Evita erro de locale pt-BR (vírgula) |

**Uso do `GET /status`:** após timeout/erro de rede em `POST /quitacao`, o Vendas consulta o status antes de reenviar — se já estiver `Quitada`, apenas conclui o fluxo local (reconciliação, junto com C3).

### 4.3 Registro de mudanças do contrato

| Data | Versão | Mudança | Status |
|---|---|---|---|
| 21/09/2026 | 1.0 | Contrato inicial recebido | Vigente |
| — | 1.1 | C1–C8 acima | **Proposta — não comunicada ao outro lado** |

---

## 5. Lista de tarefas priorizada

Prioridade: **P0** = requisito obrigatório · **P1** = sugestão de alto retorno para a avaliação · **P2** = sugestão de acabamento.

| ID | Tarefa | Tipo | Prio |
|---|---|---|---|
| T01 | Ambiente **sem custo** (Community/trial): Delphi, Firebird 3, DevExpress, ReportBuilder instalados e compilando "hello world" com os 4; anotar edição/versão/validade de cada licença | OBR | P0 |
| T02 | Script DDL + seed + esqueleto do projeto/camadas + composition root | OBR/SUG | P0 |
| T03 | Config INI (conexão, URL Financeiro, timeout, SMTP) + `.ini.example` | SUG | P0* |
| T04 | Camada de dados FireDAC (conexão, transação, repositórios) | OBR + SUG (Repository) | P0 |
| T05 | CRUD Clientes (incluir/alterar/excluir/consultar) | OBR | P0 |
| T06 | CRUD Produtos | OBR | P0 |
| T07 | CRUD Vendas (mestre/detalhe, total calculado, status) | OBR | P0 |
| T08 | Cliente HTTP do Financeiro (quitação, cancelamento, status) com timeout configurável | OBR | P0 |
| T09 | Fluxo Confirmar/Cancelar venda → atualiza status local | OBR | P0 |
| T10 | Relatório de confirmação de pedido (ReportBuilder) | OBR | P0 |
| T11 | Exportar relatório para PDF | SUG (na prática, pré-requisito do anexo) | P0* |
| T12 | Envio SMTP automático pós-quitação | OBR | P0 |
| T13 | Tratamento centralizado de exceções + log em arquivo | SUG | P1 |
| T14 | Validação CPF/CNPJ e e-mail com feedback visual (DevExpress) | SUG | P1 |
| T15 | Fila de reenvio (Financeiro e e-mail) + tela de pendências | SUG | P1 |
| T16 | Mock do Financeiro a partir do contrato | SUG (viabiliza T08–T12 em paralelo ao C#) | P1 |
| T17 | Integração ponta a ponta com o Financeiro real (ajuste de contrato) | OBR | P0 |
| T18 | README de execução + roteiro de testes manuais + `decisoes.md` | OBR (README) + SUG | P0/P1 |
| T19 | Build release, pacote (exe + DLLs), backup `.FBK` | OBR | P0 |
| T20 | Acabamento de UI (filtros, atalhos, máscaras) | SUG | P2 |

`*` = tecnicamente sugestão, mas o requisito obrigatório não fecha sem ela.

**Onde cortar (com prazo de 5 dias, já assumir os dois primeiros cortes):** T20 → reprocessamento automático da fila (só botão "Reenviar") → seed extenso → roteiro de testes reduzido aos fluxos principais → refinamentos de contrato além de C1–C3.
**Nunca cortar:** T05–T12, T17, T19 e o README.

---

## 6. Cronograma (5 dias — entrega na sexta-feira, 25/09/2026)

Premissa (DEC-12, decidida pelo autor): dia 1 = segunda-feira 21/09/2026; **prazo de desenvolvimento = sexta-feira 25/09/2026** (o prazo formal do desafio iria até 28/09). Não há dia de folga: o D4 é o "feature freeze" e o D5 é só integração final, documentação e empacotamento.

| Dia | Data | Foco | Entregas / critério de saída |
|---|---|---|---|
| D1 | seg 21/09 | Fundação + alinhamento | T01 (ambiente/licenças), T02, T03, T04, T16 (mock). **Contrato v1.1 enviado ao C#.** Projeto compila e conecta no Firebird; T05 Clientes iniciado |
| D2 | ter 22/09 | Cadastros | T05 Clientes, T06 Produtos completos; T14 validadores (CPF/CNPJ, e-mail); T13 esqueleto (log + handler de exceções) |
| D3 | qua 23/09 | Vendas + cliente HTTP | T07 CRUD Vendas mestre/detalhe com regras de status; T08 cliente HTTP com timeout configurável, testado no mock |
| D4 | qui 24/09 | Fluxo completo (feature freeze) | T09 confirmar/cancelar; T10 relatório; T11 PDF; T12 e-mail pós-quitação (SMTP de teste); T17 já contra o C# assim que ele estiver de pé. **Fim do D4: nenhuma funcionalidade nova** |
| D5 | sex 25/09 | Robustez + fechamento | T15 fila de reenvio (versão mínima: botão "Reenviar"); T17 fechado com o C# real; T18 README + roteiro de testes (enxuto) + `decisoes.md`; T19 release, pacote (exe + DLLs) e `.FBK`; teste de instalação em pasta limpa |

Riscos de cronograma: sem folga, qualquer atraso no C# ou no ambiente derruba a entrega. Mitigações: o mock (T16) permite avançar sem o C#; **T01 no D1** valida Delphi/DevExpress/ReportBuilder/SMTP logo de início; se o C# não estiver pronto na quinta, a demonstração usa o mock e a integração real entra como evidência adicional na sexta.

---

## 7. Riscos principais

| Risco | Impacto | Mitigação |
|---|---|---|
| Componentes licenciados (DevExpress/ReportBuilder) indisponíveis ou em trial com limitações | Alto | Validar no D1 (T01); ver "Estratégia de licenças" abaixo |
| Executável compilado com trial pode exibir aviso/marca d'água ou **expirar** antes de o avaliador rodá-lo | Alto | Perguntar à CartSys; entregar código-fonte + evidências (PDF gerado, prints/vídeo); ver abaixo |
| Financeiro C# atrasa/diverge do contrato | Alto | Contrato versionado + mock; integração real já no D4, fechamento no D5 (sem folga) |
| SMTP com TLS falha (OpenSSL do Indy antigo) | Médio | Testar envio real no D1/D2; empacotar DLLs corretas; [DEC-04] |
| Indisponibilidade do Financeiro trava a UI | Médio | Timeout configurável (padrão 10 s), cursor de espera, fila de reenvio |
| Escopo dual-stack em 5 dias de desenvolvimento | Alto | Ordem P0 → P1 → P2; corte pré-definido (seção 5) |
| Credenciais SMTP versionadas por engano | Médio | `.ini` no `.gitignore`; só `.ini.example` no repositório |

---

### Estratégia de licenças (custo zero)

Diretriz: manter Delphi, FireDAC, DevExpress e ReportBuilder, sem comprar nada. **Os dados abaixo vêm de conhecimento geral e podem estar desatualizados — conferir nos sites oficiais no D1.**

| Item | Caminho sem custo | Cuidados a verificar |
|---|---|---|
| Delphi + FireDAC | Community Edition (gratuita, com critérios de elegibilidade) **ou** trial da edição paga | Se a Community traz o driver FireDAC para Firebird e a versão exigida pelo desafio; se não, usar o trial |
| Firebird 3.0 | Gratuito (open source) | — |
| DevExpress VCL | Trial (tipicamente 30 dias) | Aviso de avaliação em telas/executável |
| ReportBuilder | Trial/avaliação do fabricante | Limitações (marca d'água, expiração, exportação PDF/e-mail) |
| Indy (SMTP), `System.Net.HttpClient` | Já vêm com o Delphi | — |

Regras práticas:
1. **Instalar tudo no D1**, só depois de decidir; o relógio do trial começa na instalação/ativação, e 30 dias cobrem os 7 do desafio.
2. **Perguntar à CartSys** (recrutador) se disponibiliza licenças/ambiente para o desafio — costuma ser a resposta mais simples e resolve a expiração do executável.
3. Como o avaliador pode abrir o executável depois de o trial vencer: entregar **código-fonte + executável + evidências** (PDF do relatório, prints/vídeo do fluxo) e documentar a limitação no README.
4. Não versionar chaves/instaladores de licença no repositório.

## 8. Decisões em aberto (precisam de validação antes de implementar)

**Status (atualizado):** o autor aprovou "seguir as recomendações". Ficam **ADOTADAS** as recomendações de DEC-01, 03, 04, 05, 06, 07, 08, 09, 10, 11, 13, 14 e 15, e DEC-12 (**revisada pelo autor: D1 = 21/09, desenvolvimento até sexta 25/09**). Observações:
- **DEC-02 (licenças) — diretriz do autor: manter a stack obrigatória sem custo, usando edições gratuitas ou trial.** Detalhes de versões/edições a confirmar no D1 (T01); ver "Estratégia de licenças" na seção 7. Enquanto isso, o código deve evitar recursos exclusivos de versões recentes do Delphi.
- **DEC-08 e DEC-09** estão adotadas do lado do Vendas, mas **seguem pendentes de confirmação pelo lado C#** (registrar em 4.3 quando houver resposta).

Cada item traz a **recomendação** adotada.

| ID | Decisão | Opções | Recomendação |
|---|---|---|---|
| **DEC-01** | Banco de dados | Firebird 3.0 · SQL Server 2020/2022 | **Firebird 3.0**: entrega leve (`.FBK` + script), sem instalar servidor pesado no avaliador, IDENTITY/BOOLEAN nativos no FB3. SQL Server só se você já tiver ambiente e quiser demonstrar T-SQL |
| **DEC-02** | Versões disponíveis: Delphi (13/12.x/10.3), DevExpress e ReportBuilder — instaladas e licenciadas (não trial)? | — | **Preciso que você informe.** Determina sintaxe permitida (ex.: inline vars só no 10.3+; `System.Net.HttpClient` existe em todas) e se PDF/e-mail no ReportBuilder funcionam sem marca d'água |
| **DEC-03** | Formato dos IDs no contrato (`string`) | ID inteiro serializado · GUID | **Inteiro como string** (`"42"`): simples, legível em log; o C# trata como string opaca |
| **DEC-04** | Cliente HTTP e e-mail | HTTP: `System.Net.HttpClient` · Indy `TIdHTTP` · `TRESTClient`. E-mail: Indy `TIdSMTP` · outro | HTTP: **`THTTPClient` nativo** (timeouts de conexão/resposta configuráveis, sem DLL, TLS do SO) + `System.JSON`. E-mail: **Indy `TIdSMTP`** (+OpenSSL; testar TLS cedo). Sem bibliotecas de terceiros |
| **DEC-05** | Banco compartilhado ou segregado do Financeiro (PDF §10 exige decisão documentada) | Compartilhado · segregado | **Segregado**: baixo acoplamento, a API é a única ponte, cada módulo evolui/faz backup sozinho |
| **DEC-06** | Como desenvolver sem o Financeiro pronto | Mock (Node/Python/Delphi Indy) · aguardar o C# | **Mock mínimo em `tools/mock-financeiro/`** seguindo o contrato, com modo "falha/timeout" para testar a fila |
| **DEC-07** | Autenticação da API | Nenhuma · `X-Api-Key` | **Nenhuma** no MVP (fora do escopo), com header opcional configurável se o C# pedir |
| **DEC-08** | Financeiro pode **recusar** uma quitação? Qual resposta? | 422 + `codigo`/`mensagem` · status "Recusada" · sempre aceita | Recusa = 4xx com corpo de erro (C1/C2); venda permanece `Pendente` e a mensagem é exibida. **Alinhar com o C#** |
| **DEC-09** | Cancelar venda **já quitada** é permitido? | Só Pendente · qualquer estado | **Só `Pendente`** no MVP (estorno é outro processo); Financeiro responde 409 se receber o contrário |
| **DEC-10** | Repositório devolve entidade ou DataSet para grades/relatório | Só entidades · híbrido | **Híbrido** (entidade p/ edição, DataSet p/ grade e ReportBuilder) — pragmático e ainda isolado atrás de interface |
| **DEC-11** | Incluir saldo de estoque em Produtos? | Sim · não | **Não** (fora do escopo; corta tempo) |
| **DEC-12** | Data real de recebimento / prazo final | Decidido pelo autor: desenvolvimento até sexta 25/09 (prazo formal do desafio: 28/09) | **Adotada: 25/09**; cronograma de 5 dias na seção 6 |
| **DEC-13** | Provedor SMTP para testes e para a demo | Gmail (senha de app) · Mailtrap/Ethereal · SMTP do avaliador | **Mailtrap/Ethereal em desenvolvimento**, Gmail com senha de app se quiser mostrar e-mail real; credenciais só no `.ini` local |
| **DEC-14** | Envio síncrono ou em thread | Síncrono com timeout · `TTask` | **Síncrono** com timeout curto e cursor de espera (menos risco de concorrência com FireDAC/VCL); o que falhar vai para a fila |
| **DEC-15** | Repositório: público ou privado, e commits do plano | — | Manter privado ou sem credenciais; commitar `VISAO-PRODUTO.md` junto ao código |

**Bloqueantes reais antes do D1:** DEC-02 (só você sabe), DEC-01 (confirmar), DEC-08/DEC-09 (dependem do C#). As demais têm default seguro.

---

## 9. Próximos passos

1. ~~Validar a seção 8~~ — recomendações adotadas. Falta informar **DEC-02** (versões/licenças).
2. Enviamos a seção 4 (contrato v1.1 proposto) para a sessão do ERP Financeiro e registramos a resposta em 4.3.
3. Com o plano aprovado, seguir para o pipeline do repositório (`/definir_organizar`) para gerar SDD/TASK a partir deste documento, ou começar direto pela T01.
