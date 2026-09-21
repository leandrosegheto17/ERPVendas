# ADR-002 — Firebird 3.0 + FireDAC, banco segregado do Financeiro

- Status: Accepted
- Contexto: DEC-01/DEC-05 decididas pelo autor. Entrega exige DDL + .FBK.
- Alternativas: SQL Server (instalação pesada); banco compartilhado com o Financeiro (acoplamento).
- Decisão: Firebird 3.0, charset UTF8, banco exclusivo do Vendas; a única ponte com o Financeiro é a API. DDL do VISAO-PRODUTO §3 adotado como base (IDENTITY, BOOLEAN, NUMERIC(15,2), COMPUTED BY). Ajustes: (1) `FILA_INTEGRACAO` ganha índice único parcial lógico garantido por regra de negócio (uma pendência PENDENTE por venda+tipo); (2) `VENDA_ITENS` sem ON DELETE CASCADE de fato usado (venda Pendente é excluída explicitamente em transação; cascade fica como rede de segurança); (3) Connection: modo embedded/servidor via INI; transações explícitas (`StartTransaction/Commit/Rollback`) em toda operação multi-tabela.
- Consequências: (+) entrega leve; (-) fbclient.dll com a mesma arquitetura (32/64 bit) do exe deve ser empacotada. Sem evolução de schema versionada: `01_schema.sql` único (custo/benefício frente ao prazo).
