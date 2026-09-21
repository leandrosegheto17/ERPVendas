# GUARDRAILS — ERP Vendas (Delphi) — RASCUNHO inicial (proposto pelo Coordenador, 2026-09-21)

Status: aprovado pelo Gestor com ressalvas em 2026-09-21 (ver CTO-REVIEW.md). Regras inegociáveis; alterações só via Log de Alterações (PIPELINE-CONVENTIONS §5). Fontes: SDD.md, ADR-001..010, PRD-TECNICO.md, UX-SPEC.md, VISAO-PRODUTO.md.

## Escopo e prazo
1. Prazo de desenvolvimento: sex 25/09/2026. D4 (24/09) = feature freeze: depois dele só correção, integração, docs e pacote. Nenhuma funcionalidade nova. Não é funcionalidade nova concluir o que já está planejado no TASK.md: a fila enfileira no D4 (T37/T40/T43) e Reenviar/Pendências (Lote 13, T50-T53) fecham no fim do D4 ou na manhã do D5.
2. Ordem de trabalho: P0 antes de P1 antes de P2. Nenhuma tarefa P2 começa com P0/P1 pendente.
3. Escopo fechado: sem login/multiusuário, estoque, fiscal, reprocessamento automático da fila, threads no fluxo de integração. Requisito novo ou mudança de escopo é decisão do Gestor, não do Executor.
4. Cortes na ordem definida na Seção 4 do TASK.md; nunca cortar itens P0 nem README/DDL/.FBK/pacote.

## Arquitetura
5. Camadas: UI -> Negócio -> interfaces do Domínio <- Dados/Integração. Domínio sem Vcl/FireDAC/System.Net/Indy.
6. Forms não contêm SQL, chamada HTTP, SMTP nem regra de negócio; só coletam, chamam Service e exibem.
7. Só o composition root instancia classes concretas; injeção por construtor; sem framework de DI/ORM.
8. Regra de status (só Pendente edita/exclui/cancela) é imposta no Service e defendida pelo CHECK do banco; a UI apenas reflete.
9. ADR aceito é imutável: mudança de decisão = novo ADR com `Superseded by`. Ninguém edita ADR existente.
10. Toda decisão estrutural nova (fora do SDD/ADRs) gera ADR ou BLOCKERS antes de implementar.

## Dados e integração
11. SQL sempre parametrizado; escrita multi-tabela em transação explícita; transação nunca aberta durante chamada HTTP.
12. Dinheiro em `Currency`/`NUMERIC(15,2)`; nunca `Double`. JSON com ponto decimal, UTF-8, ISO 8601, independente do locale.
13. Contrato do Financeiro só muda registrado em `docs/contrato-api-financeiro.md` (fonte única) com data e status; cliente tolerante a v1.0.
14. E-mail somente após quitação confirmada pelo Financeiro (RN-06); falha externa nunca trava a aplicação: vira resultado tipado + fila; 4xx não reenfileira, 5xx/timeout reenfileira.
15. Banco do Vendas segregado; a única ponte com o Financeiro é a API REST.

## Segurança e privacidade
16. Nenhum segredo no repositório: senhas, credenciais SMTP, ApiKey, chaves de licença DevExpress/ReportBuilder, INI real, logs, PDFs gerados. Só `erpvendas.ini.example` com valores fictícios. Varredura antes de todo commit e da entrega (T63).
17. Log mascara CPF/CNPJ e e-mail, nunca grava senha, ApiKey ou corpo de mensagem; mensagem ao usuário nunca expõe SQL, caminho, stack ou credencial.
18. Ao Financeiro vão apenas IDs, valores e itens (sem dados pessoais). Dados de demo fictícios.
19. Cliente/produto com vendas é inativado, nunca excluído fisicamente.

## Stack e custo
20. Custo zero: Community/trial + FOSS; sem dependências de terceiros além das obrigatórias (FireDAC, DevExpress VCL, ReportBuilder, `THTTPClient`/`System.JSON`, Indy `TIdSMTP` + OpenSSL). Python só para o mock (ferramenta de dev, fora do pacote).
21. Sintaxe Delphi compatível com 10.3+ até DEC-02 ser fechada (sem inline var e recursos de 11+/12+/13); sem runtime packages.
22. Sem testes automatizados obrigatórios; toda tarefa tem critério de aceite manual verificável e o roteiro manual é mantido em `docs/roteiro-testes-manuais.md`.

## UX e qualidade
23. Acessibilidade não negociável: teclado completo, TabOrder, Enter/Esc, foco no campo inválido, status/erro nunca só por cor.
24. Toda tela com estados vazio/carregando/erro/sucesso conforme UX-SPEC §4 ou justificativa; componente fora do DevExpress/VCL padrão só marcado como [NOVO].
25. Documentação obrigatória: README, DDL, `.FBK`, `docs/decisoes.md` (resumo apontando para ADRs, sem duplicar); trial/licença documentado no README.
26. Commits pequenos por tarefa (`Txx: resumo`); nenhum código sem tarefa correspondente no TASK.md; sem `TODO` órfão.
27. Proibido cor, fonte ou tamanho solto em form/DFM: tudo vem de `ERPV.UI.Tokens`; estilo de grade e botão só via `ConfigurarGrade`/`EstilizarBotao`; mensagens ao usuário só via `Notificar` (sem `MessageDlg` direto); skin aplicado uma única vez com fallback nativo (ADR-011). T68 e T15 (MUST visual) não são cortados sem aval do usuário.

## Log de Alterações
| Data | Proposto por | Aprovado por | Mudança | Motivo |
|---|---|---|---|---|
| 2026-09-21 | coordenador | gestor | Criação do rascunho inicial com 26 regras | Loop C, Rodada 1: derivado de SDD, ADRs, PRD-TECNICO e VISAO-PRODUTO |
| 2026-09-21 | coordenador | gestor | Regra 27 adicionada (tokens, `Notificar`, skin único; T68/T15 MUST) | Loop C, Rodada 2: UX-SPEC v1.1 e ADR-011 (interface clean e profissional) |
| 2026-09-21 | gestor | gestor | Regra 1 esclarecida: conclusão de Reenviar/Pendências (Lote 13) no fim do D4/manhã do D5 não viola o feature freeze; removida linha em branco antes da regra 27; campo Status atualizado | Premissa do usuário (fila enfileira no D4, Reenviar fecha D4/D5); TASK.md Seção 6 item 3 |
