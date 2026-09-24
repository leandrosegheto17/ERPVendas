# Contrato de API — Integração ERP Vendas x Financeiro

Fonte única de verdade do contrato entre o ERP Vendas (cliente) e o sistema
Financeiro em C# (servidor). Espelha `VISAO-PRODUTO.md` §4 e alimenta
`ADR-004` (cliente REST), `ADR-005` (fila/reenvio) e `ADR-006` (fluxo de
quitação). Qualquer mudança de rota/payload/código só entra em vigor depois
de registrada neste arquivo (TASK.md, Seção 1, "Contrato").

- **Versão vigente:** v1.0 (recebida do lado C#, não alterada).
- **Versão:** v1.1 (itens C1-C8) **implementada pelo C#** (confirmada em 2026-09-24 pelo smoke T54; DEC-08/09 respondidas)
  — ver Seção 3 (registro T55).
- **Base URL:** configurável em `erpvendas.ini` (ex.: `http://localhost:5000`),
  nunca hardcoded no código Delphi.
- **Autenticação:** header `X-Api-Key` **obrigatório no C# real** (T55/D3, 2026-09-24; só `/api/health` dispensa); opcional só para o mock. O cliente só o
  envia se houver valor no INI/variável de ambiente; vazio
  = não envia (DEC-07, válido só no mock). 401 => mensagem de configuração, sem enfileirar.
- **Formato:** JSON, UTF-8. Números decimais sempre com ponto (nunca vírgula),
  2 casas para valores monetários. Datas em ISO 8601 (`AAAA-MM-DDThh:mm:ss`).
  `TFormatSettings` invariante no cliente Delphi, independente do locale
  pt-BR ativo na máquina. `vendaId`, `clienteId`, `produtoId` sempre como
  **string** contendo o id inteiro (nunca número JSON).

---

## 1. Contrato v1.0 — vigente

### 1.1 POST `/api/vendas/quitacao`

Confirma o pagamento de uma venda Pendente junto ao Financeiro (RF-12/13).

**Request**

```json
{
  "vendaId": "1042",
  "clienteId": "17",
  "valorTotal": 350.90,
  "itens": [
    { "produtoId": "3", "quantidade": 2, "precoUnitario": 120.00 },
    { "produtoId": "8", "quantidade": 1, "precoUnitario": 110.90 }
  ]
}
```

**Response — sucesso (200)**

```json
{
  "status": "Quitada",
  "dataQuitacao": "2026-09-22T14:35:12"
}
```

**Response — recusa (4xx, corpo não garantido em v1.0)**

Corpo de erro **não é garantido** pelo baseline v1.0; o cliente é tolerante:
se não houver corpo/campo reconhecível, usa mensagem genérica com o código
HTTP (ver ADR-004 e UX-SPEC §4.3): `"Quitação recusada pelo Financeiro
(código HTTP xxx)"`.

**Response — indisponibilidade (5xx / timeout / erro de rede)**

Sem corpo estruturado esperado; classificado como `Indisponivel` pelo
cliente (timeout padrão 10 s, configurável no INI). Venda permanece
`Pendente` e é enfileirada (`FILA_INTEGRACAO`, tipo `QUITACAO`) — RN-08.

**Efeito local esperado:** 200 → grava `STATUS=Quitada` e `DATA_QUITACAO`
(valor vindo do Financeiro) em transação curta, fora da chamada HTTP
(ADR-006); depois gera PDF e envia e-mail. 4xx → mantém `Pendente`, não
enfileira (RN-08). 5xx/timeout/rede → mantém `Pendente`, enfileira.

---

### 1.2 POST `/api/vendas/cancelamento`

Cancela uma venda Pendente junto ao Financeiro (RF-16/17).

**Request**

```json
{
  "vendaId": "1042",
  "motivo": "Cliente desistiu da compra"
}
```

`motivo` é opcional (`motivo?`); se omitido, o campo não é enviado.

**Response — sucesso (200)**

```json
{
  "status": "Cancelada"
}
```

**Response — recusa (4xx)**

Mesmo tratamento tolerante da quitação: sem corpo garantido em v1.0, mensagem
genérica com código HTTP como fallback. Venda permanece no status anterior
(RN-02: só `Pendente` é cancelável no MVP; ver DEC-09, ainda não confirmada
pelo C#).

**Response — indisponibilidade (5xx / timeout / erro de rede)**

Classificado como `Indisponivel`; item enfileirado em `FILA_INTEGRACAO`,
tipo `CANCELAMENTO`.

**Efeito local esperado:** 200 → grava `STATUS=Cancelada` e
`MOTIVO_CANCELAMENTO`. 4xx → mantém status anterior, não enfileira. 5xx/timeout
→ mantém status anterior, enfileira.

---

### 1.3 GET `/api/vendas/{vendaId}/status`

Consulta o status atual de uma venda no Financeiro. Usada para reconciliação
após timeout/5xx na quitação (RF-18, ADR-005): antes de reenviar um item
`QUITACAO` pendente, o Vendas consulta este endpoint; se já `Quitada`, conclui
localmente sem repostar.

**Request:** sem corpo; `{vendaId}` na URL (string do id inteiro).

**Response — sucesso (200)**

```json
{
  "vendaId": "1042",
  "status": "Quitada"
}
```

Valores de `status` esperados pelo cliente (v1.0 não define um enum fechado):
`"Pendente"`, `"Quitada"`, `"Cancelada"`. Qualquer valor fora desse conjunto é
tratado como `RespostaInvalida` (não interrompe o fluxo, mas não é
interpretado como conclusão).

**Response — erro**

`404` (venda desconhecida no Financeiro) ou `5xx`/timeout: classificados como
`Recusado`/`Indisponivel` conforme a faixa do código HTTP, igual às outras
rotas.

---

### 1.4 Regras de formato (todas as rotas)

- Locale invariante: `.` como separador decimal, nunca `,`; nunca depende do
  locale pt-BR do SO.
- Datas em ISO 8601, sem timezone explícito (horário local do servidor
  Financeiro, assumido igual ao do Vendas — sem conversão de fuso).
- Ids (`vendaId`, `clienteId`, `produtoId`) sempre como string, mesmo sendo
  inteiros no banco de cada lado.
- Header `X-Api-Key`: enviado somente se configurado (INI ou variável de
  ambiente); o C# real o exige (ausência = 401, T55/D3). Datas do C# vêm em UTC com `Z` (T55/D4; verificado no app, sem correção).
- Cliente **nunca** mantém transação de banco local aberta durante a
  chamada HTTP (ADR-006).

### 1.5 Códigos de erro (mapeamento do cliente Delphi — ADR-004)

| Faixa HTTP / condição | Categoria (`TResultadoFinanceiro`) | Efeito |
|---|---|---|
| 200 | `Sucesso` | Segue o fluxo (grava status, PDF, e-mail conforme a rota) |
| 4xx (400, 404, 409; o C# não usa 422) | `Recusado` | Mantém status atual; mensagem de `erro.mensagem` do envelope real `{"erro":{"codigo","mensagem"}}` (ou raiz `mensagem`, v1.0), senão fallback com código HTTP; **não enfileira** (RN-08) |
| 401 | `Recusado` | Mensagem fixa de configuração da `X-Api-Key` (ausente vs. rejeitada); não enfileira (T55/D3) |
| 409 `CONFLITO_CONCORRENCIA` | `Indisponivel` | Retentável (o C# diz que pode repetir): enfileira como 5xx; decisão só pelo `codigo` (T55/D2) |
| 5xx | `Indisponivel` | Mantém status atual; enfileira (exceto GET status, que não enfileira, só reconcilia) |
| Timeout (>10 s, configurável) | `Indisponivel` | Idem 5xx |
| Erro de rede/conexão | `Indisponivel` | Idem 5xx |
| Corpo de resposta não parseável / campo obrigatório ausente no 200 | `RespostaInvalida` | Tratado como falha; não altera dado local; mensagem amigável ao usuário |

---

## 2. Proposta v1.1 (C1-C8) — **IMPLEMENTADA PELO C# (confirmada 2026-09-24, ver Seção 3)**

> Histórico da proposta original (texto de 22/09; onde diz `422` e corpo `{codigo,mensagem}`, vale o que o C# implementou: 400/409 e envelope `erro`, Seção 3). Ressalva antiga: nada aqui
> estava em vigor até a confirmação do time C# (agora dada). O cliente Delphi (ADR-004) já foi
> implementado de forma tolerante à v1.0 — funciona igual, com ou sem estes
> refinamentos.

| # | Lacuna no baseline v1.0 | Proposta v1.1 | Motivo |
|---|---|---|---|
| C1 | Sem formato de erro definido nos 4xx/5xx | Corpo padrão `{ "codigo": string, "mensagem": string }` em toda resposta de erro | Vendas precisa distinguir "recusado" (regra de negócio) de "indisponível" (infraestrutura) de forma confiável, não só pelo código HTTP |
| C2 | Sem códigos HTTP definidos por cenário | `200` ok · `400` payload inválido · `404` venda desconhecida (GET status) · `409` transição inválida (ex.: cancelar venda já quitada — DEC-09) · `422` regra de negócio do Financeiro recusou a quitação (DEC-08) · `5xx` indisponibilidade | Decide automaticamente se o item deve ou não ser enfileirado (5xx/timeout reenfileira; 4xx não) |
| C3 | Sem garantia de idempotência | `POST /api/vendas/quitacao` repetido para um `vendaId` já quitado devolve `200` com o mesmo resultado (não duplica cobrança/registro) | Torna segura a retentativa manual (tela de Pendências) após timeout, sem risco de duplicidade no Financeiro |
| C4 | Resposta de quitação não devolve `vendaId` | Aceitar como está (Vendas já conhece o id enviado); opcionalmente incluir `vendaId` na resposta | Conveniência de log/rastreio, não bloqueia nada |
| C5 | Valores de `status` no GET não são um enum fechado | Fechar o enum: `Pendente`, `Quitada`, `Cancelada` (+ eventual `Recusada`, a decidir junto com DEC-08) | Mapeamento 1:1 seguro com `VENDAS.STATUS` no banco do Vendas, sem valor surpresa |
| C6 | Sem autenticação | Manter sem autenticação obrigatória; oferecer `X-Api-Key` opcional caso o C# queira exigir num ambiente específico | Simplicidade no MVP, com trilha de evolução (DEC-07) |
| C7 | Base URL/porta não padronizada entre ambientes | Documentar URL de cada ambiente (dev/homolog/produção) neste contrato quando existirem | Facilita configuração do `erpvendas.ini` por ambiente |
| C8 | Serialização não descrita formalmente | Formalizar: JSON UTF-8; `valorTotal`/`precoUnitario` como número com ponto decimal (2 casas); datas ISO 8601 | Evita erro de locale pt-BR (vírgula) já mitigado do lado Vendas, mas bom ter formalizado dos dois lados |

**Relação direta com DEC-08/DEC-09 (bloqueadas de confirmação):**
- **DEC-08** (Financeiro pode recusar uma quitação? qual resposta?): coberta
  por C1 + C2 (código `422` + corpo `{codigo, mensagem}` para recusa de
  regra de negócio). Enquanto não confirmada, o Vendas trata **qualquer**
  4xx como recusa genérica (RF-15).
- **DEC-09** (cancelar venda já quitada é permitido?): coberta por C2
  (código `409` para transição inválida). Enquanto não confirmada, o Vendas
  **nunca** envia cancelamento para venda que não esteja `Pendente` (RF-17,
  bloqueio já feito no lado do cliente, independente da resposta do
  servidor).

---

## 3. Tabela de mudanças (v1.0 → v1.1)

| Data | Versão | Mudança | Status |
|---|---|---|---|
| 21/09/2026 | 1.0 | Contrato inicial recebido do lado C# (3 rotas, sem formato de erro/idempotência formalizados) | **Vigente** |
| 22/09/2026 | 1.1 | Proposta C1-C8: formato de erro padronizado, códigos HTTP por cenário (incl. `409`/`422` para DEC-08/09), idempotência de quitação, enum fechado de status, formalização de serialização | **Proposta enviada ao contato C# em 22/09/2026 (prazo pedido: 23/09/2026); não houve resposta escrita — a implementação da v1.1 pelo C# foi confirmada em 24/09/2026 pelo smoke T54 (ver linhas de 24/09)** |
| 24/09/2026 | smoke T54 | Smoke com curl contra o Financeiro C# real (http://localhost:5000, chave via `ERPV_FINANCEIRO_APIKEY`, nunca registrada). O C# implementa de fato a v1.1 (envelope `{erro:{codigo,mensagem}}`, 400/401/404/409, idempotência, `X-Correlation-Id`, alias `/api/v1`). Divergências D1-D9 abaixo, a tratar na T55. | **Registrado; ajustes de código na T55** |
| 24/09/2026 | 1.1 (registro T55) | **Confirmação: v1.1 implementada pelo C#** (evidência = smoke T54, curl + app na IDE; não houve resposta escrita do contato). DEC-08 respondida: recusa = 400 (`VALOR_TOTAL_DIVERGENTE`, `PAYLOAD_INVALIDO`) ou 409 (`VENDA_JA_CANCELADA`, `DADOS_DIVERGENTES`, `MOTIVO_OBRIGATORIO`), **sem 422**. DEC-09 respondida: o C# aceita cancelar Quitada com motivo (200) e devolve 409 `MOTIVO_OBRIGATORIO` sem motivo; o Vendas mantém o bloqueio local (só cancela Pendente). Ajustes no cliente: D1 (envelope `erro`), D2 (`409 CONFLITO_CONCORRENCIA` = `Indisponivel`/retentável, sustentado pelo contrato-v1.1 do Financeiro; demais 4xx = `Recusado`), D3 (401 = mensagem de configuração da chave), D4 (só documentação: C# envia UTC). Mock passou a responder 400 com envelope. Não verificado contra o C# real: 409 `CONFLITO_CONCORRENCIA`, 5xx e timeout (cobertos por testes DUnitX de função pura, `tests/ERPV.Testes.FinanceiroClientErros.pas`, compilados e executados na IDE em 24/09/2026: 78/78 testes DUnitX passaram). | **Confirmada (v1.1 implementada; ajustes T55 aplicados no código, sem compilação/execução por CLI)** |

### 3.1 Divergências encontradas no smoke T54 (2026-09-24)

Escopo executado: **curl** contra os 3 endpoints reais e, depois, o **app Delphi
rodado na IDE** contra o mesmo Financeiro (o `dcc32` da edição Community não
compila por linha de comando). Chave via `ERPV_FINANCEIRO_APIKEY`, omitida das
evidências. Verificado no app em 2026-09-24: quitação de venda Pendente =>
`Quitada` com `DATA_QUITACAO` no horário local correto (D4 verificado, sem
deslocamento de fuso nem falha de parse); e-mail de confirmação com PDF entregue
(Mailtrap, porta 2525, sem TLS); cancelamento de venda Pendente => `Cancelada`.
Confirmar venda Cancelada e cancelar venda Quitada são barrados na UI (botão
desabilitado; RF-11, INT-05/DEC-09): o app nunca envia essas chamadas, e o 409
correspondente do C# só foi exercitado por curl. D1, D2 e D3 continuam vindo de
leitura de código comparada com as respostas reais (não observados no app).

Resultados reais (curl): health 200; quitação nova 200 `{status:Quitada,dataQuitacao}`;
quitação repetida 200 (idempotente, mesma data); status Quitada/Cancelada 200;
status de id inexistente 404 `VENDA_NAO_ENCONTRADA`; cancelamento de Quitada
com motivo 200; cancelamento de id desconhecido 200 `Cancelada` (cria); cancelamento
repetido 200; quitar Cancelada 409 `VENDA_JA_CANCELADA`; cancelar Quitada sem
motivo 409 `MOTIVO_OBRIGATORIO`; `valorTotal` divergente 400
`VALOR_TOTAL_DIVERGENTE`; `itens` vazio 400 `PAYLOAD_INVALIDO`; sem chave e chave
errada 401 `NAO_AUTORIZADO` (corpos idênticos); alias `/api/v1/vendas/{id}/status` 200.

| # | Divergência (cliente/contrato do Vendas x C# real) | Impacto | Ação (T55) |
|---|---|---|---|
| D1 | Envelope de erro: o C# devolve `{"erro":{"codigo","mensagem"}}`; `ExtrairMensagem` lê `mensagem` na raiz. | A mensagem real do Financeiro nunca é exibida; cai sempre no fallback "(código HTTP xxx)" | Ler `erro.mensagem` (e `erro.codigo`), mantendo fallback |
| D2 | Não existe `422`: recusa por regra de negócio é 400 (`VALOR_TOTAL_DIVERGENTE`, `PAYLOAD_INVALIDO`) ou 409 (`VENDA_JA_CANCELADA`, `DADOS_DIVERGENTES`, `MOTIVO_OBRIGATORIO`, `CONFLITO_CONCORRENCIA`). Mock/roteiro do cliente assumem 422. | Tratamento genérico 4xx continua correto (Recusado, sem enfileirar), exceto `CONFLITO_CONCORRENCIA` (409, o C# diz que pode repetir) | Decidir se `CONFLITO_CONCORRENCIA` deve ser tratado como retentável; atualizar mock para 400/409 |
| D3 | `X-Api-Key` é **obrigatório** no C# (todas as rotas exceto `/api/health`); o contrato do Vendas diz opcional (DEC-07) e o INI padrão vem com `ApiKey=` vazio. Chave ausente e inválida dão 401 idêntico. | Sem chave configurada, toda operação vira `Recusado` 401 (não enfileira) | Marcar chave como obrigatória em produção; mensagem específica para 401 (configuração, não recusa de negócio) |
| D4 | `dataQuitacao` vem em UTC com sufixo `Z` e 7 casas fracionárias (`2026-09-24T12:57:36.3587666Z`); o contrato do Vendas dizia "sem timezone, sem conversão". O cliente usa `ISO8601ToDate(..., False)`. | **Verificado no app (2026-09-24):** `DATA_QUITACAO` gravada e exibida no horário local correto; parse com 7 casas e "Z" sem falha | Nenhuma correção; só documentar que o C# envia UTC |
| D5 | Quitação repetida com payload diferente para venda **já Quitada** devolve 200 (não `409 DADOS_DIVERGENTES`; esse código só ocorre em venda Pendente registrada). | Sem impacto no fluxo normal; idempotência confirmada | Ajustar a descrição de `DADOS_DIVERGENTES` no contrato — **status: feito** (documentação apenas, sem mudança de código): `DADOS_DIVERGENTES` (409) só ocorre em venda Pendente já registrada; quitação repetida de venda já Quitada devolve 200 |
| D6 | Cancelamento de `vendaId` desconhecido devolve 200 `Cancelada` (D-08, cria registro) e cancelar Quitada com motivo é aceito (200). | O Vendas só cancela Pendente, então sem impacto; confirma DEC-09 como "permitido com motivo" no C# | Registrar DEC-08/DEC-09 como respondidas |
| D7 | `POST /api/vendas` (registrar Pendente) responde 404: não implementado no C#. | Vendas não o usa | Manter fora do escopo |
| D8 | Mensagens do C# usam vírgula decimal (culture pt-BR do host) em `VALOR_TOTAL_DIVERGENTE`; JSON malformado devolve `PAYLOAD_INVALIDO` com mensagem enganosa ("vendaId é obrigatório"). | Só texto; o Vendas não deve parsear mensagem | Usar apenas `codigo` |
| D9 | Ids como número JSON (`"vendaId":123`) também são aceitos pelo C#; o cliente envia string (correto). | Nenhum | Nenhuma |

Não verificados: timeout de 10 s, erro 5xx e
indisponibilidade real (o C# não foi derrubado), `CONFLITO_CONCORRENCIA` e
`ERRO_INTERNO` (não provocados), persistência local do resultado.

O resultado da confirmação foi registrado pela T55 na linha de 24/09/2026
("1.1 (registro T55)") da tabela acima, junto aos ajustes de mapeamento de
erro/código/`X-Api-Key` no cliente (D1-D4). Não houve resposta escrita do
contato C#; a evidência é o smoke T54. Os cenários "Não verificados" acima
seguem em aberto (RF14-05).

---

## 4. Mensagem para envio ao contato do time C# (ação humana do usuário)

> Registro histórico (22/09): não houve resposta escrita ao pedido; a
> confirmação veio pelo smoke T54 de 24/09/2026 (Seção 3).
> O envio desta mensagem é uma ação humana do usuário — não é executada por
> este agente. O texto abaixo está pronto para colar em e-mail/chat com o
> contato do time C# do Financeiro.

**Assunto:** Confirmação de contrato de integração Vendas x Financeiro — DEC-08/DEC-09 (prazo 23/09)

**Corpo:**

> Olá,
>
> Estamos finalizando a integração do ERP Vendas com o Financeiro e
> gostaríamos de confirmar dois pontos do contrato antes de fecharmos o
> comportamento do cliente para a entrega de sexta-feira (25/09):
>
> **1. Recusa de quitação (DEC-08).** Quando o Financeiro recusa uma
> quitação por regra de negócio (ex.: valor divergente, cliente bloqueado
> etc.), qual é o comportamento hoje?
> - Vocês respondem com algum código HTTP 4xx específico (proponho `422`)?
> - O corpo da resposta traz `{ "codigo": string, "mensagem": string }`
>   com o motivo, ou não há corpo estruturado hoje?
>
> **2. Cancelamento de venda já quitada (DEC-09).** Nosso MVP só permite
> cancelar vendas com status `Pendente` (o Vendas já bloqueia isso do nosso
> lado antes de chamar a API). Se, por algum motivo, chegar uma chamada de
> cancelamento para uma venda que vocês já têm como quitada, o que a API
> devolve hoje?
> - Um erro específico (proponho `409 Conflict`)?
> - Ou é tratado de outra forma?
>
> Em anexo/no link [inserir link do repositório ou do arquivo
> `docs/contrato-api-financeiro.md`], está a proposta de contrato v1.1
> (itens C1-C8) com o detalhamento completo do que estamos assumindo do
> nosso lado enquanto não temos a confirmação de vocês — hoje o cliente do
> Vendas é tolerante e não depende desses refinamentos para funcionar, mas
> ficaríamos mais seguros com a confirmação.
>
> Poderiam confirmar (mesmo que informalmente, por aqui) até
> **quarta-feira, 23/09**? Isso nos ajuda a fechar o mapeamento de erros do
> lado do Vendas ainda dentro do prazo desta sprint.
>
> Qualquer dúvida, estou à disposição.
>
> Obrigado!

---

*Este arquivo é a fonte única do contrato (TASK.md, Seção 1, "Contrato").
Qualquer divergência encontrada durante o smoke test contra o C# real (T54)
deve ser registrada na Seção 3 acima, com data e status da confirmação
(T55).*
