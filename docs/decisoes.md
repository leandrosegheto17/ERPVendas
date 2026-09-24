# Decisões do projeto

Índice das decisões técnicas. O texto completo (contexto, alternativas, consequências) fica nos documentos de origem; aqui só há ponteiros.

## ADRs

Pasta: [`.md/adr/`](../.md/adr/README.md)

| ADR | Decisão (1 linha) |
|---|---|
| [001](../.md/adr/001-arquitetura-em-camadas-enxuta.md) | Arquitetura em 3 camadas enxuta, com composition root. |
| [002](../.md/adr/002-firebird-firedac-segregado.md) | Firebird 3.0 + FireDAC, banco segregado do Financeiro. |
| [003](../.md/adr/003-repositorio-hibrido-simplificado.md) | Entidades para escrita; consulta somente leitura para grades e relatório. |
| [004](../.md/adr/004-integracao-rest-sincrona-com-timeout.md) | Cliente REST com THTTPClient + System.JSON, síncrono com timeout, tolerante ao contrato v1.0. |
| [005](../.md/adr/005-fila-integracao-reenvio-manual.md) | Fila FILA_INTEGRACAO com reenvio manual e reconciliação por GET /status. |
| [006](../.md/adr/006-consistencia-fluxo-quitacao.md) | Ordem e consistência do fluxo de quitação (QuitacaoService). |
| [007](../.md/adr/007-email-indy-smtp-e-segredos.md) | E-mail via Indy TIdSMTP; configuração e segredos fora do repositório. |
| [008](../.md/adr/008-excecoes-log-e-config.md) | Tratamento central de exceções, log em arquivo e config INI. |
| [009](../.md/adr/009-mock-financeiro-script-simples.md) | Mock do Financeiro como script único fora do executável. |
| [010](../.md/adr/010-interfaces-de-repositorio.md) | Interfaces de repositório mantidas (supersede em parte ADR-001 e ADR-003). |
| [011](../.md/adr/011-tema-unico-e-design-tokens-ui.md) | Extra: tema único e design tokens centralizados na UI. |

## Decisões DEC-xx adotadas

Registro completo (opções e recomendação) na tabela da seção 8 de [`VISAO-PRODUTO.md`](../.md/VISAO-PRODUTO.md); status "adotadas" no fim da mesma seção.

| DEC | Decisão (1 linha) |
|---|---|
| DEC-01 | Banco Firebird 3.0. |
| DEC-03 | IDs no contrato como string (inteiro serializado). |
| DEC-04 | THTTPClient nativo para HTTP; Indy TIdSMTP para e-mail. |
| DEC-05 | Banco segregado do Financeiro. |
| DEC-06 | Mock do Financeiro em `tools/mock-financeiro/`. |
| DEC-07 | Sem autenticação na API no MVP (header opcional se o C# pedir). |
| DEC-08 | Recusa de quitação = 4xx com corpo de erro; venda segue Pendente. Não confirmada pelo C#. |
| DEC-09 | Só venda Pendente pode ser cancelada (409 caso contrário). Não confirmada pelo C#. |
| DEC-10 | Repositório híbrido: entidade para edição, DataSet para grade/relatório. |
| DEC-11 | Sem saldo de estoque em Produtos (fora do escopo). |
| DEC-12 | Prazo de desenvolvimento: sexta 25/09/2026. |
| DEC-13 | SMTP: Mailtrap/Ethereal em desenvolvimento; Gmail com senha de app opcional. |
| DEC-14 | Envio síncrono com timeout; falhas vão para a fila. |
| DEC-15 | Repositório privado ou sem credenciais. |

DEC-02 (versões/licenças de Delphi, DevExpress e ReportBuilder): resolvida na T01 com edições Community/trial/demo, registrada em [`ambiente-licencas.md`](ambiente-licencas.md).
Contrato do Financeiro: [`contrato-api-financeiro.md`](contrato-api-financeiro.md).
