# ADR-006 — Ordem e consistência do fluxo de quitação (QuitacaoService)

- Status: Accepted
- Contexto: fluxo cruza Financeiro (fora de transação), banco local, PDF e SMTP.
- Decisão: sequência fixa e passos independentes:
  1. Validar venda Pendente e sem fila de QUITACAO/CANCELAMENTO pendente.
  2. POST quitação (fora de transação de banco; nenhuma transação aberta durante HTTP).
  3. Sucesso: **transação curta** grava STATUS=Quitada e DATA_QUITACAO (do Financeiro) e commit. Só depois disso segue.
  4. Gera PDF (ReportBuilder) a partir do banco.
  5. Envia e-mail; falha em 4 ou 5 => venda continua Quitada, item EMAIL na fila, mensagem ao usuário (INT-04).
  6. Indisponível: tenta GET /status uma vez (reconciliação); Quitada => passo 3; caso contrário item QUITACAO na fila, venda segue Pendente.
  Cancelamento análogo (sem PDF/e-mail). Cada passo devolve resultado tipado; o form apenas exibe a mensagem correspondente ao desfecho (enum `TDesfechoQuitacao`: QuitadaEmailEnviado, QuitadaEmailPendente, Recusada, FilaIndisponivel, Erro).
- Consequências: (+) sem estado inconsistente irrecuperável; janela residual: crash entre 2 e 3 => Financeiro Quitada e local Pendente; recuperável pelo GET /status ao reenviar (risco R-04 aceito). Nunca há e-mail antes da quitação confirmada (RN-06).
