# Mock do Financeiro (T05 / ADR-009 / RF-26)

Servidor HTTP minimo, **só biblioteca padrão do Python 3** (sem dependências
externas), que simula o serviço Financeiro (C#) descrito no contrato v1.0
(`docs/contrato-api-financeiro.md`). Serve para desenvolver e demonstrar a
integração (ADR-004/005/006) sem depender do C# real.

Não faz parte do pacote de entrega do `.exe` — é ferramenta de
desenvolvimento/demo (ADR-009).

## Requisitos

- Python 3.8+ (só stdlib: `http.server`, `json`, `socket`, `threading`,
  `datetime`, `urllib.parse`). Nenhuma instalação de pacote necessária.

## Como rodar

```bash
python mock_financeiro.py --host 127.0.0.1 --port 8080 --modo ok
```

Parâmetros (todos opcionais):

- `--host` (padrão `127.0.0.1`)
- `--port` (padrão `8080`)
- `--modo` (padrão `ok`) — modo inicial; pode ser trocado depois via `/_modo`
  sem reiniciar o servidor.

Encerrar com `Ctrl+C`.

## Rotas de negócio (contrato v1.0)

| Método | Rota | Descrição |
|---|---|---|
| POST | `/api/vendas/quitacao` | Confirma quitação de uma venda. Corpo: `{"vendaId": "1", "clienteId": "1", "valorTotal": 150.00, "itens": [...]}`. Sucesso: `200` com `{"vendaId", "status": "Quitada", "dataQuitacao"}`. |
| POST | `/api/vendas/cancelamento` | Cancela uma venda. Corpo: `{"vendaId": "1", "motivo": "opcional"}`. Sucesso: `200` com `{"vendaId", "status": "Cancelada"}`. |
| GET | `/api/vendas/{id}/status` | Consulta o estado em memória da venda. `200` com `{"vendaId", "status", "dataQuitacao"?}`. Venda nunca vista antes = `"Pendente"`. |

O estado (`status`/`dataQuitacao`) fica **em memória**, por `vendaId`; é
perdido ao reiniciar o processo.

## Rota administrativa: `/_modo`

Fora do contrato v1.0 — só para controlar o comportamento simulado durante o
teste manual. Aceita `GET` ou `POST`, com o parâmetro de query `m`:

```bash
curl "http://127.0.0.1:8080/_modo?m=ok"
curl "http://127.0.0.1:8080/_modo?m=recusa"
curl "http://127.0.0.1:8080/_modo?m=erro500"
curl "http://127.0.0.1:8080/_modo?m=timeout"
# ou: curl "http://127.0.0.1:8080/_modo?m=timeout-post"  (so POST atrasa; ver secao abaixo)
curl "http://127.0.0.1:8080/_modo?m=offline-simulado"
```

Sem `m` (`GET /_modo`), só relata o modo atual: `{"modo": "...", "modosValidos": [...]}`.

O modo é **global** e afeta as 3 rotas de negócio até ser trocado de novo:

| Modo | Efeito em POST quitação/cancelamento e GET status |
|---|---|
| `ok` (padrão) | Comportamento normal descrito na tabela acima. |
| `recusa` | Responde `400` com o envelope real do C# `{"erro":{"codigo","mensagem"}}` (T55; antes 422, que o C# nao usa) — simula recusa 4xx do Financeiro (RN mapeada para `Recusado` em ADR-004). Não altera o estado em memória. |
| `erro500` | Responde `500` com `{"mensagem": "..."}` — simula erro interno do Financeiro (`Indisponivel` em ADR-004). |
| `timeout` | Aguarda 11 s antes de responder (o cliente Delphi usa timeout padrão de 10 s lido do INI, ADR-004 — por isso o mock espera mais que isso) e só então responde normalmente. Serve para validar que o cliente classifica como `Indisponivel` sem travar além do timeout configurado. |
| `timeout-post` | Atrasa 11 s só a **resposta dos POSTs** (quitação/cancelamento); o efeito do POST é registrado no estado do mock ANTES do atraso e `GET /api/vendas/{id}/status` responde normal, sem atraso. Serve para provar a reconciliação T41 de ponta a ponta (POST estoura, GET confirma `Quitada`, sem reenvio: 1 POST no log). |
| `offline-simulado` | Derruba a conexão TCP sem escrever nenhuma resposta HTTP — simula servidor fora do ar / conexão recusada. O cliente deve receber uma falha de rede (mapeada para `Indisponivel`). |

## Roteiro de teste manual (critério de aceite da T05)

Com o servidor rodando em `127.0.0.1:8080` (ajuste a porta se usar outra):

```bash
# 1) Quitação em modo ok -> "Quitada" + dataQuitacao
curl -s -X POST http://127.0.0.1:8080/api/vendas/quitacao \
  -H "Content-Type: application/json" \
  -d '{"vendaId":"1","clienteId":"1","valorTotal":150.00,"itens":[{"produtoId":"1","quantidade":2,"precoUnitario":75.00}]}'
# -> {"vendaId": "1", "status": "Quitada", "dataQuitacao": "..."}

# 2) GET status reflete o estado em memória
curl -s http://127.0.0.1:8080/api/vendas/1/status
# -> {"vendaId": "1", "status": "Quitada", "dataQuitacao": "..."}

# 3) Cancelamento em modo ok -> "Cancelada"
curl -s -X POST http://127.0.0.1:8080/api/vendas/cancelamento \
  -H "Content-Type: application/json" \
  -d '{"vendaId":"2","motivo":"teste"}'
# -> {"vendaId": "2", "status": "Cancelada", "motivo": "teste"}

# 4) Modo recusa -> 4xx
curl -s "http://127.0.0.1:8080/_modo?m=recusa"
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://127.0.0.1:8080/api/vendas/quitacao \
  -H "Content-Type: application/json" -d '{"vendaId":"3"}'
# -> 400

# 5) Modo erro500 -> 500
curl -s "http://127.0.0.1:8080/_modo?m=erro500"
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://127.0.0.1:8080/api/vendas/quitacao \
  -H "Content-Type: application/json" -d '{"vendaId":"4"}'
# -> 500

# 6) Modo timeout -> excede 10 s
curl -s "http://127.0.0.1:8080/_modo?m=timeout"
time curl -s -m 20 -o /dev/null -w "%{http_code}\n" -X POST http://127.0.0.1:8080/api/vendas/quitacao \
  -H "Content-Type: application/json" -d '{"vendaId":"5"}'
# -> tempo total > 10 s (o mock espera 11 s)

# 7) Modo offline-simulado -> conexão cai, sem resposta
curl -s "http://127.0.0.1:8080/_modo?m=offline-simulado"
curl -s -m 5 -X POST http://127.0.0.1:8080/api/vendas/quitacao \
  -H "Content-Type: application/json" -d '{"vendaId":"6"}'
# -> curl reporta falha de conexão (ex.: "Empty reply from server" / connection reset),
#    sem corpo de resposta

# 8) Volta ao modo normal
curl -s "http://127.0.0.1:8080/_modo?m=ok"
```

Todos os 8 passos foram executados manualmente durante a implementação da
T05, com os resultados esperados confirmados (ver nota de status em
`.md/TASK.md`).

## Limitações conhecidas

- Estado em memória, não persiste entre reinícios.
- Servidor single-process (`ThreadingHTTPServer`); não pensado para carga,
  só para desenvolvimento/demo local.
- `/_modo` não tem autenticação — não expor fora de `localhost`/rede de
  desenvolvimento.

## Modo `timeout-post` e pior caso de espera síncrona (RF9-03 / T41 / A4)

Roteiro manual de ponta a ponta (T41, prova pendente do usuário na IDE):

1. Subir o mock (`python mock_financeiro.py`) e, se quiser partir de estado limpo, reiniciá-lo (o estado das vendas fica em memória). Não quite a venda antes via curl: o próprio modo `timeout-post` registra o efeito do POST, e uma quitação prévia acrescentaria um segundo POST ao log.
2. `curl "http://127.0.0.1:8080/_modo?m=timeout-post"`.
3. Na UI, Confirmar quitação de uma venda Pendente: o POST estoura (~10 s), o GET `/status` de reconciliação responde `Quitada` na hora.
4. Conferir: venda local Quitada (DATA_QUITACAO preenchida), `FILA_INTEGRACAO` sem item QUITACAO PENDENTE e exatamente 1 POST (o da confirmação) no log do mock, sem reenvio.

Pior caso de espera (A4): em `TQuitacaoService.Confirmar`, quando o POST estoura o timeout o cliente (`TFinanceiroClient`, Connection/Send/ResponseTimeout = `TimeoutMs` do INI) faz um GET `/status` de reconciliação com o mesmo timeout. Se ambos estourarem (mock `timeout`, ou Financeiro lento), a UI espera de forma síncrona até ~2x o timeout configurado: com o padrão de 10 s (`TIMEOUT_FINANCEIRO_PADRAO_SEGUNDOS`), ~20 s, depois a venda segue Pendente e vai para a fila (T40). Sugestão (não implementada, decisão do usuário): timeout menor (ex.: 3-5 s) só no GET de reconciliação.
