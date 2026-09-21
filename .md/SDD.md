# SDD — ERP Vendas (Delphi) — RASCUNHO Rodada 1 (2026-09-21)

Base: PRD-TECNICO.md, VISAO-PRODUTO.md, CTO-REVIEW.md. ADRs em `.md/adr/`. Prazo: dev até sex 25/09 (D4 = feature freeze).

## 1. Visão Geral
Aplicação desktop Delphi (VCL + DevExpress) de cadastro de Clientes/Produtos/Vendas. Confirmar/cancelar venda chama a API REST JSON do ERP Financeiro (C#, contrato v1.0); após quitação gera PDF (ReportBuilder) e envia e-mail (SMTP). Falhas externas vão para uma fila local de reenvio manual. Fora do escopo: multiusuário/login, estoque, fiscal. Princípio: o mais simples que atenda o critério "camadas + boas práticas + decisões documentadas".

## 2. Componentes e Fluxo de Dados
```
UI (forms DevExpress finos)
  -> Negócio: ClienteService, ProdutoService, VendaService, QuitacaoService, FilaService
       -> Dados: Repositórios FireDAC (Cliente, Produto, Venda, Fila)  -> Firebird 3.0 (ERPVENDAS.FDB)
       -> Integração: IFinanceiroGateway (THTTPClient) -> ERP Financeiro C# / mock
                      IEmailSender (Indy SMTP)         -> SMTP
                      IRelatorioPedido (ReportBuilder) -> PDF
Transversal: Config (INI), Log (arquivo), Erros (hierarquia), Validadores (CPF/CNPJ/e-mail)
Composition root: App/ (monta dependências, injeta por construtor)
```
Regra de dependência: UI -> Negócio -> (interfaces do Domínio) <- Dados/Integração; Domínio (entidades, enums, exceções, 7 interfaces: `IClienteRepository`, `IProdutoRepository`, `IVendaRepository`, `IFilaRepository`, `IFinanceiroGateway`, `IEmailSender`, `IRelatorioPedido`) sem VCL/FireDAC. Forms sem SQL/HTTP (ADR-001, ADR-010). O composition root instancia os repositórios FireDAC e os injeta nos Services por interface.

Estrutura de pastas: a de VISAO-PRODUTO §2 mantida integralmente (`src/{App,Core,Dominio/Contratos,Negocio,Dados,Integracao,Relatorios,UI}`, `db/`, `config/`, `docs/`, `tools/`, `bin/`).

Fluxo de dados principal (Confirmar): UI -> QuitacaoService -> [POST quitacao] -> commit status local -> Relatório PDF -> e-mail; falha -> Fila (ADR-005/006). Diagrama e ordem em ADR-006 e PRD-TECNICO §4.

Tratamento de exceções: ADR-008. Classes: EValidacao/ERegraNegocio (mensagem ao usuário), EIntegracao/EInfra (mensagem amigável + log). Falhas esperadas de Financeiro/SMTP não são exceções para a UI: viram resultado tipado (ADR-004/006).

Regras de status: só Pendente é editável/excluível/cancelável; imposto no Service (a UI só reflete, desabilitando controles) e defendido no banco (CHECK de status).

## 3. Stack Tecnológica
| Item | Escolha | Justificativa / alternativa |
|---|---|---|
| Linguagem/IDE | Delphi (versão a fechar, DEC-02; alvo compatível 10.3+) | Obrigatório. Sem inline var, sem recursos de 11+/12+/13; sem generics avançados desnecessários |
| Acesso a dados | FireDAC | Obrigatório; driver FB (checar se Community inclui; senão trial) |
| Banco | Firebird 3.0, segregado | ADR-002 |
| UI | DevExpress VCL (cxGrid, cxTextEdit, cxMaskEdit, cxCurrencyEdit, cxDateEdit, cxLookupComboBox, dxBarManager/menu, cxButtons, dxLayoutControl opcional, dxSkinController opcional) | Obrigatório; versão a confirmar no D1 |
| Relatório | ReportBuilder (TppReport + ppPDFDevice/exportação PDF) | Obrigatório; validar marca d'água/PDF no trial no D1 |
| HTTP/JSON | THTTPClient + System.JSON | ADR-004; sem terceiros |
| E-mail | Indy TIdSMTP + OpenSSL | ADR-007 |
| Config/Log | INI (TIniFile) / arquivo texto | ADR-008 |
| Mock | Python stdlib | ADR-009 |
| Testes | Manuais (roteiro) | Sem framework de teste (desafio não exige) |
Custo: zero (Community/trial + FOSS). Sem dependências de DI/ORM/JSON de terceiros.

## 4. Decisões Arquiteturais (índice de ADRs)
| ADR | Decisão | Relação com VISAO-PRODUTO |
|---|---|---|
| 001 | 3 camadas; interfaces nas fronteiras externas; DI manual | Adota (trecho de repositórios superseded por ADR-010) |
| 002 | Firebird 3 + FireDAC, segregado, transações explícitas | Adota |
| 003 | Repositório híbrido entidade/DataSet | Adota |
| 004 | THTTPClient síncrono, timeout, tolerante a v1.0 | Adota + ajuste (não depende da v1.1; ApiKey opcional) |
| 005 | Fila manual, 1 pendente por venda+tipo, GET status antes de repostar | Adota + regras extras |
| 006 | Ordem do fluxo de quitação, commit curto sem transação durante HTTP | Novo |
| 007 | Indy SMTP; segredos no INI/variável de ambiente | Adota + ajuste |
| 008 | Exceções, log, INI | Adota |
| 009 | Mock em Python | **Precisa** (VISAO deixava aberto: Node/Python/Delphi) |
| 010 | Interfaces de repositório mantidas (4 novas, total 7) | Adota (como no VISAO) |

Divergências explícitas: (1) PDF não persistido, regenerado a partir do banco no reenvio; (2) PROXIMA_TENTATIVA presente no DDL mas sem uso; (3) `docs/decisoes.md` será um resumo apontando para estes ADRs, não duplicação; (4) senha SMTP também via variável de ambiente.

## 5. Modelo de Dados de Alto Nível
DDL de VISAO-PRODUTO §3 adotado sem mudança de tabelas/colunas: CLIENTES, PRODUTOS, VENDAS, VENDA_ITENS, FILA_INTEGRACAO (ADR-002 para ajustes de regra). Relações: CLIENTES 1-N VENDAS 1-N VENDA_ITENS N-1 PRODUTOS; VENDAS 1-N FILA_INTEGRACAO. Convenções: CPF/CNPJ só dígitos, status literais idênticos ao contrato, `vendaId/clienteId/produtoId` enviados como string do ID inteiro (DEC-03), preço em snapshot no item. Migração: `01_schema.sql` + `02_seed.sql` mínimo (2 clientes, 3 produtos) + `ERPVENDAS.FBK`.

## 6. Riscos Técnicos
| ID | Risco | Sev. | Mitigação / dívida aceita |
|---|---|---|---|
| R-01 | Prazo de 5 dias sem folga, dual-stack (ADR-010 soma ~0,5 dia de boilerplate nas interfaces, diluído em T02/T04) | Alta | Ordem P0->P1; cortes já assumidos; feature freeze D4; arquitetura enxuta (ADR-001) |
| R-02 | TLS Indy x OpenSSL (versão de DLL incompatível/32-64 bit) | Média | Spike de envio real D1/D2; fallback sem TLS no Mailtrap; DLLs empacotadas |
| R-03 | Contrato v1.1 (erros, 409, idempotência, DEC-08/09) não confirmado | Alta | Cliente tolerante (ADR-004); reconciliação por GET status (ADR-005); suposições registradas; dívida aceita: repostar quitação sem garantia de idempotência do C# |
| R-04 | Janela POST ok e crash antes do commit local | Baixa | Recuperável via GET status; aceita |
| R-05 | UI congela até timeout (síncrono) | Média | Timeout 10 s, cursor de espera, botões desabilitados; aceita (DEC-14) |
| R-06 | Trial DevExpress/ReportBuilder: marca d'água, PDF limitado, versão/compatibilidade | Média | T01 no D1; evidências (PDF/prints) na entrega; risco de expiração já mitigado pelo autor |
| R-07 | DEC-02 aberta (versão do Delphi) | Média | Sintaxe conservadora (10.3+); fechar no D1 |
| R-08 | Nome/posição de componentes DevExpress varia por versão | Baixa | UX-SPEC lista candidatos, sem fixar versão |
| R-09 | Sem testes automatizados | Média | Roteiro manual + mock com modos de falha; dívida aceita (não exigido) |
| R-10 | Log sem rotação; INI com senha em texto claro | Baixa | Arquivo por dia; INI fora do Git; variável de ambiente opcional; dívida aceita (app local, sem multiusuário) |
| R-11 | Reenvio manual pode ser esquecido | Baixa | Contador de pendências no menu/status bar |

Escalabilidade: não é requisito (uso desktop local monousuário); grades usam consultas com filtro para não carregar tudo. Sem gargalos previstos no volume do desafio.

## 7. Requisitos de Segurança (nível de arquitetura; SAST/DAST/hardening é do Validador)
- **Autenticação/autorização:** não há login (fora de escopo, INT). Autorização = regras de status no Service. API Financeiro: sem auth; `X-Api-Key` opcional pelo INI (DEC-07).
- **Segredos:** senha do banco, credenciais SMTP e ApiKey só em `erpvendas.ini` (no `.gitignore`) ou variável de ambiente; repositório só `erpvendas.ini.example` com valores fictícios; nenhuma chave de licença DevExpress/ReportBuilder no repo; nada disso no log; checagem por varredura (grep de senha/host reais) antes de cada commit/entrega.
- **Transporte:** HTTP local para o Financeiro é aceito em dev (`http://localhost`); configurável para HTTPS por INI sem mudar código. SMTP com STARTTLS/SSL quando o provedor exigir (ADR-007).
- **Injeção/integridade:** SQL sempre parametrizado; validação de CPF/CNPJ/e-mail/quantidade/preço no Service (não só na UI); CHECK/UNIQUE/FK no banco como segunda barreira; total calculado no servidor de regras, nunca digitado (RN-04).
- **LGPD básica:** dados pessoais (nome, CPF/CNPJ, endereço, telefone, e-mail) só o necessário aos requisitos; para o Financeiro vão apenas IDs, valores e itens (sem dados pessoais); log mascara CPF/CNPJ e e-mail e nunca grava corpo de mensagem; PDF enviado só ao e-mail do próprio cliente; PDFs temporários ficam em pasta configurada e são apagados após envio bem-sucedido (falha => regenerados no reenvio); exclusão de cliente = inativação (preserva histórico, com finalidade legítima), sem exclusão física com vendas; finalidade e retenção descritas em uma nota no README. Dados de demo: fictícios (seed com CPF de teste válidos, e-mails de sandbox).
- **Isolamento:** banco segregado do Financeiro (única ponte é a API); usuário Firebird da aplicação com privilégios mínimos (sem SYSDBA em produção; SYSDBA apenas em dev/documentado).
- **Exceções:** mensagens ao usuário nunca expõem SQL, caminho, stack ou credencial.
- **Deploy/empacotamento:** pasta `bin/`: `ERPVendas.exe`, `fbclient.dll` (mesma arquitetura do exe), `libeay32.dll/ssleay32.dll` (ou OpenSSL exigido pela versão do Indy), DLLs/BPLs de runtime somente se usar pacotes (preferir build sem runtime packages); `erpvendas.ini.example`; `db/01_schema.sql`, `02_seed.sql`, `ERPVENDAS.FBK`; `README.md` (passos: instalar Firebird 3, restaurar FBK com `gbak`, copiar INI, apontar Financeiro/SMTP, executar; limitações de trial); teste de instalação em pasta limpa no D5.
- **Estratégia de teste manual:** `docs/roteiro-testes-manuais.md` enxuto: CRUD e validações (CPF/CNPJ inválido, e-mail inválido, duplicidade); venda (sem itens, cliente/produto inativo, qtd 0, preço snapshot); regras de status (só Pendente edita); quitação OK + e-mail (Mailtrap) + PDF; mock modo recusa (4xx), 500, timeout -> fila -> Reenviar; falha de SMTP (senha errada) -> fila EMAIL; reconciliação (mock devolve Quitada no GET); cancelamento; INI ausente; instalação em pasta limpa. Evidências (prints/PDF) anexadas.
