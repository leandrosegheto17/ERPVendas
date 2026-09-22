# Contrato de API — Integração ERP Vendas x Financeiro

Fonte única de verdade do contrato entre o ERP Vendas (cliente) e o sistema
Financeiro em C# (servidor). Espelha `VISAO-PRODUTO.md` §4 e alimenta
`ADR-004` (cliente REST), `ADR-005` (fila/reenvio) e `ADR-006` (fluxo de
quitação). Qualquer mudança de rota/payload/código só entra em vigor depois
de registrada neste arquivo (TASK.md, Seção 1, "Contrato").

- **Versão vigente:** v1.0 (recebida do lado C#, não alterada).
- **Versão proposta:** v1.1 (itens C1-C8), aguardando confirmação do lado C#
  — ver Seção 3.
- **Base URL:** configurável em `erpvendas.ini` (ex.: `http://localhost:5000`),
  nunca hardcoded no código Delphi.
- **Autenticação:** nenhuma no MVP; header `X-Api-Key` **opcional** — só é
  enviado se um valor estiver configurado no INI/variável de ambiente; vazio
  = não envia (DEC-07).
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
  ambiente); ausência não é erro.
- Cliente **nunca** mantém transação de banco local aberta durante a
  chamada HTTP (ADR-006).

### 1.5 Códigos de erro (mapeamento do cliente Delphi — ADR-004)

| Faixa HTTP / condição | Categoria (`TResultadoFinanceiro`) | Efeito |
|---|---|---|
| 200 | `Sucesso` | Segue o fluxo (grava status, PDF, e-mail conforme a rota) |
| 4xx | `Recusado` | Mantém status atual; mensagem do corpo se existir, senão fallback com código HTTP; **não enfileira** (RN-08) |
| 5xx | `Indisponivel` | Mantém status atual; enfileira (exceto GET status, que não enfileira, só reconcilia) |
| Timeout (>10 s, configurável) | `Indisponivel` | Idem 5xx |
| Erro de rede/conexão | `Indisponivel` | Idem 5xx |
| Corpo de resposta não parseável / campo obrigatório ausente no 200 | `RespostaInvalida` | Tratado como falha; não altera dado local; mensagem amigável ao usuário |

---

## 2. Proposta v1.1 (C1-C8) — **PROPOSTA, NÃO CONFIRMADA PELO LADO C#**

> Esta seção descreve refinamentos **propostos** ao baseline v1.0. Nada aqui
> está em vigor até confirmação do time C#. O cliente Delphi (ADR-004) já foi
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
| 22/09/2026 | 1.1 | Proposta C1-C8: formato de erro padronizado, códigos HTTP por cenário (incl. `409`/`422` para DEC-08/09), idempotência de quitação, enum fechado de status, formalização de serialização | **Proposta — enviada ao contato C# em 22/09/2026, aguardando confirmação até 23/09/2026** |

Quando a confirmação (total, parcial ou negativa) chegar do lado C#, esta
tabela ganha uma nova linha com a data e o resultado (T55 do TASK.md é
responsável por esse registro, junto ao ajuste de mapeamento de erro/código/
`X-Api-Key` no cliente).

---

## 4. Mensagem para envio ao contato do time C# (ação humana do usuário)

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
