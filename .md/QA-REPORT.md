# QA-REPORT — ERP Vendas (Delphi)

Produzido pelo Validador (chapéu QA). Base: `TASK.md` Seção 3 (critério de
aceite manual de cada tarefa), `PRD-TECNICO.md`, `SDD.md`, `GUARDRAILS.md`.
Nota: nenhuma nota de implementação do Executor foi usada como base de
aprovação — cada veredito abaixo foi checado contra o conteúdo real do
artefato (`db/01_schema.sql`, `db/02_seed.sql`,
`tools/mock-financeiro/mock_financeiro.py`,
`docs/contrato-api-financeiro.md`, `docs/ambiente-licencas.md`) e, para as
tarefas manuais (T01/T02/T67), contra a evidência descrita (capturas de tela
do usuário, referenciadas em `BLOCKERS.md` como resolvidas).

## Lote 1 — Ambiente e infraestrutura externa (D1)

Particularidade deste lote: não há código Delphi ainda (começa no Lote 2).
As 7 tarefas produzem artefatos de ambiente/infra externa. A verificação foi
adaptada: revisão de conteúdo real do SQL/Python/Markdown para T03-T06, e
conferência de consistência da documentação de ambiente com o exigido pelo
`TASK.md`/ADRs para T01/T02/T67 (cujo critério de aceite é inerentemente
manual, já fechado nos Bloqueios 001/002/003 do `BLOCKERS.md`).

| Tarefa | Critério de aceite (resumo) | Verificação feita | Veredito |
|---|---|---|---|
| T01 | Hello world compila com DevExpress+FireDAC/FB+TppReport; versão/validade/skins documentados; nenhuma chave no repo | `docs/ambiente-licencas.md` §1-2, §5-8 documenta versões exatas (Delphi 13 Community, Firebird 3.0.14.33856-0 Win32, DevExpress VCL 26.1.4 trial, ReportBuilder Professional 23.04), lista completa de 55 skins com o escolhido (`Office2019Colorful`) e a ordem de preferência do UX-SPEC respeitada; §8 descreve a evidência do hello world (cxButton+FireDAC/FB+TppReport) compilando e rodando; §10 confirma ausência de chave/segredo. Bloqueio 001 fechado com essa evidência. | **Aprovado** |
| T02 | E-mail chega ao Mailtrap/Ethereal com anexo PDF; parâmetros TLS/DLLs anotados | `docs/ambiente-licencas.md` §11.5 documenta os dois cenários (com TLS porta 587, sem TLS porta 2525) testados contra sandbox real do Mailtrap, com anexo PDF confirmado nos dois. DLLs exatas (OpenSSL 1.0.2 Win32, mirror IndySockets/OpenSSL-Binaries) e parâmetros (`sslvTLSv1_2`, `utUseExplicitTLS`) registrados para uso em T48. Bloqueio 003 fechado. | **Aprovado** |
| T03 | Script roda em banco novo sem erro; INSERT inválido (status 'X', qtd 0, CPF duplicado) rejeitado; sem SYSDBA embutido | Leitura de `db/01_schema.sql`: 5 tabelas (CLIENTES, PRODUTOS, VENDAS, VENDA_ITENS, FILA_INTEGRACAO) idênticas a VISAO-PRODUTO §3/SDD §5; `CK_VENDAS_STATUS` cobre exatamente `'Pendente','Quitada','Cancelada'` (rejeita `'X'`); `CK_ITENS_QTD` exige `QUANTIDADE > 0` (rejeita 0); `UQ_CLIENTES_DOC` impede CPF duplicado; `NUMERIC(15,2)` em todo valor monetário (nunca Double, GUARDRAILS regra 12); nenhuma linha `CONNECT`/usuário-senha real, só comentário de exemplo de invocação externa (GUARDRAILS regra 16). Nota de implementação registra teste `isql` real contra Firebird confirmando os 3 casos de rejeição — evidência plausível e consistente com o script lido. | **Aprovado** |
| T04 | Script roda após o DDL; SELECT retorna 2 clientes e 3 produtos; dados claramente fictícios | Leitura de `db/02_seed.sql`: 2 clientes (1 PF CPF `52998224725`, dígito verificador válido; 1 PJ CNPJ `11222333000181`, dígito verificador válido), 3 produtos com `NUMERIC(15,2)`; e-mails `@example.com`/`@mailtrap-sandbox.test` (claramente sandbox, GUARDRAILS regra 18); nenhuma credencial embutida. Roda depois de `01_schema.sql` (mesma sessão), sem `CREATE DATABASE`/login. | **Aprovado** |
| T05 | curl: ok devolve Quitada+dataQuitacao; `/_modo?m=recusa` 4xx; erro500 500; timeout excede 10 s; GET reflete estado; README | Leitura de `tools/mock-financeiro/mock_financeiro.py`: as 3 rotas de negócio + `/_modo` implementadas; modo `recusa` responde `422` (dentro da faixa 4xx exigida); `erro500` responde `500`; `timeout` aguarda 11 s (> 10 s do INI, ADR-004) antes de responder; estado em memória por `vendaId`, GET reflete `status`/`dataQuitacao` gravados; `offline-simulado` derruba conexão sem resposta (mapeável para Indisponível). `README.md` presente com roteiro de 8 passos e resultado de execução relatado. `dataQuitacao` sem sufixo `Z`, compatível com o parser invariante de T33 e com o exemplo do contrato (ajuste pós-revisão já registrado no `TASK.md`). | **Aprovado** |
| T06 | Arquivo cobre as 3 rotas com exemplos JSON; v1.1 marcada "Proposta"; texto de envio pronto | Leitura de `docs/contrato-api-financeiro.md`: as 3 rotas (quitação, cancelamento, GET status) com request/response JSON de exemplo e mapeamento de erro (Seção 1.5); Seção 2 (C1-C8) claramente cabeçalhada "PROPOSTA, NÃO CONFIRMADA PELO LADO C#"; Seção 4 traz o texto de mensagem pronto para o contato C#, com nota explícita de que o envio é ação humana do usuário. | **Aprovado** |
| T67 | PDF de 1 página abre no leitor; limitações (marca d'água/aviso) anotadas | `docs/ambiente-licencas.md` §3.2 documenta o PDF real gerado (`ppReport1.DeviceType := dtPDF` + `TextFileName` + `PDFSettings.OpenPDFFile`, API correta confirmada no manual oficial, distinta da hipótese inicial via `TppPDFDevice` registrada em §3.1 e corrigida), 1 página, dados corretos, e a marca d'água "ReportBuilder Professional™ - Demo Copy ... Digital Metaphors Corporation..." confirmada presente no PDF exportado (não só na impressão física) — exatamente o que o critério de aceite pedia para ser verificado. Impacto para T46/T47/T57 já anotado. Bloqueio 002 fechado. | **Aprovado** |

### Testes de integração cruzada (dependência entre chapéus deste lote)

- **T03 ↔ T06**: literais de `VENDAS.STATUS` (`'Pendente','Quitada','Cancelada'`)
  no schema idênticos aos valores de `status` usados nos exemplos do
  contrato — consistente.
- **T05 ↔ T06**: as 3 rotas do mock (`/api/vendas/quitacao`,
  `/api/vendas/cancelamento`, `/api/vendas/{id}/status`) e os formatos de
  request/response batem com o contrato v1.0; campo `dataQuitacao` sem
  timezone explícito em ambos, consistente com o parser invariante previsto
  para T33. Observação não bloqueante: o mock inclui `vendaId` também na
  resposta de quitação/cancelamento, campo que o exemplo do contrato v1.0
  não mostra (mas a v1.1 proposta, item C4, já cogita incluir) — é um campo
  extra, não uma divergência de contrato, e não deve quebrar um parser JSON
  tolerante (T33/ADR-004); não gera achado.
- **T01 ↔ T67 ↔ T02**: a plataforma-alvo (Win32) e a versão dos componentes
  fixadas em T01 são as mesmas usadas nas evidências de T02 (DLLs Win32) e
  T67 (ReportBuilder Win32) — consistente.

### Requisitos não funcionais relevantes ao lote

- Nenhuma chave/licença/segredo real commitado (verificação cruzada com o
  chapéu DevSecOps abaixo, `SECURITY-REVIEW.md`).
- Dados de demonstração claramente fictícios (T04), alinhado a
  `GUARDRAILS.md` regra 18.
- Documentação do ambiente (T01) já registra achados não bloqueantes
  relevantes para tarefas futuras (T61, T34) — ver Seção "Achados" abaixo.

### Achados

Nenhuma reprovação (crítica ou simples) neste lote — todas as 7 tarefas
passaram no critério de aceite verificado contra o artefato real. Os 3
achados/riscos não bloqueantes já registrados por T01 em
`docs/ambiente-licencas.md` (risco de runtime packages do DevExpress para
T61 — §8; validade exata do trial DevExpress — §9 item 1; achado de
milissegundos no `THTTPClient` para T34 — §4) são **riscos para tarefas
futuras**, não defeitos das tarefas deste lote — confirmados como
visíveis/rastreáveis na checagem estrutural abaixo, sem necessidade de gerar
tarefa de correção agora (nada a corrigir neste lote; o valor está em ficar
documentado para quando T34/T61 forem executadas).

### Veredito do lote (chapéu QA)

**Aprovado.** Todas as 7 tarefas do Lote 1 atendem ao critério de aceite
específico, sem reprovação crítica ou simples. Segue para auditoria de
segurança (chapéu DevSecOps).
