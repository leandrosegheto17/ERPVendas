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

## Lote 2 — Núcleo Delphi (D1)

Particularidade deste lote (DEC-14, sem testes automatizados): T07-T11 têm
evidência de compilação/execução real na IDE registrada em rodadas
anteriores (confirmada pelo usuário); T12 e T13 foram verificadas de fato
nesta rodada, também na IDE, contra o banco real de T03/T04 — não estático.
A verificação abaixo não repetiu a compilação (fora do alcance deste
agente, mesma limitação documentada em T07 — Delphi Community não compila
via CLI): revalidou por leitura completa do código-fonte de todas as 15
units do lote contra cada critério de aceite específico, e conferiu que a
nota de Status de cada tarefa não foi usada como substituto dessa leitura.

| Tarefa | Critério de aceite (resumo) | Verificação feita | Veredito |
|---|---|---|---|
| T07 | Projeto vazio compila e abre janela; `git status` não lista INI/logs/binários; estrutura idêntica à de VISAO §2 | `ERPVendas.dpr/.dproj` (Win32, `TargetedPlatforms=1`, `DCC_UsePackages=false`) com as 8 pastas de camada em `DCC_UnitSearchPath`; `.gitignore` cobre `erpvendas.ini`, `config/*.ini` (com exceção do `.example`), `*.dcu/*.dcp/*.map`, `logs/`, `*.pdf`, `*.exe/*.res`, licenças (`*.lic/*.key`); `git status --porcelain` na worktree não lista nenhum artefato desses (working tree limpa). `ERPV.UI.FormMain.pas` é form fino real (só `Vcl.Forms/Controls/Dialogs` no `uses`, comentário explícito "nenhuma regra de negócio, SQL ou chamada HTTP aqui"). Compilação em si: evidência é a nota de Status (confirmação do usuário na IDE em rodada anterior), não repetida por este agente — sem motivo para desconfiar, consistente com o restante do código lido. | **Aprovado** |
| T08 | Compila sem `uses` de Vcl/FireDAC/System.Net/Id* nas units de Domínio; status literais = 'Pendente'/'Quitada'/'Cancelada' | Grep dedicado nas 13 units de `src/Dominio` (Entidades + Contratos): nenhuma referencia `Vcl.*`, `FireDAC.*`, `System.Net.*` ou `Id*` — só `System.SysUtils`, `System.Generics.Collections`, `Data.DB` (4 Contratos, para `TDataSet`, exceção explícita do ADR-010) e units internas `ERPV.Dominio.*`. `ERPV.Dominio.Enums.pas`: `STATUS_VENDA_STR = ('Pendente', 'Quitada', 'Cancelada')` e `TIPO_FILA_STR = ('QUITACAO', 'CANCELAMENTO', 'EMAIL')` — literais exatos exigidos, com conversão nos dois sentidos (`StrToStatusVenda` lança `EArgumentException` para desconhecido; `TryStrToStatusVenda` para uso tolerante). Compilação: nota de Status registra confirmação real do usuário na IDE. | **Aprovado** |
| T09 | Valores lidos do INI de teste; `.ini.example` só com dados fictícios; INI ausente ⇒ mensagem clara e saída controlada | `ERPV.Core.Config.pas`: `ValidarArquivo` lança `EConfiguracao` com mensagem clara orientando copiar o `.example` quando o arquivo não existe; `ValidarSecoesObrigatorias`/`LerObrigatoria` cobrem seção/chave ausente com a mesma orientação; segredos (`Banco.Senha`, `SMTP.Senha`, `Financeiro.ApiKey`) resolvidos com precedência de variável de ambiente sobre o INI. `config/erpvendas.ini.example`: todos os valores claramente fictícios (`senha_ficticia_dev`, `senha_ficticia_smtp`, Mailtrap sandbox, caminhos locais de exemplo) — nenhuma credencial real. Execução real confirmada pelo usuário na nota de Status (`BaseUrl` lido, `TimeoutMs` convertido corretamente). | **Aprovado** |
| T10 | Log criado na pasta configurada; CPF `12345678909` mascarado; senha em texto não é gravada | `ERPV.Core.Log.pas`: `MascararSensiveis` mascara CNPJ formatado/só-dígitos, CPF formatado/só-dígitos (regex com `\b` de fronteira de palavra, ordem CNPJ→CPF correta já que os dígitos têm tamanhos diferentes), e-mail (mantém 1º caractere + domínio), e redige `senha=/password=/apikey=/api_key=/token=/secret=` (case-insensitive) para `******` como rede de segurança extra. Toda gravação passa obrigatoriamente por essa função — não existe método público que grave string crua. Falha de gravação é engolida (best effort, `except` vazio comentado), nunca lança. Arquivo `<pasta>\erpvendas-AAAAMMDD.log`, `ForceDirectories` garante a pasta. Execução real confirmada pelo usuário na nota de Status (CPF/e-mail mascarados, senha redigida, arquivo criado). | **Aprovado** |
| T11 | Exceção não tratada mostra "Ocorreu um erro inesperado..." e stack/SQL só no log; `EValidacao` mostra o texto original | `ERPV.Core.Erros.pas`: `MensagemAmigavel` devolve `E.Message` literal para `EValidacao`/`ERegraNegocio`/`EInfraMensagemSegura`; mensagem genérica fixa para `EIntegracao`/`EInfra` (demais casos); texto literal exigido pelo critério ("Ocorreu um erro inesperado. Os detalhes foram gravados no log.") para qualquer outra exceção não mapeada. `TTratadorDeExcecoes.AoTratarExcecao` sempre grava o detalhe técnico completo via `FLogger.Erro` antes de mostrar a mensagem amigável via `MessageDlg(mtError)` — ordem correta (loga sempre, mostra só o amigável). Única classe do Core com `uses Vcl.Dialogs`, com justificativa documentada no cabeçalho (handler de `Application.OnException` não tem como evitar). Execução real dos 3 cenários (EValidacao/EInfra/Exception genérica) confirmada pelo usuário na nota de Status, incluindo o log com SQL/host presentes só no arquivo. | **Aprovado** |
| T12 | App conecta ao banco de T03; banco offline/senha errada ⇒ mensagem amigável sem SQL/caminho e detalhe no log | `ERPV.Dados.Conexao.pas`: `TConexao.Create` recebe `TConfiguracao`/`TLogger` prontos (DI por construtor, nunca instancia sozinha) e chama `Conectar` internamente. `Conectar` captura qualquer exceção do FireDAC, grava classe+mensagem original (pode ter Database/host/usuário) só no log via `FLogger.Erro`, e relança `EInfra.Create(MSG_FALHA_CONEXAO)` com mensagem fixa sem SQL/caminho/credencial — mesma mensagem para offline e senha errada (não distingue os dois cenários ao usuário, conforme exigido). `IniciarTransacao/Confirmar` seguem o mesmo padrão (mensagem fixa `MSG_FALHA_TRANSACAO`); `Desfazer` nunca relança (best effort, evita mascarar a exceção original). Nenhum SQL concatenado na unit (só conexão/transação). **Esta tarefa foi verificada de fato pelo usuário na IDE** (não é revisão estática): conectou ao banco real de T03/T04, log confirmou `EIBNativeException` completo em cenário de senha errada sem vazar a senha, tela mostrou só a mensagem genérica. | **Aprovado** |
| T13 | App inicia via root; nenhuma unit de Negócio/UI referencia classe concreta de Dados/Integração | `ERPV.App.Root.pas`: `TRootAplicacao.Create` monta a sequência exata Config→Log→Tratador (conectado a `Application.OnException`)→Conexão, todas por construtor. `TentarIniciarAplicacao` (única função de entrada usada pelo `.dpr`) captura `EInfra` (cobre `EConfiguracao`, que herda dela) na cadeia inteira, mostra `MensagemAmigavel` e devolve `False` sem criar form algum. `Destroy` libera na ordem inversa e zera `Application.OnException` antes de liberar o Tratador — evita handler apontando para objeto destruído. `ERPVendas.dpr` só cria `FormMain` se `TentarIniciarAplicacao` retornar `True`. Checagem de `uses`: nenhuma unit de Negócio/UI existe ainda além de `ERPV.UI.FormMain` (que não importa nada de `ERPV.Dados.*`/`ERPV.Core.Config` — só `Vcl.*`/`System.*` padrão) — critério cumprido para o que existe hoje; fica sujeito a nova checagem quando T14+ (Lote 3) forem criadas. **Esta tarefa foi verificada de fato pelo usuário na IDE**: cenário feliz (app abriu via root, sem erro), INI ausente (mensagem específica de `EConfiguracao`, sem crash), senha errada (mensagem genérica de `EInfra`, log com detalhe completo). | **Aprovado** |

### Achado durante a verificação manual de T12/T13 (revisado nesta rodada)

Registrado no `TASK.md` como achado real encontrado pelo usuário durante a
verificação em IDE de T12/T13 (não estático): `MensagemAmigavel` (T11)
tratava toda `EInfra` com o texto genérico fixo, o que descartava a
mensagem específica e útil de `EConfiguracao` (T09) — o usuário nunca via a
orientação "copie `config\erpvendas.ini.example`...". Corrigido no commit
`966a508`, antes do merge deste lote na `main`.

Revisão do Validador sobre a correção (`ERPV.Core.Erros.pas` +
`ERPV.Core.Config.pas`, lidos linha a linha acima): a solução criou
`EInfraMensagemSegura` como subclasse dedicada de `EInfra`, para o caso
específico de uma mensagem de infraestrutura que **o próprio construtor já
escreveu pensando no usuário final** e que é comprovadamente livre de dado
sensível; `MensagemAmigavel` checa essa subclasse antes da checagem mais
genérica de `EInfra` (`is EInfraMensagemSegura` antes de `is EInfra`, ordem
correta já que é mais específica). `EConfiguracao` passou a herdar dela em
vez de `EInfra` puro. Conferido de fato o conteúdo das 3 mensagens que
`EConfiguracao` pode lançar (`ValidarArquivo`/`ValidarSecoesObrigatorias`/
`LerObrigatoria`): todas contêm apenas o caminho do próprio `erpvendas.ini`
(informado pelo próprio usuário/ambiente, não um segredo) e uma instrução
de setup — nenhuma contém SQL, senha, ApiKey, host de banco/API ou stack.

**Concordância do Validador com o julgamento do Executor**: o caminho do
`erpvendas.ini` em si não é dado sensível sob ADR-008/GUARDRAILS — a regra
existe para não vazar SQL/host de banco/credencial/stack, não para esconder
onde fica o próprio arquivo de configuração que o usuário precisa editar
para corrigir o problema. A correção foi tratada corretamente como ajuste
direto de baixo risco durante T12/T13, não como reprovação: não altera o
comportamento de segurança de `EInfra`/`EIntegracao` em geral (a mensagem
genérica continua valendo para falha de banco/HTTP, que são os casos que
podem carregar SQL/host/credencial), é uma subclasse nova e explícita
(opt-in, não abre uma brecha geral), e a mudança foi limitada a exatamente
o caso já identificado como seguro. Não há motivo para reabrir como
reprovação — o mecanismo (`EInfraMensagemSegura`) inclusive melhora a
extensibilidade futura para outros casos similares (ex.: outras mensagens
de infraestrutura escritas para o usuário final), sem enfraquecer a regra
geral. Sem achado a registrar em `Refatoração Lote-2` sobre este ponto.

### `cross-platform-integration-testing`: N/A

Não se aplica a este lote (nem ao projeto): ERP Vendas é uma aplicação
desktop Windows única (Delphi VCL, Win32, sem app mobile/web paralelo
consumindo a mesma API neste projeto). Não há múltiplas plataformas
cliente para testar integração cruzada de UI — a única integração externa
real (Financeiro via REST) é tratada nos Lotes 6/8/9 (T33-T48), fora do
escopo do Lote 2 (que é infraestrutura interna: Config/Log/Erros/Conexão/
composition root, sem chamada HTTP ainda).

### Testes de integração cruzada (dependência entre chapéus deste lote)

- **T07 ↔ T08 ↔ T09 ↔ T10**: `ERPVendas.dproj` tem `src\Dominio\Entidades`
  e as demais 7 pastas de camada em `DCC_UnitSearchPath` desde T07 — T08/T09/
  T10 não precisaram tocar o `.dproj` para serem encontradas pelo compilador,
  consistente com a nota de cada tarefa.
- **T09 ↔ T11 ↔ T12**: `TConfiguracaoBanco` (T09, `Caminho/Usuario/Senha`)
  usada literalmente por `ERPV.Dados.Conexao.ConfigurarConnection` (T12) via
  `FConfiguracao.Banco.Caminho/Usuario/Senha` — assinatura bate campo a
  campo, sem campo inventado.
- **T10 ↔ T11 ↔ T12 ↔ T13**: `TLogger` (T10) injetado em `TTratadorDeExcecoes`
  (T11) e em `TConexao` (T12), ambos por construtor a partir de `TRootAplicacao`
  (T13) — nenhuma das duas classes instancia `TLogger` sozinha; conferido
  nos 3 arquivos.
- **T11 ↔ T09 (EConfiguracao)**: ver seção de achado acima — consistência
  confirmada após a correção.
- **T12 ↔ T13**: `TConexao.Create(Config, Logger)` chamado por
  `TRootAplicacao.Create` com a mesma assinatura documentada no cabeçalho de
  T12 (usado como "exemplo de referência, não implementado ali") — bate
  exatamente com a implementação real em T13.

### Requisitos não funcionais relevantes ao lote

- **Segurança de mensagem ao usuário (ADR-008)**: confirmado por leitura
  completa de `MensagemAmigavel`/`TConexao.Conectar`/`ConfigurarConnection`
  que nenhuma mensagem exibida via `MessageDlg` neste lote contém SQL,
  caminho de arquivo de dados, stack ou credencial — a única exceção
  deliberada (`EInfraMensagemSegura`/`EConfiguracao`) foi revisada acima e
  está correta.
- **Segredo fora do Git (ADR-007/008, GUARDRAILS)**: `erpvendas.ini` real
  ignorado pelo `.gitignore`; `.ini.example` só com dados fictícios;
  variável de ambiente com prioridade sobre o INI para os 3 segredos
  (`ERPV_BANCO_SENHA`, `ERPV_SMTP_PASSWORD`, `ERPV_FINANCEIRO_APIKEY`).
- **Mascaramento de log (SDD §7)**: confirmado na leitura de
  `MascararSensiveis` (T10) e na verificação manual real do usuário.
- **DI manual por construtor / composition root único (ADR-001)**: `TConexao`
  e `TTratadorDeExcecoes` nunca instanciam suas próprias dependências;
  `TRootAplicacao` (T13) é a única unit hoje que instancia classes
  concretas de Core/Dados — consistente com a regra "só o composition root
  instancia classes concretas".

### Fechamento estrutural do lote

Todas as 7 tarefas (T07-T13) estão `Concluída` no `TASK.md`. Nenhuma
dependência da Seção 4 relativa a este lote ficou órfã/inconsistente
(T08→T07; T09→T07; T10→T07,T09; T11→T10; T12→T03,T09,T11; T13→T08,T09,T10,
T11,T12 — todas as tarefas referenciadas já estão `Concluída`). Nenhuma
tarefa `Bloqueada` sem resolução no lote. Não há achado simples/débito
baixo-médio a registrar neste lote (o único achado real, tratado acima, foi
corrigido de forma completa e consistente pelo próprio Executor antes desta
validação, sem deixar débito residual) — **nenhuma tarefa criada em
`Refatoração Lote-2`**. Nenhuma inconsistência que exija redesenho de
dependência/decomposição — não há motivo para escalar ao `coordenador`.

### Achados

Nenhuma reprovação (crítica ou simples) neste lote — todas as 7 tarefas
passaram no critério de aceite verificado contra o artefato real (leitura
completa de código para T07-T11; verificação manual real na IDE,
confirmada e revisada pelo Validador, para T12/T13).

### Veredito do lote (chapéu QA)

**Aprovado.** Todas as 7 tarefas do Lote 2 atendem ao critério de aceite
específico, sem reprovação crítica ou simples, e sem achado pendente em
`Refatoração Lote-2`. Segue para auditoria de segurança (chapéu DevSecOps).

## Lote 3 — Casca de UI, tokens e tema (D2)

Base: critério de aceite de T14, T15, T68 e T69 no `TASK.md`, código real lido (`ERPV.UI.Tokens`, `ERPV.UI.Tema`, `ERPV.UI.Icones`, `ERPV.UI.FormMain`, `ERPV.UI.FormBaseLista`, `ERPV.UI.FormBaseEdicao`, `ERPVendas.dpr`, `assets/icones`), sem usar a nota do Executor como base. Limitação declarada: sem CLI de compilação (Delphi Community) e sem testes automatizados; a evidência de execução é a verificação real do usuário na IDE (2026-09-23), cruzada com a leitura do código. O Validador não recompilou. Nota: este lote foi validado depois de os Lotes 4 e 5 já consumirem suas bases (listas de Clientes/Produtos embutidas no `FormMain`, herdando de `TFormBaseLista`/`TFormBaseEdicao`), o que é evidência adicional de que as bases funcionam.

| Tarefa | Critério (resumo) | Verificação | Veredito |
|---|---|---|---|
| T68 | Skin aplicado; fallback sem skin; form de teste com grade zebra, 3 papéis de botão e `Notificar`; contraste AA; nenhuma cor fora dos tokens | Leitura: `AplicarTema`/`ConfigurarGrade`/`EstilizarBotao`/`Notificar` só usam `clERPV*`/`ERPVFontePrincipal`/`ERPVTam*`; estilos próprios (sem mutar valor lido, correção do AV). Execução real: skin Office2019Colorful, 3 papéis (T15), Notificar Info e Pergunta, zebra (T19/T23) | **Aprovado com ressalva** (itens já movidos para T60: fallback sem skin, Notificar Aviso/Erro, contraste AA medido; `clWhite` fora de token, RF3-01) |
| T15 | Filho herda base e abre; Esc fecha, Enter aciona OK; 3 papéis via `EstilizarBotao` | Leitura: só `Notificar` (sem `MessageDlg`), cores/fontes por token. Execução real com form filho temporário (removido): Esc, Enter, Tab, papéis, pergunta de descarte; e uso real por T19/T20/T23/T24 (Lotes 4/5) | **Aprovado** |
| T14 | Shell com faixa, navegação, 3 áreas da status bar; fallback de menu; URL do INI; Alt+letra; só tokens | Leitura: `FormMain` só depende de Tokens/Tema/Icones e Services (sem SQL/FireDAC/HTTP); item ativo em negrito (não só cor); destinos sem tela usam `Notificar(utnInfo)`. Execução real: faixa, nav lateral, status bar ("Financeiro: http://localhost:5000" do INI, "Pronto", "Pendências: 0"), Alt+letra | **Aprovado com ressalva** (fallback `ERPV_NAV_LATERAL` e DPI 125%/1366x768 não testados, já em T60; `clWhite`, RF3-01) |
| T69 | Ícones carregam em botões/navegação/status bar; licença registrada; nenhum botão só com ícone | Leitura: `AplicarIcone` nunca altera `Caption`; 48 PNGs (16 x 3 tamanhos) presentes em `assets/icones`; nomes = constantes `ERPVIcone*`; degrada sem exceção (try/except em todas as rotinas públicas). Execução real: ícones com texto na navegação e botões, transparência correta | **Aprovado** (ícones em menu de barra, erro/alerta/sucesso e pasta_vazia não plugados: declarado no TASK, observação) |

### Testes de integração (dentro do lote)

`FormMain` -> Tema/Icones -> bases -> listas de Clientes e Produtos exercitado pelo usuário na IDE (Lotes 4 e 5). `.dpr` chama `AplicarTema` antes de criar qualquer form e `FormMain.Configurar(BaseUrl, ...)`. Dependências T13 (INI/BaseUrl) e T07 satisfeitas.

### Observações (não são reprovação)

- Já declarados como pendentes/movidos: fallback de menu (`ERPV_NAV_LATERAL`) e DPI 125%/1366x768 não testados (T14); fallback sem skin, `Notificar` Aviso/Erro e contraste AA medido movidos para T60; ícones no menu de barra, erro/alerta/sucesso e `pasta_vazia` não plugados (T69); contorno pesado dos `TcxButton` na navegação = dívida visual.
- `clWhite` aparece também em `ERPV.UI.Tema.EstilizarBotao` (texto do botão Primário), não só no `FormMain`; `ERPV.UI.FormBaseLista.pas` está sem BOM (hoje só ASCII); `FormTesteTema` segue no `.dpr`. Tudo isso virou tarefa (abaixo).

### Fechamento estrutural

Todas as 4 tarefas `Concluída`. Dependências da Seção 4 (T14->T13,T68; T15->T07,T68; T68->T01,T07; T69->T68) resolvidas e não órfãs; os Lotes 4 e 5 já usaram as bases sem inconsistência. Nenhuma tarefa `Bloqueada`. Tarefas criadas em `Refatoração Lote-3` (fim da Seção 3 do `TASK.md`): RF3-01, RF3-02, RF3-03. Nenhuma escalação ao `coordenador`.

### Veredito do lote (chapéu QA)

**Aprovado com ressalvas.** Nenhuma reprovação crítica; ajustes simples viraram tarefas em `Refatoração Lote-3`. Segue para auditoria de segurança.

## Lote 4 — Cadastro de Clientes (D2)

Base: critério de aceite de T16-T20 no `TASK.md`, código real lido (`ERPV.Core.Validadores`, `ERPV.Dados.ClienteRepository`, `ERPV.Negocio.ClienteService`, `ERPV.UI.FormListaClientes`, `ERPV.UI.FormEdicaoCliente`), sem usar a nota do Executor como base. Limitação declarada: sem CLI de compilação (Delphi Community) e sem testes automatizados; a evidência de execução é a verificação real do usuário na IDE (2026-09-23), cruzada com a leitura do código. O Validador não recompilou.

| Tarefa | Critério (resumo) | Verificação | Veredito |
|---|---|---|---|
| T16 | CPF/CNPJ/e-mail válidos e inválidos da tabela | 5 casos executados pelo usuário (True/False/True/True/False); dígitos verificadores conferidos contra implementação independente (25.000 entradas, 0 divergências) | **Aprovado** |
| T17 | Operações refletidas no banco; lista filtra inativos; SQL parametrizado | Leitura: todo SQL usa `ParamByName`, sem concatenação de valor (só monta cláusulas fixas); busca com LIKE escapado; execução real de incluir/obter/alterar/existe/excluir; SQLs também validados em `isql` real | **Aprovado** (ver RF4-03) |
| T18 | Obrigatórios, validação T16, documento único, só dígitos | Leitura de `Validar`: nome, CPF/CNPJ (por tipo), e-mail, duplicidade ignorando o próprio Id; `uses` sem Vcl/FireDAC/Dados; execução real confirmou cada caso com o campo certo | **Aprovado** (texto sem acento, RF4-01) |
| T19 | Cabeçalho, chips de situação, busca, vazio, erro + Tentar novamente, sem SQL no form | Leitura: form só chama `TClienteService`, sem SQL/FireDAC; execução real aprovada (grade com seed, busca, inativos, Novo/Editar/Excluir) | **Aprovado** |
| T20 | Coluna única, erro no campo, máscara por tipo, Enter/Esc, botões nos papéis | Leitura: `EValidacao.Campo` vira erro no campo com foco no 1º inválido; execução real aprovada | **Aprovado com ressalva** (RF4-01; borda grossa, abaixo) |

### Testes de integração (dentro do lote)

Form -> Service -> Repository -> Firebird exercitado pelo usuário na IDE: incluir, editar, duplicado, inativar (lista filtra), excluir. Contrato `IClienteRepository` consistente entre Service e Repository. Dependência do Lote 3 (T14/T15/T68) satisfeita: lista embutida no `FormMain`, herda das bases.

### Observações (não são reprovação)

- Borda grossa dos campos da edição (T20): revisar na T60.
- T68: roteiro visual completo e contraste AA/"nenhuma cor solta" seguem como dívida conhecida (aval do usuário).
- Não verificados em execução: fallback de menu (T14), DPI 125% e 1366x768 (T60), busca com acento/caixa (RF4-03).

### Fechamento estrutural

Todas as 5 tarefas `Concluída`. Dependências da Seção 4 (T16->T07; T17->T08,T12,T03; T18->T16,T17; T19->T14,T15,T18; T20->T14,T15,T18) resolvidas e não órfãs. Nenhuma tarefa `Bloqueada`. Unit e chamada temporárias do teste da T18 (`ERPV.Temp.TesteT18`, `RodarTesteT18`) confirmadas ausentes do repositório. Nota: o cabeçalho do Lote 3 ainda não está marcado `Validado`; não bloqueia o Lote 4. Tarefas criadas em `Refatoração Lote-4` (fim da Seção 3 do `TASK.md`): RF4-01, RF4-02, RF4-03. Nenhuma escalação ao `coordenador`.

### Veredito do lote (chapéu QA)

**Aprovado com ressalvas.** Nenhuma reprovação crítica; 3 ajustes simples viraram tarefas em `Refatoração Lote-4`. Segue para auditoria de segurança.

## Lote 5 — Cadastro de Produtos (D2)

Base: critério de aceite de T21-T24 no `TASK.md`, código real lido (`ERPV.Dados.ProdutoRepository`, `ERPV.Negocio.ProdutoService`, `ERPV.UI.FormListaProdutos`, `ERPV.UI.FormEdicaoProduto`, integração em `ERPV.UI.FormMain`/`ERPV.App.Root`), sem usar a nota do Executor como base. Limitação declarada: sem CLI de compilação e sem testes automatizados; evidência de execução é a verificação real do usuário na IDE (2026-09-23), cruzada com a leitura do código. O Validador não recompilou. Aviso: os textos "Não compilado" nas células de T21/T23/T24 do `TASK.md` estão desatualizados (as mesmas células registram verificação real posterior).

| Tarefa | Critério (resumo) | Verificação | Veredito |
|---|---|---|---|
| T21 | CRUD no banco; lista com filtro de ativos | Leitura: SQL 100% parametrizado (`ParamByName`), LIKE escapado, preço `Currency`, transação com `Iniciou`/rollback, FK na exclusão mapeada; execução real: incluir (RETURNING), obter, alterar, listar sem/com inativos, excluir | **Aprovado** (RF5-01, RF5-02) |
| T22 | Preço -1 / descrição vazia recusados; válido persiste | Leitura de `Validar`: Trim, descrição, unidade, preço < 0 com `EValidacao.CreateCampo`; `uses` sem Vcl/FireDAC/Dados; execução real confirmou todos os casos (preço 0 válido) | **Aprovado** |
| T23 | Lista igual à T19: cabeçalho, chips, vazio, erro + Tentar novamente, "Inativo" visível | Leitura: form só chama `TProdutoService` (sem SQL/FireDAC), Tentar novamente, Excluir com confirmação, "Inativo" texto+cor; execução real aprovada (seed, preço pt-BR, busca, inativos, shell) | **Aprovado** |
| T24 | Preço pt-BR, gravado NUMERIC(15,2); erros do T22 no campo; layout/papéis de botão | Leitura: `cxCurrencyEdit` lido como Currency (sem Double), `EValidacao.Campo` mapeado para o campo; execução real aprovada (19,90, erros por campo, Salvar/Cancelar) | **Aprovado** |

### Testes de integração (dentro do lote)

Form -> Service -> Repository -> Firebird exercitado pelo usuário na IDE. Contrato `IProdutoRepository` consistente entre Service e Repository; `FormMain.Configurar(BaseUrl, ClienteService, ProdutoService)` e `AbrirDestino(dsProdutos)` integram a lista ao shell; `ERPV.App.Root` monta repositório e serviço. Teste temporário (`ERPV.Temp.TesteT22`, `RodarTesteT22`) confirmado ausente do repositório. Não aplicável: teste cross-platform (projeto Delphi VCL desktop) e API-CONTRACT (fora do escopo do lote).

### Requisitos não funcionais

Precisão monetária (Currency/NUMERIC(15,2)) ok; SQL parametrizado (sem injeção); erros logados e traduzidos para mensagem segura. Não verificados: DPI 125% e 1366x768 (T60), performance com volume.

### Achados (bug-documentation) — todos Simples, nenhum Crítico

- **RF5-01 (Simples):** mensagens fixas do repositório usam `EInfra` (handler global as trocaria pela genérica); `Excluir` sem verificar linhas afetadas (Id inexistente passa silencioso); busca com acento/caixa (`UPPER`) não verificada. Mesmo padrão de RF4-02/RF4-03. Sem impacto no critério de aceite.
- **RF5-02 (Simples):** DELETE de produto com item de venda (FK) não provado; só exercitável no Lote 6, e a regra "excluir = inativar" é da T30.

Padrão recorrente: RF5-01 repete RF4-02/RF4-03 (clones de Cliente). Sugere apenas corrigir o modelo antes de clonar de novo; não é problema de decomposição, sem escalação ao `coordenador`.

### Fechamento estrutural

T21-T24 `Concluída`. Dependências da Seção 4 (T21->T08,T12,T03; T22->T21,T11; T23->T14,T15,T22; T24->T14,T15,T22) resolvidas e não órfãs; T21 bloqueia T16/T17 e T25 (Lote 4 já validado, Lote 6 pendente), sem inconsistência. Nenhuma tarefa `Bloqueada`. Tarefas criadas em `Refatoração Lote-5` (Seção 3 do `TASK.md`): RF5-01, RF5-02.

### Veredito do lote (chapéu QA)

**Aprovado com ressalvas.** Nenhuma reprovação crítica; T21-T24 aprovadas; 2 ajustes simples em `Refatoração Lote-5`. Segue para auditoria de segurança (chapéu DevSecOps).

## Lote 6 — Vendas: dados e regras (D3)

Base: critério de aceite de T25-T30 no `TASK.md`, código real lido (`ERPV.Dados.VendaRepository`, `ERPV.Negocio.VendaService`, `ERPV.Negocio.ClienteService`, `ERPV.Negocio.ProdutoService`, `ERPV.App.Root`, uso de `TResultadoExclusao` em `FormListaClientes`/`FormListaProdutos`/`FormListaVendas`), sem usar a nota do Executor como base. Limitação declarada: sem CLI de compilação (Delphi Community) e sem testes automatizados; a evidência de execução é a verificação real do usuário na IDE (2026-09-23), registrada nas linhas de T25-T30 do `TASK.md` (testes temporários já removidos, então o Validador não os reexecutou nem os releu). O Validador não recompilou. Na coluna de verificação, "execução real" = relatado pelo usuário; "leitura" = conferido pelo Validador no código-fonte.

| Tarefa | Critério (resumo) | Verificação | Veredito |
|---|---|---|---|
| T25 | Venda com 2 itens atômica; erro no 2º item faz rollback do mestre; excluir apaga itens | Leitura: `Incluir`/`Alterar`/`Excluir`/`AtualizarStatus` usam uma única transação (`Iniciou := not EmTransacao`, `Confirmar` só se iniciou, `Desfazer` no except), `Incluir` restaura `AVenda.Id` no rollback; SQL 100% `ParamByName`; `Currency` em total e preço; nulos via `Clear`; falha vira `EInfra` amigável + log. Execução real: 2 itens (total 26,10), 2º item com quantidade 0 levanta `EInfra` e `VENDAS` antes = depois, `AtualizarStatus` Quitada com dataQuitacao relido, `Excluir` apaga mestre e itens | **Aprovado** (RF6-02) |
| T26 | Lista traz seed com nome e total; filtro por status; existência verdadeiro/falso | Leitura: `ListarDataSet` = TFDQuery somente leitura, filtros anexam cláusulas fixas com parâmetros (sem concatenar valor), `JOIN CLIENTES`, `VALOR_TOTAL`; `Existe*` = `SELECT FIRST 1` parametrizado (produto via `VENDA_ITENS`). Execução real: CLIENTE_NOME/VALOR_TOTAL, filtro Quitada exclui Pendente, Pendente+cliente traz, `ExisteVendaPorCliente/Produto` True/False | **Aprovado** (RF6-02) |
| T27 | Cada violação recusada com motivo; venda válida grava Pendente | Leitura de `Validar`: cliente informado, existente e ativo; >= 1 item; qtd > 0; produto existente e ativo, tudo com `EValidacao.CreateCampo` em português; `Id=0` força `svPendente` (RN-01); `uses` sem Vcl/FireDAC/Dados. Execução real: sem itens, qtd 0, cliente inativo/inexistente e produto inativo recusados; válida grava Pendente e relê | **Aprovado** |
| T28 | Total recalculado não aceita valor digitado; mudar preço do produto não altera itens gravados | Leitura de `AplicarPrecosETotal`: `Total` recalculado em `Currency` e sobrescreve `ValorTotal`; preço do item sempre vem do produto (item novo) ou do snapshot gravado (item já existente, casado por ProdutoId sem reutilizar o mesmo item antigo). Execução real: total e preço digitados ignorados, snapshot preservado após mudar preço, edição mantém snapshot e item novo pega preço atual | **Aprovado** (ver observação de regra) |
| T29 | Editar/excluir Quitada/Cancelada recusado; CHECK como 2ª barreira | Leitura: `ExigirPendente` lê o status do banco (não confia no objeto do chamador), levanta `ERegraNegocio` com mensagem por status; usado em `Salvar` (Id > 0) e `Excluir`. Execução real: editar e excluir Quitada e Cancelada recusados; excluir Pendente funciona. Ressalva de leitura: `Salvar` em edição não força `Status/DataQuitacao/Motivo` a partir do registro lido (RF6-01) | **Aprovado com ressalva** (RF6-01) |
| T30 | Cliente/produto com venda => inativa e informa; sem venda => exclui fisicamente | Leitura: `TClienteService.Excluir`/`TProdutoService.Excluir` chamam `ExisteVendaPorCliente/Produto` do `IVendaRepository` injetado; com venda: `Ativo := False` + `Alterar` e `reInativado`; sem: `Excluir` e `reExcluido`; `FormListaClientes`/`FormListaProdutos` já consomem o resultado (`Notificar` "foi inativado"). Execução real: sem venda excluídos fisicamente, com venda inativados e continuam com Ativo=False. Cobre RF5-02 | **Aprovado** |

### Testes de integração (dentro do lote)

- Contrato `IVendaRepository`: `TVendaRepository` cumpre a interface sem stubs restantes (os stubs de T26 foram substituídos; `IVendaRepository` inalterada). Consumidores conferidos por leitura: `TVendaService` (Obter/Incluir/Alterar/Excluir/ListarDataSet), `TClienteService`/`TProdutoService` (`ExisteVenda*`) e `TQuitacaoService` (`AtualizarStatus`, Lote 9).
- `TVendaService` -> `IClienteRepository`/`IProdutoRepository` (T17/T21): validação de cliente/produto ativo e snapshot de preço exercitados em execução real pelo usuário (T27/T28).
- `ERPV.App.Root`: `FVendaRepository` criado antes de `FClienteService`/`FProdutoService`, que o recebem por construtor; `FVendaService` recebe os três repositórios; liberação em ordem inversa antes de `FConexao`. A instanciação concreta fica só no Root (ADR-001).
- Consumo pela UI (Lote 7, `FormListaVendas`/`FormEdicaoVenda`) já usa `TVendaService` sem SQL no form; validação desse lote é separada.
- Não aplicável: teste cross-platform e `API-CONTRACT.yaml` (projeto Delphi VCL desktop; contrato fora do escopo do lote).
- Higiene: nenhum resquício de `ERPV.Temp.*` ou `RodarTeste*` em `ERPVendas.dpr`, `ERPVendas.dproj` ou `src/` (busca por texto, 0 ocorrências; `src/App` só tem `ERPV.App.Root.pas`).

### Requisitos não funcionais

- SQL parametrizado: todo valor entra por `ParamByName`; a única montagem dinâmica de SQL (`ListarDataSet`) concatena cláusulas fixas (constantes), nunca valores do usuário. Sem risco de injeção.
- Precisão monetária: `Currency` ponta a ponta (entidade, repositório, `Total` do service); sem `Double`. Coluna NUMERIC(15,2).
- Camada de Negócio sem Vcl/FireDAC: `uses` de `VendaService`, `ClienteService` e `ProdutoService` só têm `System.*`, `Data.DB` (para `TDataSet`, exceção já aceita nos contratos), Core e Domínio.
- Integridade transacional: mestre+itens atômicos (rollback comprovado em execução real).
- UTF-8: `VendaRepository`, `VendaService`, `ProdutoService` e `IVendaRepository` com BOM. `ClienteService` e `Root` sem BOM, mas 100% ASCII (0 bytes não ASCII), sem risco hoje; se receberem acento, precisam de BOM (relacionado a RF4-01, textos sem acento).
- Não verificados: performance com volume de vendas; concorrência (dois usuários editando a mesma venda); DPI/resolução (escopo de UI).

### Achados (bug-documentation) — todos Simples, nenhum Crítico

- **RF6-01 (Simples):** `TVendaService.Salvar` em edição (Id > 0) confirma que o registro do banco é Pendente, mas grava com `Alterar` o `Status`, `DataQuitacao` e `MotivoCancelamento` do objeto do chamador (`SQL_ALTERAR` atualiza esses campos). Um chamador que envie o objeto com `Status = svQuitada` transitaria a venda por fora de `AtualizarStatus`/`QuitacaoService` (o CHECK do banco não impede essa transição). Passos: obter venda Pendente, mudar `Status` para Quitada, chamar `Salvar`. Esperado: status inalterado (só `AtualizarStatus` muda). Obtido (por leitura, não exercitado): grava Quitada. Não afeta o critério de aceite de T29 (editar/excluir venda não Pendente é recusado, verificado em execução) e a UI atual não expõe o cenário; correção de uma linha: copiar `Status/DataQuitacao/MotivoCancelamento` de `Atual` antes de `Alterar`.
- **RF6-02 (Simples):** mesmo padrão de RF4-02/RF5-01: mensagens fixas do repositório levantadas como `EInfra` (`MSG_NAO_ENCONTRADA` em `Alterar`/`AtualizarStatus`) podem ser trocadas pela mensagem genérica no handler global; `ExisteVenda*` falha com a mensagem "consultar a venda" (operação 'obter'), imprecisa para cliente/produto; `Excluir` de venda com Id inexistente é silencioso (não verifica linhas afetadas). Sem impacto no critério de aceite.
- **RF6-03 (Simples, documentação/higiene):** `TASK.md` tem células de T28/T29/T30 terminando em "Detalhes:" sem conteúdo; T27 ainda cita "Teste temporário: `ERPV.Temp.TesteT27.pas` (remover)" e T25 cita conflito de merge de `Root.pas` com T17/T21, ambos já superados; o cabeçalho do `ERPV.App.Root` ainda diz que nenhum repositório/serviço foi implementado. Sem impacto funcional.

Observação de regra (não é reprovação; decisão de negócio, sinalizar ao usuário/Gestor): `Validar` recusa editar uma venda Pendente cujo item aponta para produto (ou cliente) inativado depois da criação, mesmo sem alterar aquele item. Coerente com RN-03 lida literalmente, mas impede corrigir a venda sem trocar o produto; decidir se a validação de "ativo" deve valer só para itens novos.

Padrão recorrente: RF6-02 repete RF4-02/RF5-01 (mensagem `EInfra` fixa e `Excluir` sem linhas afetadas); é padrão de modelo clonado, não de decomposição. Sem escalação ao `coordenador`. Este relatório não alterou o `TASK.md` (instrução do pedido); RF6-01..RF6-03 precisam entrar em `Refatoração Lote-6` (Seção 3) no fechamento estrutural.

### Fechamento estrutural

T25-T30 `Concluída`. Dependências da Seção 4 (T25->T08,T12; T26->T25; T27->T25,T17,T21; T28/T29->T27; T30->T18,T22,T26) resolvidas e não órfãs; T25 desbloqueia T31/T32 (Lote 7, já implementado) e T38-T43 (Lote 9) sem inconsistência; RF5-02 coberta pela T30. Nenhuma tarefa `Bloqueada`. Nenhuma escalação ao `coordenador`. Pendente, fora do escopo desta execução: registrar RF6-01..RF6-03 em `Refatoração Lote-6` (Seção 3 do `TASK.md`) e marcar o lote `Validado`.

### Veredito do lote (chapéu QA)

**Aprovado com ressalvas.** Nenhuma reprovação crítica; T25-T28 e T30 aprovadas, T29 aprovada com ressalva (RF6-01); 3 ajustes simples. Segue para auditoria de segurança (chapéu DevSecOps), que deve olhar em especial RF6-01 (transição de status por fora do fluxo de quitação).

## Lote 7 — Vendas: telas (D3)

Base: critério de aceite de T31 e T32 no `TASK.md`, UX-SPEC §2.4/§2.5/§4.1/§4.2/§5, e código real lido no estado atual da branch (`ERPV.UI.FormListaVendas`, `ERPV.UI.FormEdicaoVenda`, `ERPV.UI.FormBaseEdicao`, `ERPV.UI.FormMain`, `ERPVendas.dpr`/`.dproj`), sem usar a nota do Executor como base. Limitação declarada: Delphi Community não compila por CLI e não há testes automatizados; o Validador não recompilou nem executou o app. A **única evidência de execução** é a aprovação real do usuário na IDE em 2026-09-23 (registrada nas linhas T31/T32 do `TASK.md`), que cobre o fluxo geral (abrir Vendas, criar venda com itens, editar, total/chip, salvar) e dois achados já corrigidos (`cxDropDownEdit` no `uses`; `CellSelect=True` na grade de itens). O que o usuário não descreveu item a item (Visualizar de Quitada/Cancelada, filtros, vazio/erro, DPI) consta abaixo como "leitura" e **não** como provado em execução. Nota de estado: a main já trouxe o Lote 9 (T42); o código atual contém o botão Confirmar (lista e edição) e o helper `ERPV.UI.ConfirmacaoVenda`. A aprovação do usuário para T31/T32 é anterior a essa mudança; o veredito abaixo se restringe ao escopo T31/T32, e o que é de T42 é citado só como interferência.

### Validação por tarefa

| Tarefa | Critério (resumo) | Verificação | Veredito |
|---|---|---|---|
| T31 | Lista com colunas Nº/Data/Cliente/Total/Situação/Sinc; status como chip (texto+cor); valores à direita; Sinc reservada; botões por status (UX 4.2); "Cancelar venda" só no menu de contexto e dentro da venda; vazio/erro (UX 4.1); Novo/Editar abrem T32 e recarregam | **Execução real (usuário):** lista abre no menu Vendas, mostra vendas, Novo/Editar abrem a edição (fluxo geral aprovado). **Leitura:** 6 colunas conforme UX 2.4; Total formatado `R$ #,##0.00` pt-BR com alinhamento à direita (célula e cabeçalho); situação desenhada com texto em negrito + cor de fonte por token (`clERPVAvisoTexto`/`SucessoTexto`/`InativoTexto`); Sinc = coluna sem campo, vazia; `AtualizarEstado`: Pendente => Editar+Excluir; Quitada/Cancelada => Editar vira "Visualizar" e Excluir desabilitado; `AoExcluir` reconfere Pendente e pede confirmação; menu de contexto com "Cancelar venda" `Enabled := False`; painel vazio "Nenhum registro. Use Novo." e painel de erro com "Tentar novamente"; filtros Situação e Cliente (cliente inclui inativos) recarregam via `ListarDataSet`; recarrega só em `mrOk`. **Não provado em execução:** Visualizar de Quitada/Cancelada, filtros, menu desabilitado, vazio, erro, DPI 125% | **Aprovado com ressalvas** (RF7-03) |
| T32 | Cliente ativo em lookup; grade de itens editável (produto ativo, qtd inteira); preço/subtotal/total somente leitura; total em destaque; chip no cabeçalho; salvar sem item recusado; Quitada/Cancelada somente leitura com banner; preço não editável; hierarquia de botões | **Execução real (usuário):** criar/editar venda com itens, total, chip; achados corrigidos (`cxDropDownEdit`, `CellSelect`). **Leitura:** lookup de cliente e de produto só com ativos quando Pendente (todos quando somente leitura); Qtd = `TcxSpinEdit` inteiro, min 1; Preço/Subtotal com `Editing := False` e `Focusing := False`; total em fonte `ERPVTamTotalVenda` alinhado à direita; chip texto (maiúsculas) + cor por token; validação visual (cliente, >= 1 item, produto e qtd por linha) com ícone U+2716 + texto, e `EValidacao` do serviço mapeada por campo; `MontarVenda` envia **só** ClienteId, ProdutoId e Quantidade; total/preço exibidos são prévia, após Salvar relê por `Obter` (fonte de verdade = `TVendaService`, T27-T29); não Pendente: banner, controles desabilitados, Salvar oculto, Cancelar vira "Fechar"; "Cancelar venda" (botão perigoso) desabilitado com dica. **Não provado em execução:** abrir Quitada/Cancelada, banner, recusa "sem item/sem cliente" (mensagens inline), DPI | **Aprovado com ressalvas** (RF7-01, RF7-02) |

### Testes de integração (dentro do lote)

- Telas -> serviços: `TFormListaVendas` usa `TVendaService.ListarDataSet/Excluir` e `TClienteService.ListarDataSet` (filtro); `TFormEdicaoVenda` usa `Obter/Salvar` de venda, `ListarDataSet` de cliente e produto. Sem acesso a repositório/FireDAC nas duas telas (leitura de `uses` e corpo). Execução real: criar/editar venda de ponta a ponta pela tela (aprovação do usuário).
- Contrato T31 -> T32: `TFormEdicaoVenda.Create(Owner, VendaService, ClienteService, ProdutoService, VendaId)`, `ShowModal = mrOk` recarrega a lista; conferido por leitura e coberto pelo fluxo aprovado.
- `FormMain`: destino `dsVendas` cria `TFormListaVendas` embutida (`BorderStyle := bsNone`, `Align := alClient`, `OnFechada`), recebe `QuitacaoService`, liberada em `FecharListaVendas`/destruição; item "&Vendas" na navegação lateral e no menu. Conferido por leitura; a abertura pelo menu foi o fluxo aprovado.
- Interferência de T42 (não é escopo de T31/T32): botão Confirmar na barra de filtros da lista (TabOrder 2) e no cabeçalho da edição; `ERPV.UI.ConfirmacaoVenda` sem BOM com 8 linhas com caracteres não ASCII (risco de mojibake, mesmo problema já visto em T15) — registrado como RF7-05, mas pertence a T42/Lote 9.
- Higiene: `ERPVendas.dpr` e `ERPVendas.dproj` sem `ERPV.Temp.*`/`RodarTeste*` (0 ocorrências); as duas units estão referenciadas.
- Não aplicável: teste cross-platform e `API-CONTRACT.yaml` (VCL desktop; contrato fora do escopo do lote).

### Requisitos não funcionais (acessibilidade básica e padrões)

- Sem SQL nem regra de negócio nas telas: busca por `SELECT/INSERT/UPDATE/DELETE/.SQL/TFDQuery` nas duas units = 0 (o único match textual é `CellSelect`). Totais e preços vêm do serviço; a tela nunca envia preço/total como fonte.
- Notificações só por `Notificar`; sem `MessageDlg`/`ShowMessage`.
- Tokens/sem cor solta: nenhuma cor literal (`clRed`, `TColor(`) nas duas units; só `clERPV*` de `ERPV.UI.Tokens`, fontes por `ERPVFontePrincipal`/`ERPVTam*`.
- Cor sempre com texto: chip de situação com texto na lista e na edição; erro com ícone U+2716 + texto; banner com texto. Nota: a lista aplica só cor de **fonte** no chip (sem fundo), a documentação da unit fala em "fundo/fonte" (RF7-03, cosmético).
- Enter/Esc: vêm de `TFormBaseEdicao` (T15, aprovado em execução). Esc = descartar (pergunta se houver alteração); Enter = Salvar exceto em botão/memo. Risco: com o foco na grade de itens, Enter **não** é excluído e aciona `Confirmar` (RF7-01).
- TabOrder: lista: filtros 0/1, Confirmar 2 (T42), grade 1 no painel de conteúdo; edição: não há `TabOrder` explícito para os controles do form de venda, vale a ordem de criação (Confirmar de T42 no cabeçalho vem antes do Cliente; `Remover` criado antes de `Adicionar`, invertendo a ordem visual) — RF7-01. Não exercitado por teclado em execução.
- UTF-8: `FormListaVendas`, `FormEdicaoVenda` e `FormMain` com BOM.
- Não verificados: DPI 125%/150% (usa `EscalarPx` na edição; lista com larguras fixas de coluna e filtros em px), desempenho com muitas vendas, leitor de tela.

### Achados (bug-documentation) — todos Simples, nenhum Crítico

- **RF7-01 (Simples, teclado):** (a) `TFormBaseEdicao.KeyDown` trata Enter como Salvar sempre que o foco não é botão/memo; com a grade de itens em edição por célula, Enter para confirmar a célula pode gravar a venda inteira antes de o usuário terminar (não reproduzido; o usuário aprovou o fluxo geral). (b) A tela de venda não define `TabOrder`: Tab passa por Confirmar (T42) antes de Cliente e por Remover antes de Adicionar. Esperado (UX 5): Cliente -> Adicionar -> Remover -> grade -> Salvar/Cancelar. Correção: `TabOrder` explícito e, se confirmado (a), ignorar Enter quando `ActiveControl` for a grade/editor.
- **RF7-02 (Simples):** venda Pendente cujo item aponta para produto inativado depois: o lookup de produto (só ativos) exibe a célula vazia, e o serviço recusa salvar (observação de regra do Lote 6). Usuário vê linha "sem produto" sem explicação. Sem impacto no critério de aceite; alinhar com a decisão de negócio pendente do Lote 6.
- **RF7-03 (Simples, cosmético/doc):** chip de situação da lista só muda a cor da fonte (negrito), sem fundo como o chip da edição/UX-SPEC; texto sempre presente, então a regra "nunca só cor" está cumprida. Cabeçalho da unit cita "cor de fundo/fonte". Inclui higiene de `TASK.md`: T31 com "Detalhes:" vazio e T32 ainda dizendo "(não compilado)".
- **RF7-05 (Simples, fora do escopo T31/T32, pertence ao T42):** `ERPV.UI.ConfirmacaoVenda.pas` sem BOM com caracteres não ASCII. Além disso, `ConfirmarVendaClick` (edição) confirma a versão **gravada** da venda (relê `Obter`) e ignora alterações ainda não salvas na grade; validar no lote do T42.

Padrão recorrente: nenhum (RF7-01 é de base/ordem de criação, não de decomposição). Sem escalação ao `coordenador`. Este relatório não alterou o `TASK.md`; RF7-01..RF7-03 devem entrar em `Refatoração Lote-7` (Seção 3) no fechamento estrutural (RF7-05 vai para o lote do T42).

### Fechamento estrutural

T31 e T32 `Concluída`. Dependências da Seção 4 (T31->T14,T15,T26,T29; T32->T14,T15,T27,T28,T29) resolvidas, sem órfãs; T31 destrava T53 e T32 destrava T42/T44, sem inconsistência. Nenhuma tarefa `Bloqueada`. Pendências assumidas e fora do escopo: menu/botão "Cancelar venda" desabilitado até T43/T44; coluna Sinc vazia até T53. Pendente, fora desta execução: registrar RF7-01..RF7-03 em `Refatoração Lote-7` e marcar o lote `Validado`.

### Veredito do lote (chapéu QA)

**Aprovado com ressalvas.** Nenhuma reprovação crítica; T31 e T32 aprovadas com ressalvas (achados simples RF7-01..RF7-03); o critério central de cada tarefa está coberto pelo fluxo real aprovado pelo usuário e pela leitura do código, mas Visualizar de Quitada/Cancelada, filtros, vazio/erro e DPI **não** foram provados em execução. Segue para auditoria de segurança (chapéu DevSecOps).


## Lote 8 — Cliente REST do Financeiro (D3)

Base: critério de aceite de T33-T36 no `TASK.md`, `docs/contrato-api-financeiro.md` v1.0, ADR-004/005/006, Diretrizes (Seção 1), `tools/mock-financeiro/mock_financeiro.py` e código real lido (`ERPV.Integracao.FinanceiroDTOs`, `ERPV.Integracao.FinanceiroClient`, `ERPV.Dominio.Resultados`, `ERPV.Dominio.Enums`, `IFinanceiroGateway`, `ERPV.Core.Config`, consumo em `ERPV.Negocio.QuitacaoService`), sem usar a nota do Executor como base. Limitação declarada: sem CLI de compilação (Delphi Community), sem testes automatizados e sem execução contra o mock; **toda a verificação é por inspeção estática**. T33-T36 estão "Concluída — pendente de confirmação de compilação/execução na IDE". "Leitura" = conferido pelo Validador no código-fonte.

| Tarefa | Critério (resumo) | Verificação (leitura) | Veredito |
|---|---|---|---|
| T33 | JSON com `valorTotal` ponto/2 casas, ids string, `itens[]` conforme contrato; parse de `Quitada`+`dataQuitacao` com pt-BR ativo | `FinanceiroFormatSettings` (en-US + separadores explícitos, nunca o `FormatSettings` global); `CurrToStrF(ffFixed,2)` => `350.90`, sem milhar; `TJSONNumber.Create(string)` preserva o texto; `vendaId/clienteId/produtoId` = `TJSONString`; `quantidade` inteiro; nomes e ordem de campos idênticos ao contrato; `motivo` omitido se vazio; parse por `ISO8601ToDate(...,False)` (independe de locale, sem conversão de fuso); `status` via `TryStrToStatusVenda` (fora do enum => False); `Quitada` exige `dataQuitacao` válida; campos extras e `vendaId` ausente tolerados; `try/finally` libera os objetos JSON. Sem Vcl/FireDAC/System.Net; `uses` só Domínio + `System.*`; sem `inline var`; BOM presente. Ressalva: RF8-01 | **Aprovado com ressalva** (RF8-01) |
| T34 | Contra o mock: ok => Sucesso; recusa => Recusado (mensagem ou fallback "código HTTP xxx"); erro500/timeout => Indisponível sem travar além do timeout; servidor parado => Indisponível | `THTTPClient` síncrono; `ConnectionTimeout/SendTimeout/ResponseTimeout := TimeoutMs` (já em ms, `TimeoutSegundos*1000`); `X-Api-Key` só se `Trim(ApiKey) <> ''` e nunca logada; rota/método batem com o mock; 2xx => parser (válido => `Sucesso(Status,Data)`, inválido => `RespostaInvalida`); 4xx => `Recusado(codigo, mensagem do corpo ou fallback "... (codigo HTTP xxx)")`, compatível com o 422 `{"mensagem":...}` do mock; 5xx e demais => `Indisponivel(codigo)`; exceção de rede/timeout capturada em `Executar` e devolvida como `Indisponivel(0,...)` (mock `timeout` dorme 11 s > 10 s; `offline-simulado` derruba o socket; mock parado recusa conexão: os três caem no `except`); log só método/rota/código/nome da classe da exceção, sem corpo, cabeçalho ou chave; `HandleRedirects := False`; `try/finally` libera `THTTPClient` e stream; `Enviar` genérico reutilizado por T35/T36. Ressalva: RF8-01 (exceção pode escapar do parser) | **Aprovado com ressalva** (RF8-01) |
| T35 | Mock: ok => Cancelada; recusa/500 mapeados como em T34 | POST `/api/vendas/cancelamento` (bate com o mock); corpo `{"vendaId":"1042","motivo":...}` (motivo omitido se vazio); 2xx com `svCancelada` => `Sucesso`; 2xx com outro status (ex.: Quitada) ou corpo inválido => `RespostaInvalida`; 4xx/5xx/rede pelo mesmo `Enviar` | **Aprovado** |
| T36 | Mock devolve Quitada/Pendente e o cliente converte para enum; status desconhecido => RespostaInvalida | GET `/api/vendas/{id}/status` (id via `IntToStr`, bate com o mock); `Status` por `TryStrToStatusVenda`; desconhecido/corpo inválido => `RespostaInvalida`; 404 => `Recusado` (contrato 1.3); `vendaId` opcional/tolerante; sem corpo enviado | **Aprovado** |

### Testes de integração (dentro do lote)

- Contrato `IFinanceiroGateway`: `TFinanceiroClient` implementa as 3 assinaturas idênticas às da interface, retornando `TResultadoFinanceiro` do Domínio; sem stubs restantes.
- Consumidor `TQuitacaoService` (leitura): trata `rfSucesso` (exige `svQuitada`, usa `DataQuitacao`, `0 => Now`), `rfRecusado` (mensagem íntegra, fallback com código), `rfIndisponivel` (reconcilia por `ConsultarStatus` antes de enfileirar) e `rfRespostaInvalida`. Coerente com o mapa do cliente: `CodigoHttp` 0 em falha de rede, código real em 5xx; `Sucesso` do GET status vem com `DataQuitacao = 0`, e o serviço já cobre com `Now`.
- Mock x cliente (leitura): rotas, métodos, códigos (422/500), corpo `{"mensagem"}`, `vendaId` string e `dataQuitacao` sem timezone são tratados pelo cliente. O mock gera a data em UTC; o cliente não converte fuso (contrato: horário local assumido igual), diferença só visível se a máquina não estiver em UTC (T55/C# real).
- Composition root: `TFinanceiroClient` ainda não é instanciado em `ERPV.App.Root` (entra em T38, conforme nota do Executor); não é reprovação de T33-T36.
- Não aplicável: cross-platform e `API-CONTRACT.yaml` (projeto Delphi VCL desktop; referência é `docs/contrato-api-financeiro.md`).

### Requisitos não funcionais

- Timeout em ms nas 3 propriedades; sem threads; nenhuma transação de banco no cliente (ADR-006).
- Segurança: `X-Api-Key` e corpo nunca logados; exceção de rede reduzida ao nome da classe (sem URL). Sem Vcl/FireDAC em Integração e Domínio (busca por texto: só comentários).
- Locale: nenhuma conversão numérica/data dos DTOs depende do locale do SO.
- Delphi 10.3: sem `inline var`. UTF-8: `DTOs` com BOM; `Client` sem BOM mas 100% ASCII (0 bytes não ASCII).
- Não verificados: comportamento real de timeout (teto de 10 s), performance.

### Achados (bug-documentation) — todos Simples, nenhum Crítico

- **RF8-01 (Simples):** `TryIsoToDateTime` só captura `EConvertError`, mas `ISO8601ToDate` (System.DateUtils) levanta `EDateTimeException` em data inválida (conhecimento da RTL, não exercitado; confirmar na IDE). Passos: resposta 200 de quitação com `"dataQuitacao":"xx"` ou `2026-13-40T99:00:00`. Esperado: `RespostaInvalida`. Obtido (por leitura): exceção escapa de `TryParseQuitacaoResponse`, atravessa o método anônimo e `Enviar` (que só protege `Executar`) e chega ao `QuitacaoService`, contrariando "sem exceção para falha esperada". Cenário raro (Financeiro mal-comportado); correção de uma linha: `TryISO8601ToDate(Valor, Data, False)` ou capturar `Exception`; opcionalmente `try/except` em volta de `AInterpretar` em `Enviar`.
- **RF8-02 (Simples, documentação):** nota de T34 no `TASK.md` diz que T35/T36 "são stubs Indisponível", já superado; nota de T33 cita `EConvertError`/`ISO8601ToDate` sem a ressalva de RF8-01.

Observações (não são reprovação): (a) `ConsultarStatus` ignora `dataQuitacao` do GET (contrato v1.0 não a define; o mock a envia), então a reconciliação de T41 grava `Now`; considerar lê-la se o C# confirmar (T55). (b) Os timeouts do `THTTPClient` são por operação, não um teto total.

Padrão recorrente: nenhum. Sem escalação ao `coordenador`. Este relatório não alterou o `TASK.md`; RF8-01/RF8-02 precisam entrar em `Refatoração Lote-8` (Seção 3) no fechamento estrutural.

### O que só a execução na IDE/mock confirma (ressalva, não reprovação por si só)

1. Compilação (Shift+F9) de `DTOs` e `Client` com 0 erros; em especial a disponibilidade em 10.3 de `THTTPClient.SendTimeout`, do construtor `TStringStream.Create(string, TEncoding, Boolean)` e das assinaturas `Get/Post` com `TNetHeaders`.
2. Roteiros manuais dos cabeçalhos das units contra o mock (porta 8101): modos `ok`, `recusa` (422 + mensagem), `erro500`, `timeout` (retorno em ~10 s, `CodigoHttp 0`), `offline-simulado`, mock parado; `X-Api-Key` presente só com chave configurada. Nota: o mock devolve 200 `Pendente` para id desconhecido, então o 404 do passo 10 só se exercita em rota errada.
3. Saída de `SerializarQuitacaoRequest` idêntica ao exemplo do contrato com locale pt-BR ativo; `TryParseQuitacaoResponse` retornando `22/09/2026 14:35:12`.
4. Tipo real da exceção de RF8-01.

### Fechamento estrutural

T33-T36 `Concluída` (pendentes de confirmação na IDE). Dependências da Seção 4 (T33->T08,T09; T34->T33,T05,T11; T35/T36->T34) resolvidas e não órfãs; T34 desbloqueia o Lote 9 (já usa `IFinanceiroGateway`). Nenhuma tarefa `Bloqueada`. Nenhuma escalação ao `coordenador`. Pendente, fora do escopo desta execução: registrar RF8-01/RF8-02 em `Refatoração Lote-8` e marcar o lote `Validado`.

### Veredito do lote (chapéu QA)

**Aprovado com ressalvas.** Nenhuma reprovação crítica; T35 e T36 aprovadas, T33 e T34 aprovadas com ressalva (RF8-01); 2 ajustes simples; ressalva geral de compilação/execução pendente na IDE/mock. Segue para auditoria de segurança (chapéu DevSecOps), que deve olhar em especial `X-Api-Key`, logs e a exceção que escapa em RF8-01.

---

## Lote 9 — Fluxo Confirmar venda (T37-T42) — chapéu QA (2026-09-23)

Método: inspeção estática rigorosa (Delphi Community não compila via CLI; T37-T42 seguem "pendente de confirmação na IDE"). Lido: `ERPV.Dados.FilaRepository`, `ERPV.Negocio.QuitacaoService` (Confirmar T38-T41; Cancelar/T43 só para coerência), `ERPV.UI.ConfirmacaoVenda`, trechos de `FormListaVendas`/`FormEdicaoVenda`/`FormMain`, `ERPV.App.Root`, `.dpr`/`.dproj`, contra `db/01_schema.sql`, UX-SPEC §4.2/§4.3, ADR-005/006. Nada foi executado.

### Critérios (acceptance-criteria-validation)

| Tarefa | Critério | Resultado (por leitura) |
|---|---|---|
| T37 | 1 PENDENTE por venda+tipo; 2x => 1 linha, tentativas 2; CONCLUIDO seta `CONCLUIDO_EM`; `ULTIMO_ERRO` truncado em 500 | OK. SQL confere com o schema (tabela `FILA_INTEGRACAO`; colunas `VENDA_ID, TIPO, STATUS, TENTATIVAS, ULTIMO_ERRO, PROXIMA_TENTATIVA, CRIADO_EM, CONCLUIDO_EM`; literais `PENDENTE/CONCLUIDO/QUITACAO`). Busca de PENDENTE + UPDATE (+1) ou INSERT (TENTATIVAS=1) na mesma transação curta (só abre/fecha se o chamador não abriu); `Copy(...,1,500)`; `MarcarConcluido`/`RegistrarFalha` com `RowsAffected=0 => EInfra`; falha FireDAC => `EInfra` amigável + log, sem SQL. Unicidade só no código (sem índice único parcial; aceitável monousuário, ADR-005). |
| T38 | Exige Pendente antes do POST; sem transação durante HTTP; commit curto | OK. `Obter` do banco, `ERegraNegocio` se nulo/não Pendente antes do POST; entidade liberada no `finally`; `AtualizarStatus(Quitada, Data)` isolado; `Data=0 => Now`; 200 com status diferente de Quitada => `qdRespostaInvalida` sem efeito. |
| T39 | Recusa não grava nem enfileira | OK. Ramo `rfRecusado` só mapeia; mensagem íntegra, fallback com código HTTP. |
| T40 | Indisponível enfileira QUITACAO; falha ao enfileirar não mascara | OK no service: `EnfileirarIndisponivel` grava `tfQuitacao` com `ULTIMO_ERRO`; `EInfra` capturado => segue `qdIndisponivel` com aviso na Mensagem. Ver A2 (texto da UI). |
| T41 | GET status antes de enfileirar; Quitada => conclui local sem repostar | Lógica OK (`ConsultarStatus` em `rfIndisponivel`; Quitada => `AtualizarStatus` + `qdSucesso`, sem fila, sem novo POST). Não provável de ponta a ponta com o mock atual (R1). |
| T42 | Textos UX 4.3 literais via `Notificar`; cursor/botões restaurados em `finally`; Confirmar só para Pendente | Textos idênticos ao 4.3 (pergunta com `R$ 350,00` pt-BR, indisponível, recusa, resposta inválida); Info=banner, Aviso/Erro=modal, sem `MessageDlg` direto; cursor, `Enabled` e rótulo restaurados em `finally`; lista habilita só Pendente + service injetado; edição só venda gravada e não somente-leitura. Reprovada por A1. |

Lacunas conhecidas e aceitas (não são reprovação): e-mail no texto de sucesso = T49; bloqueio de Confirmar por fila pendente = T53.

### Achados (bug-documentation)

- **A1 — CRÍTICA (T42; afeta mensagens de T37-T41): fontes com acentos sem BOM.** `ERPV.UI.ConfirmacaoVenda.pas` (8 linhas não ASCII), `ERPV.Negocio.QuitacaoService.pas` (10) e `ERPV.Dados.FilaRepository.pas` (3) estão em UTF-8 sem BOM; todas as demais units com acento têm BOM. O Delphi 10.3 lê fonte sem BOM como ANSI: "indisponível", "Quitação", "Ação", "Pendências" saem com mojibake, e o critério central de T42 é o texto literal de UX 4.3 (também afeta fallback do service, `ULTIMO_ERRO` e mensagens de `EInfra` da fila). É o RF7-05 do Lote 7, ainda em aberto. Correção: regravar as 3 units em UTF-8 com BOM (esforço mínimo) e conferir os textos no modal na IDE. Crítica por comprometer o aceite literal; T42 volta a `Em andamento`.
- **A2 — Simples (T40/T42):** a UI diz "foi colocada na fila" mesmo quando enfileirar falhou; `TextoDesfechoQuitacao` ignora o aviso que o service põe em `Mensagem`. O service não mascara (critério de T40 cumprido), a UI sim. Sugestão: flag `Enfileirado` no resultado e Aviso alternativo.
- **A3 — Simples (T42, RF7-05, edição):** `ConfirmarVendaClick` usa `FVendaService.Obter(...).ValorTotal` do banco; alterações não salvas na grade são ignoradas na pergunta. Exigir salvar antes ou desabilitar com grade suja.
- **A4 — Simples (T40):** em timeout/5xx o fluxo faz POST (até `TimeoutMs`) e depois GET de reconciliação (mais até `TimeoutMs`): pior caso ~2x o timeout (~20 s), UI síncrona travada. Considerar timeout menor no GET ou aviso; verificar na IDE.
- **A5 — Simples (documentação):** cabeçalho de `QuitacaoService` cita `FILA_SINCRONIZACAO` (tabela real: `FILA_INTEGRACAO`) e `STATUS=QUITADA` (literal do banco: `Quitada`).
- Cosmético: recusa concatena `mensagem + '. '`; se o Financeiro já terminar com ponto, sai "..".

### RF6-01 e RF8-01: risco para este lote

- **RF6-01: risco BAIXO, não bloqueia T38.** `Confirmar` lê o status do banco e só aceita Pendente; `AtualizarStatus` é o único caminho de quitação; a UI de edição nunca atribui `Status` (default `svPendente`), então a brecha (Salvar com objeto Quitada marcar quitada sem POST) não é atingível pela UI atual. Manter como defesa em profundidade antes do Lote 16/T54.
- **RF8-01: risco MÉDIO-BAIXO, alcançável.** Um 200 do POST com `dataQuitacao` malformada faz `EDateTimeException` atravessar `TFinanceiroClient.Enviar` e `Confirmar`: o Financeiro pode ter quitado, a venda local segue Pendente, nada é gravado nem enfileirado, e a UI mostra o "erro inesperado" genérico (sem "Resposta inesperada", sem fila), quebrando "falha esperada vira resultado tipado". Exige Financeiro mal-comportado; o GET da reconciliação não é afetado (`ConsultarStatus` ignora `dataQuitacao`). Corrigir antes do smoke T54.

### Integração entre lotes

- Root: Conexão -> repositórios (Venda, Cliente, Produto) -> serviços -> `FilaRepository` -> `FinanceiroClient` -> `QuitacaoService`; destruição em ordem inversa (Quitacao, Financeiro, VendaService, repositórios por interface, Conexão) — consistente.
- `.dpr`/`.dproj`: `FilaRepository`, `QuitacaoService`, `ConfirmacaoVenda` registrados uma vez cada; sem marcadores de merge em `src`, `.dpr`, `.dproj`. `Root.QuitacaoService` -> `FormMain.Configurar` -> lista -> edição.
- Unit combinada `QuitacaoService`: Confirmar (T38-T41) e Cancelar (T43) coerentes (mesma injeção Venda/Financeiro/Fila; Cancelar não reconcilia por GET, escopo de T50).
- HTTP sem transação e gravações de status e fila separadas: aderente a ADR-005/006. Não aplicável: `API-CONTRACT.yaml`/cross-platform.

### Requisitos não funcionais

Sem threads, chamada síncrona com cursor/rótulo (DEC-14), SQL parametrizado, mensagem ao usuário sem SQL. Não verificados: tempo real de bloqueio, repaint do rótulo, compilação em 10.3.

### Ressalvas de verificação (não são reprovação)

- **R1 — T41 sem prova ponta a ponta:** o modo `timeout` do mock atrasa também o `GET /status`, então a reconciliação sempre estoura e cai na fila. Sugestão: modo `timeout-post` no mock (atrasa só POST). Roteiro: quitar via curl, `_modo?m=timeout-post`, Confirmar => venda Quitada, fila vazia, 1 único POST no log. Alternativa: teste unitário com `IFinanceiroGateway` falso (POST=Indisponível, GET=Quitada).
- **R2:** compilação e roteiros de T37-T42 na IDE contra o mock (ok, recusa, erro500, timeout) seguem pendentes.

### Fechamento estrutural

T37-T42 `Concluída` (pendentes de IDE); dependências da Seção 4 resolvidas; nenhuma tarefa `Bloqueada`. A2-A5 devem entrar em `Refatoração Lote-9`; A1 exige retorno de T42 ao `executor` (`Em andamento` no `TASK.md` e entrada em `BLOCKERS.md`). Este relatório não alterou o `TASK.md`. Padrão recorrente: acento sem BOM no Lote 7 (RF7-05) e neste lote; sugerir ao `coordenador` verificação de BOM no roteiro do Executor.

### Veredito por tarefa (chapéu QA)

- T37: **Aprovada** (verificar na IDE; BOM no mesmo commit de A1).
- T38: **Aprovada com ressalva** (RF8-01 alcançável; A1 nas mensagens; A5).
- T39: **Aprovada.**
- T40: **Aprovada com ressalva** (A2, A4).
- T41: **Aprovada com ressalva** (R1).
- T42: **Reprovada, crítica (A1)**; A3 simples. Revalidar só T42 e os textos de T38-T41 após regravar com BOM.

### Veredito do lote (chapéu QA)

**Reprovado até correção de A1** (uma reprovação crítica de correção trivial: BOM em 3 units). Sem A1 o lote seria Aprovado com ressalvas (A2-A5, R1, R2). O chapéu DevSecOps só audita após a revalidação de A1.

## Lote 10 — Cancelamento de venda (D4)

Base: critério de aceite de T43 e T44 no `TASK.md`, `SDD.md` (ADR-005/006/008), `UX-SPEC.md` §2.6/4.2/4.3, `GUARDRAILS.md`, e código real lido (`ERPV.Negocio.QuitacaoService`, `ERPV.UI.FormCancelamentoVenda`, `ERPV.UI.FormListaVendas`, `ERPV.UI.FormEdicaoVenda`, `ERPV.UI.FormBaseEdicao`, `ERPV.Dados.VendaRepository.AtualizarStatus`, `ERPV.Dados.FilaRepository.Enfileirar`, `db/01_schema.sql`), sem usar a nota do Executor como base. Limitação declarada: sem Delphi/CLI de compilação e sem execução contra o mock; **toda a verificação é por inspeção estática**. T43 e T44 estão "Concluída — pendente de confirmação de compilação/execução na IDE" (ressalva de evidência: nenhum resultado abaixo foi executado). Ambas as units estão ligadas no `.dpr` e no `.dproj`.

| Tarefa | Critério (resumo) | Verificação (leitura) | Veredito |
|---|---|---|---|
| T43 | Só Pendente; POST cancelamento; Cancelada => grava status+motivo; 4xx => mantém e informa; 5xx/timeout => fila CANCELAMENTO; Quitada não envia POST | `QuitacaoService.pas:274-286`: status lido do banco; nulo/Quitada/Cancelada => `dcNaoPermitida` antes de qualquer POST (RN-02). `:288-291`: motivo aparado; POST fora de transação (ADR-006), entidade liberada antes. `:294-299`: 2xx com `svCancelada` => `AtualizarStatus(Id, svCancelada, 0, Motivo)` (commit curto próprio no repositório; NULL se motivo vazio) => `dcCancelada`. `:300-302`: 2xx com outro status => `dcRespostaInvalida`, sem efeito. `:303-304`: `rfRecusado` => `dcRecusada`, sem fila (RN-08). `:305-309`: `rfIndisponivel` => `Enfileirar(tfCancelamento)` (idempotente por venda/tipo: incrementa tentativas) => `dcEnfileirada`. `:310-311`: resposta inválida => Pendente, sem fila. Casa com os 4 cenários do critério. Ressalvas: RF10-01, RF10-02 | **Aprovado com ressalvas** (RF10-01, RF10-02) |
| T44 | Diálogo pela venda Pendente (papel Perigoso); mensagens UX 4.3 literais via `Notificar`; botão indisponível em Quitada/Cancelada | `FormCancelamentoVenda.pas:116-121`: "Confirmar cancelamento" (`upbPerigoso`) e "Voltar"; `:138` MaxLength 255 (coluna VARCHAR(255)); `:129` "Motivo (opcional)" com `FocusControl` (`:140`); título "Cancelar venda nº N" (`:104`) e wireframe UX 2.6 respeitados. `:145-177`: `Validar` desabilita controles + cursor de espera durante a chamada (UX 4.1), reabilita em falha. Enter confirma e Esc = Voltar sem pedir descarte (`Modificado` nunca marcado; `FormBaseEdicao.pas:186,197-203`). Textos: recusa `:209-210` e indisponível `:213-215` conferem com UX 4.3 (análogo de "cancelamento"); resposta inválida `:218` e erro inesperado `:165` literais; Info "Venda N cancelada." via `Notificar(utnInfo,..., AHost)` (`:229`), banner no chamador; Aviso/Erro = modal (`Notificar`), sem `MessageDlg` direto. Habilitação: menu de contexto `FormListaVendas.pas:472` (`Pend and QuitacaoService<>nil`) e guarda em `:596-598`; botão dentro da venda `FormEdicaoVenda.pas:569-570` (Status=Pendente, Id>0, serviço injetado) e guarda `:887-888`; Quitada/Cancelada desabilitado com hint. Sucesso na edição fecha com `mrOk`, lista recarrega e exibe o banner (`FormEdicaoVenda.pas:890-893`, `FormListaVendas.pas:615-626`); `Recarregar` também quando não cancelou (`:601`). Regra permanece no service (tela só exibe). Ressalvas: RF10-03, RF10-04 | **Aprovado com ressalvas** (RF10-03, RF10-04) |

### Testes de integração (dentro do lote e com dependências)

- T43 <-> T35 (`IFinanceiroGateway.ConfirmarCancelamento`): assinatura idêntica; T35 devolve `Sucesso` só com `svCancelada`, 4xx => `Recusado` com mensagem (fallback com código HTTP já no cliente, então `dcRecusada` não fica sem detalhe na prática), 5xx/rede => `Indisponivel`; o service mapeia as categorias e o `else` cobre `RespostaInvalida`. Coerente.
- T43 <-> T37 (`IFilaRepository.Enfileirar`): tipo `tfCancelamento`, no máximo 1 PENDENTE por (venda, tipo), erro truncado; coerente com o roteiro "repetir = tentativas 2". Fila e venda não compartilham transação com o HTTP (ADR-006 respeitado).
- T43 <-> T25 (`IVendaRepository.Obter/AtualizarStatus`): `AtualizarStatus` grava STATUS, DATA_QUITACAO (NULL com 0) e MOTIVO_CANCELAMENTO em transação própria/participante. Coerente.
- T44 <-> T43: `CancelarVendaComDialogo` trata os 5 `TDesfechoCancelamento` (`case` completo); `Notificar` tipado por desfecho.
- T44 <-> T42/T32/T31: reaproveita a propriedade `QuitacaoService` de T42 e o botão perigoso da base (`ExibirExcluir`/`AoExcluir`) em T32; sem mudança de construtores; menu de contexto de T31 ligado (antes desabilitado "até T43/T44"). Composition root injeta `Root.QuitacaoService` (`ERPVendas.dpr:57`).
- Bloqueio de Cancelar por item QUITACAO/CANCELAMENTO pendente na fila (UX 4.2) **não** está no critério de T43/T44; pertence a T53 (já previsto no `TASK.md`). Não é reprovação.
- Não aplicável: cross-platform e `API-CONTRACT.yaml` (Delphi VCL desktop; referência `docs/contrato-api-financeiro.md`).

### Requisitos não funcionais

- ADR-006: HTTP fora de transação; commits curtos. ADR-005: falha de rede/5xx => fila; recusa não enfileira. ADR-008/UX: UI sem regra de negócio, textos de UX 4.3 literais, Info = banner e Aviso/Erro = modal, cursor de espera + botões desabilitados (UX 4.1), TabOrder Motivo > Confirmar > Voltar, rótulo com `FocusControl` (UX §5).
- Segurança/LGPD: nenhum log de motivo/corpo na UI; ver RF10-03 (orientação de não digitar dado pessoal no motivo, SG8-03, ausente).
- Delphi 10.3: sem `inline var` (o `inline` em `Cancelou` é de método, permitido); `FormCancelamentoVenda` com BOM; sem FireDAC na UI.
- Não verificados: layout real do diálogo (560 px escalado, alinhamento dos botões), DPI 125%, cor do botão Perigoso, comportamento com timeout de 10 s (UI síncrona, cursor de espera, sem repintura).

### Achados (bug-documentation) — 1 Crítico (A10-01) e 5 Simples

- **A10-01 (CRÍTICA, T43):** `src/Negocio/ERPV.Negocio.QuitacaoService.pas` contém caracteres acentuados ("não", "já", "está" nas mensagens de `dcNaoPermitida`/`dcRespostaInvalida`) e está gravada em UTF-8 **sem BOM**; o Delphi 10.3+ lê arquivo sem BOM como ANSI, então os textos saem com mojibake — o mesmo defeito classificado como crítico no Lote 9 (Bloqueio 005, que já lista esta unit). Não foi detectado na primeira passada deste QA (a verificação de BOM só cobriu `FormCancelamentoVenda`); detectado ao integrar o QA do Lote 9. Correção: regravar em UTF-8 com BOM, sem alterar o conteúdo (tratada junto com o Bloqueio 005). As units de T44 (`FormCancelamentoVenda`, `FormListaVendas`, `FormEdicaoVenda`) têm BOM.
- **RF10-01 (Simples):** `TQuitacaoService.Cancelar` deixa `EInfra` escapar em `Enfileirar` (`QuitacaoService.pas:307`) e em `AtualizarStatus` (`:297`), contra o contrato "sem exceção para falha esperada" (`:16` e `:125`); `Confirmar` já protege o enfileiramento (`:165-171`). Passos: banco/fila falhando durante o cancelamento. Esperado: resultado tipado. Obtido (por leitura): exceção sobe até `FormCancelamentoVenda.Validar` (`:157-166`), que a mostra como Erro modal com texto técnico e reabilita o diálogo; o usuário pode repetir o POST e, se o Financeiro já cancelou, o segundo POST tende a ser recusado. Cenário raro (falha de banco local). Correção: capturar `EInfra` como em `EnfileirarIndisponivel` e definir desfecho/mensagem "cancelado no Financeiro, falha ao gravar local" (reconciliação por T50/GET).
- **RF10-02 (Simples, dependência futura em T50):** ao enfileirar (`QuitacaoService.pas:307`) o motivo digitado não é persistido em lugar nenhum: a venda segue Pendente (MOTIVO_CANCELAMENTO só é gravado no sucesso) e `FILA_INTEGRACAO` (`db/01_schema.sql:93-103`) não tem coluna de payload/motivo. O `Reenviar` de T50 não terá o motivo para repostar (perda silenciosa de dado do usuário). Não viola o critério de T43. Decidir em T50: reenviar sem motivo (explícito) ou guardar o motivo (venda Pendente/coluna na fila).
- **RF10-03 (Simples):** SG8-03 (observação do Lote 8 no `TASK.md`) pede que a UI de cancelamento oriente a não digitar dado pessoal no `motivo`; o diálogo não orienta (`FormCancelamentoVenda.pas:129`: só "Motivo (opcional)", sem hint). Esperado: texto curto (ex.: hint "Não informe dados pessoais"). Obtido: ausente.
- **RF10-04 (Simples, documentação):** `dcNaoPermitida` (`FormCancelamentoVenda.pas:219-223`) mostra a `Mensagem` do service como Aviso, sem texto em UX 4.3, e os textos de recusa/indisponível são por analogia (UX 4.3 diz "análogos"). Aceito; sugerir incorporar esses textos à UX 4.3.
- **RF10-05 (Simples, comentário):** cabeçalho de `QuitacaoService.pas:24-28` ainda diz que T39/T40/T49 "acrescentam comportamento", já superado (o código implementa T39-T41).

Observações (não são reprovação): (a) diferente de `Confirmar`, `Cancelar` não reconcilia por `ConsultarStatus` antes de enfileirar; fora do critério de T43, e T50 já prevê GET antes de repostar (RF-23). (b) Wireframe UX 2.6 põe "Confirmar cancelamento" à direita (implementado), em conflito com a regra geral de UX §3 (perigoso à esquerda); o Executor seguiu o wireframe. (c) Janela síncrona não repinta durante o HTTP (UX 4.1 pede só cursor de espera).

Padrão recorrente: nenhum (RF10-01 lembra RF8-01 — exceção de infra escapando de falha esperada — em outra camada; monitorar, sem escalar). Sem escalação ao `coordenador`.

### O que só a execução na IDE/mock confirma (ressalva, não reprovação por si só)

1. Compilação (Shift+F9) de `QuitacaoService` (record com método `inline`, `class function ... static`, `Exit(valor)`) e de `FormCancelamentoVenda` (herança de `TFormBaseEdicao`, `EstilizarBotao`, `EscalarPx`) com 0 erros.
2. Roteiros manuais dos cabeçalhos contra o mock (porta 8101): modos `ok`, `recusa`, `erro500`, `timeout`, parado; mock sem POST em venda Quitada/Cancelada e ao usar Voltar/Esc; 1 linha CANCELAMENTO na fila, repetir => tentativas 2.
3. Aparência: botão perigoso, alinhamento do rodapé com larguras alteradas, Tab/Enter/Esc, DPI 100%/125%, banner Info visível em `PnlConteudo`.

### Fechamento estrutural

T43 e T44 `Concluída` (pendentes de confirmação na IDE). Dependências da Seção 4 (T43->T35,T37,T25,T29; T44->T32,T43,T68) resolvidas e não órfãs; T43 desbloqueia T50 e T54; T44 desbloqueia T53/T60. Nenhuma tarefa `Bloqueada`. Nenhuma escalação ao `coordenador`. Pendente, fora do escopo desta execução: registrar RF10-01..RF10-05 em `Refatoração Lote-10` (Seção 3 do `TASK.md`; RF10-02 com alvo em T50) e marcar o lote `Validado` após o chapéu DevSecOps.

### Veredito do lote (chapéu QA)

**REPROVADO (crítica, A10-01 — T43; T44 volta a Em andamento por dependência).** Revisão do veredito anterior ("Aprovado com ressalvas"): a primeira passada não conferiu o BOM de `QuitacaoService.pas`. Tirando A10-01, T43 e T44 estão aprovadas com ressalvas (5 ajustes simples: RF10-01..RF10-05); ressalva geral de compilação/execução pendente na IDE/mock (evidência apenas estática). Segue para auditoria de segurança (chapéu DevSecOps), que deve olhar em especial o motivo livre (LGPD, SG8-03, RF10-03), a mensagem técnica exibida em RF10-01 e a ausência de log do motivo.

### Revalidação (2026-09-23)

Escopo: delta do Lote 10 (T43, T44) após a correção do BOM (T-42 / Bloqueio 005). Evidência apenas estática; nada compilado/executado.

- **A10-01 corrigido.** `src/Negocio/ERPV.Negocio.QuitacaoService.pas` começa com EF BB BF. `git diff 03cfdcd HEAD -- src` mostra exatamente 3 arquivos, 1 linha cada, só a inserção do BOM na linha 1 (QuitacaoService, FilaRepository, ConfirmacaoVenda); nenhum outro conteúdo alterado.
- **Varredura por bytes** em `src/**` (`.pas/.dfm/.dpr/.dpk`): nenhum arquivo com byte não-ASCII sem BOM. `FormCancelamentoVenda`, `FormListaVendas`, `FormEdicaoVenda` e `QuitacaoService` confirmados com BOM e acentos. Nenhuma outra ocorrência do achado crítico.
- **T43/T44 vs. critério de aceite:** código inalterado desde a validação anterior (exceto BOM), portanto a conclusão anterior vale. RF10-01..RF10-05 continuam válidos, todos simples, sem mudança de severidade.
- **Fechamento estrutural:** T43 e T44 `Concluída` no `TASK.md`; Seção 4 sem alteração (T43->T35,T37,T25,T29; T44->T32,T43,T68); nenhuma tarefa `Bloqueada`; RF10-01..05 seguem agendados em `Refatoração Lote-10`. Sem escalação ao coordenador.

**Veredito final do lote 10 (chapéu QA): APROVADO COM RESSALVAS** (5 ajustes simples RF10-01..RF10-05 em `Refatoração Lote-10`; ressalva geral: compilação/execução pendente na IDE/mock). Nenhum achado novo. Lote liberado para `Validado` junto com o chapéu DevSecOps.

## Lote 9 — revalidação (pós-correção A1) — chapéu QA (2026-09-23)

Complementa a seção "Lote 9 — Fluxo Confirmar venda (T37-T42)" acima (texto anterior mantido). Método: inspeção estática + verificação de bytes; nada compilado/executado (Delphi 10.3 sem CLI). Correção avaliada: Bloqueio 005 Resolvido (commits ec58871 e b39a790).

### Confirmação da correção de A1

- Bytes iniciais `EF BB BF` confirmados em `src/UI/ERPV.UI.ConfirmacaoVenda.pas`, `src/Negocio/ERPV.Negocio.QuitacaoService.pas` e `src/Dados/ERPV.Dados.FilaRepository.pas`.
- Sem mojibake (busca por `Ã`, `Â`, `â€`, U+FFFD em `src/`: única ocorrência é "NÃO" legítimo em comentário de `ERPV.Core.Log.pas`).
- Literais de UX 4.3 íntegros em `ConfirmacaoVenda.pas` ("Financeiro indisponível ... foi colocada na fila. Tente novamente em Pendências.", "Quitação recusada pelo Financeiro: ...", "Esta ação envia a quitação ao Financeiro.") e fallbacks de `QuitacaoService` ("Quitação recusada pelo Financeiro (código HTTP ...)", "Financeiro indisponível (código HTTP ...)").
- Varredura geral: as 36 units com caractere não ASCII em `src/` têm BOM; os arquivos sem BOM (`App.Root`, `Core.Config`, `Core.Validadores`, `Integracao.FinanceiroClient`, `Negocio.ClienteService`, `UI.FormBaseLista`, `UI.FormMain.dfm`) são só ASCII. Nenhuma outra unit acentuada sem BOM. A1 **corrigida**.

### Integração com o Lote 10 (regressão)

`QuitacaoService.pas` agora contém `Cancelar` (T43), mas `Confirmar` está intacto: lê status do banco e exige Pendente antes do POST, sem transação no HTTP; 200/Quitada => `AtualizarStatus` curto; recusa sem gravar/enfileirar; indisponível => GET de reconciliação, Quitada => conclui local sem fila, senão `EnfileirarIndisponivel` (`tfQuitacao`, EInfra não mascara). `Cancelar` usa método/campos próprios e `tfCancelamento`, sem compartilhar estado com `Confirmar`. `TDesfechoQuitacao`/`TResultadoQuitacao` inalterados; `FilaRepository` e `ConfirmacaoVenda` sem regressão de lógica. Nenhuma regressão em T38-T41.

### Achados após a revalidação

- **A1: RESOLVIDO.**
- **A2, A3, A4, A5 (Simples): permanecem válidos**, IDs estáveis, a rotear para `Refatoração Lote-9`. Cosmético (".." na recusa) também permanece.
- **RF8-01 (risco médio-baixo, alcançável) e R1 (mock `timeout` atrasa também GET /status; T41 sem prova ponta a ponta): permanecem.** R2 (compilação/roteiros na IDE) segue pendente.
- **Novos achados: nenhum.** Observação apenas documental (Simples, agregável a A5): o comentário de cabeçalho ainda cita `FILA_SINCRONIZACAO` (T40/T41), tabela real `FILA_INTEGRACAO`.
- **Reprovações críticas em aberto: nenhuma.**

### Nota sobre T38

A validação do Lote 10 reabriu T38 (`Em andamento`) por causa do mesmo BOM de `QuitacaoService.pas` (A10-01). Com A1/A10-01 corrigidos nesta unit, T38 é **restaurada a `Concluída`** nesta revalidação. (T43/T44 dependem de sua própria revalidação no Lote 10.)

### Veredito por tarefa (revalidação)

- T37: **Aprovada.**
- T38: **Aprovada com ressalva** (RF8-01, A5); restaurada a Concluída.
- T39: **Aprovada.**
- T40: **Aprovada com ressalva** (A2, A4).
- T41: **Aprovada com ressalva** (R1).
- T42: **Aprovada com ressalva** (A3 simples, A2); crítica A1 resolvida; volta a `Concluída`.

### Veredito do lote (chapéu QA)

**Aprovado com ressalvas.** Ressalvas: A2-A5, RF8-01 (corrigir antes do smoke T54), R1, R2 (IDE). A2-A5 (e o ajuste de cabeçalho) entram em `Refatoração Lote-9`. Este relatório não alterou código nem `TASK.md`. Liberado para o chapéu DevSecOps auditar o Lote 9. O Bloqueio 005 pode permanecer Resolvido.

## Lote 11 — Relatório e PDF (T45, T46, T47) — chapéu QA (2026-09-24)

Método: inspeção estática de `ERPV.Dados.VendaRepository.pas` (`SQL_RELATORIO`, `RelatorioDataSet`), `ERPV.Relatorios.PedidoLayout.pas/.dfm`, `ERPV.Relatorios.RelatorioPedido.pas`, `ERPV.Dominio.Contratos.IRelatorioPedido.pas`, `ERPV.App.Root.pas`, `.dpr`/`.dproj`. Nada compilado/executado por este agente (sem IDE Delphi). Nenhuma nota de implementação do Executor foi usada como base de aprovação.

**Evidência do usuário (IDE, 2026-09-23/24, informada por ele, não reproduzida aqui):** build compila; `GerarPdf` gerou `C:\ERPVendas\temp\pdf\Pedido_7_<timestamp>.pdf`, arquivo existe, abriu no leitor com dados corretos; `Limpar` apagou o arquivo; casos de erro (pasta inválida, `Limpar` fora da pasta) aprovados; preview do layout no Designer conferido (e-mail/rodapé/rótulos/alinhamento ajustados a pedido).

### Verificações por ponto

1. **Colunas x layout (T45/T46):** `SQL_RELATORIO` devolve 11 colunas (VENDA_ID, DATA_VENDA, STATUS, VALOR_TOTAL, CLIENTE_NOME, CLIENTE_CPF_CNPJ, CLIENTE_EMAIL, PRODUTO_DESCRICAO, QUANTIDADE, PRECO_UNITARIO, SUBTOTAL), idênticas em nome às do `mtPedido` (FieldDefs e TFields) e aos 11 `DataField` dos `TppDBText` (DBText1-11, cada um em uma coluna distinta). Bandas: cabeçalho (venda + cliente + títulos), detalhe (itens), resumo (total), rodapé (data/hora e nº de páginas). No runtime o dataset é o do FireDAC (NUMERIC(15,2) chega como BCD/FMTBCD, o mtPedido de desenho usa ftCurrency); confirmado só pela evidência do usuário (PDF com dados corretos). Larguras dos campos do cabeçalho (17 mm) x conteúdo longo: não verificável estaticamente; usuário afirma ter ajustado no preview.
2. **VALOR_TOTAL x SUBTOTAL:** SUBTOTAL = `QUANTIDADE * PRECO_UNITARIO` no banco; VALOR_TOTAL é a coluna gravada em VENDAS (o resumo imprime esse valor, não a soma dos itens). Coerência depende de T26/`VendaService` gravar total = soma dos itens (fora do Lote 11).
3. **T47:** erro amigável — `MSG_FALHA_PDF` fixa, sem caminho/SQL; detalhe só em `FLogger.Erro` (OK). `Limpar` — `DentroDaPastaTemp` usa `ExpandFileName` (resolve `..` e relativo) e compara com prefixo terminado em `\`, logo `C:\x\temp2` não passa por `C:\x\temp`; case-insensitive (adequado a Windows); só apaga arquivo existente; aviso em log, sem exceção. Liberação: Layout liberado antes do DataSet (correto: o DataSource aponta para o dataset), ambos em `finally`; falha em `RelatorioDataSet` libera a query. Nome `Pedido_<Id>_yyyymmddhhnnsszzz.pdf` (previsível; colisão só no mesmo milissegundo). Venda inexistente: `JOIN CLIENTES` => vazio => `EInfra`, nenhum arquivo. Venda sem itens: `LEFT JOIN` gera 1 linha com item vazio (aceitável).
4. **nil:** `AVenda = nil` em `GerarPdf` (linha 81, fora do `try`) gera AV bruta, não `EInfra`; `FVendaRepository`/`FLogger` nil idem. `RelatorioDataSet` com ID inexistente devolve dataset vazio (não nil). Chamadores previstos (T49/T51) não passam nil: risco baixo.
5. **Dados de teste no .dfm:** `mtPedido.Active = True`, porém o .dfm não contém linhas (sem `Data`) — nenhum dado real/PII. Faixa "Demo Copy" é do trial (T67, `docs/ambiente-licencas.md` §3.2), esperada e documentada.
6. **Domínio:** `IRelatorioPedido` usa só `ERPV.Dominio.Venda`; sem ReportBuilder/Vcl/FireDAC (ADR-001/010). `ppTypes` só em `Relatorios.RelatorioPedido`. Montagem no Root (`TRelatorioPedido.Create(PastaPdfTemp, VendaRepository, Logger)`; `nil` no `Destroy` antes dos repositórios) e registro no `.dpr` (linhas 36-37) e `.dproj` (107/112) presentes.
7. **Cabeçalho-roteiro:** presente nas units. `RelatorioPedido.pas` tem BOM UTF-8 (acento em `MSG_FALHA_PDF` ok); `PedidoLayout.pas` é ASCII puro.

### Achados

| ID | Sev. | Local | Descrição |
|---|---|---|---|
| A11-01 | Simples | `ERPV.Relatorios.RelatorioPedido.pas:81` | `AVenda`/dependências nil não tratados: AV bruta em vez de `EInfra` (mover cálculo do caminho para dentro do `try` e/ou checar nil). |
| A11-02 | Simples | `ERPV.Relatorios.RelatorioPedido.pas:76-113` | Se `Print` falhar após criar arquivo parcial, ele permanece na pasta temp (sem limpeza no `except`). |
| A11-03 | Simples | `ERPV.Relatorios.RelatorioPedido.pas:82` | Nome com timestamp em ms, sem sufixo único; colisão teórica. |
| A11-04 | Simples | `ERPV.Dados.VendaRepository.pas:473` | `RelatorioDataSet` reporta falha como `TratarFalha('obter', ...)` (rótulo de "obter venda"); só afeta log/mensagem. |
| A11-05 | Simples | `PedidoLayout.dfm` (DBText1-6, `mmWidth = 17198`) | Campos de cabeçalho com largura fixa 17 mm, sem `WordWrap`/`DisplayFormat` explícitos; e-mail/nome longos e formato de moeda/data dependem do RB/locale. Usuário conferiu no preview, sem teste com 100 chars. |
| A11-06 | Simples (doc.) | `ERPV.Relatorios.RelatorioPedido.pas:71-73` | `Limpar` não resolve symlink/junction (só prefixo textual); aceitável em pasta temp local; registrar como limitação. |
| R11-1 | Informativo | — | `VALOR_TOTAL` impresso é o gravado, não a soma dos itens (depende de T26). |

Reprovações críticas: nenhuma. Achados Simples entram em `Refatoração Lote-11` (prazo: antes do smoke T54; A11-01/02 preferencialmente junto com T49).

### Não verificável por falta de IDE

Compilação (usuário confirmou); tipos FMTBCD reais no pipeline; estouro visual com dados longos; formatação de moeda/data no PDF; `Print` em pasta sem permissão além do caso testado; quebra de página com muitos itens.

### Veredito por tarefa

- T45: **Aprovada** (ressalvas menores: A11-04, R11-1).
- T46: **Aprovada com ressalvas** (A11-05).
- T47: **Aprovada com ressalvas** (A11-01, A11-02, A11-03, A11-06).

### Veredito do lote (chapéu QA)

**Aprovado com ressalvas.** Nenhuma reprovação crítica; `TASK.md` não alterado (T45-T47 seguem `Concluída`). Liberado ao chapéu DevSecOps. Pontos para a auditoria: path traversal em `Limpar`, vazamento de caminho em log/mensagem, dados de cliente no PDF em pasta temp.

## Lote 12 — E-mail pós-quitação (T48, T49) — chapéu QA (2026-09-24)

Método: inspeção estática de `ERPV.Integracao.EmailSender.pas`, `ERPV.Negocio.QuitacaoService.pas` (`PosQuitacao`, `Confirmar`), `ERPV.UI.ConfirmacaoVenda.pas`, `ERPV.App.Root.pas`, `ERPV.Relatorios.RelatorioPedido.pas`, `ERPV.Dados.FilaRepository.pas` (`Enfileirar`), `.dpr`/`.dproj`, UX-SPEC §4.3. Nada compilado/executado por este agente (sem IDE Delphi). Notas de implementação do Executor não foram usadas como base de aprovação.

### Critérios (acceptance-criteria-validation)

**T48** (Mailtrap com anexo chega; senha errada => Falha sem crash e sem senha no log)
- Resultado tipado, sem exceção para falha esperada: `Enviar` valida destinatário vazio e anexo inexistente antes de conectar; todo o resto em `try/except` com ordem correta (`EIdSMTPReplyError` > `EIdOSSLException` > `EIdException` > `Exception`); 535/534/530 => `MSG_CREDENCIAL`. Mensagens fixas e seguras. OK.
- Log: só etapa + `ClassName` (e código de resposta SMTP); sem senha, corpo, destinatário nem `E.Message`. OK.
- TLS/sem TLS conforme spike T02 (explícito TLS 1.2 / `IOHandler=nil`+`utNoTLSSupport`); timeouts 15 s/30 s; anexo `application/pdf`; multipart/mixed com parte de texto utf-8. Liberação de `LSmtp/LSsl/LMsg` no `finally` (partes pertencem a `MessageParts`). Desconexão protegida. OK.
- Config via record por construtor (INI/env resolvidos em `Core.Config`); Root instancia `TEmailSender.Create(Cfg.SMTP, Logger)`; unit no `.dpr` (l.36) e `.dproj` (l.107). OK.
- Depende de execução real (Mailtrap, DLLs OpenSSL): ver "Não verificável".

**T49** (após commit local gera PDF, envia, apaga PDF; falha => Quitada + fila EMAIL; nunca antes da quitação)
- Ordem: `PosQuitacao` só é chamado dentro de `GravarQuitada(...) = True`, tanto no caminho `rfSucesso` quanto na reconciliação T41; nunca em recusa/indisponível/resposta inválida (`EmailStatus=eqNaoAplicavel`). OK. Sem transação aberta durante PDF/SMTP (ADR-006). OK.
- Nada levanta exceção: `try/except` cobre `Obter`, `Cliente.Obter`, `GerarPdf`, `Enviar`; `Limpar` best-effort; `Enfileirar` em try/except. Quitação nunca é desfeita. OK.
- PDF apagado em sucesso e em falha (`Limpar` sempre que `Pdf<>''`); PDF parcial na falha de `GerarPdf` é removido pelo próprio `RelatorioPedido` (RF11-02, corrige A11-02) e `Pdf` fica vazio nesse caso, sem dupla limpeza. OK.
- Falha => `Enfileirar(tfEmail)`: `FilaRepository` deduplica por (venda,tipo) PENDENTE e incrementa tentativas (RN-08). Erro gravado não inclui e-mail/CPF. OK.
- Cliente sem e-mail/inexistente => `eqFalhou` + fila (coerente com UX §1). OK.
- UI: `TextoDesfechoQuitacao` reproduz literalmente UX 4.3 (enviado: Info/banner; falha: Aviso modal). `qdIndisponivel` Aviso, `qdRecusado` Erro. OK. Os dois chamadores (`FormEdicaoVenda`, `FormListaVendas`) usam `ConfirmarVendaComFeedback`, sem quebra de assinatura.
- Composition root: ordem `Relatorio -> EmailSender -> QuitacaoService(…, ClienteRepo, Relatorio, EmailSender)`; destrutor libera `FEmailSender`/`FRelatorioPedido` (interfaces) antes de `FQuitacaoService.Free` e dos repositórios; ver A12-04.

### Integração (cross-platform-integration-testing)

T48 (`IEmailSender`/`TResultadoEnvioEmail.Sucesso/MensagemErro`) <-> T49 (`Env.Sucesso`, `Env.MensagemErro`); T47 (`GerarPdf` devolve caminho dentro da pasta temp, `Limpar` restrito a ela; caminho passado direto como anexo); T37 (`Enfileirar` `tfEmail`, mesmo enum/`TIPO_FILA_STR`); T38/T41 (dois pontos de `PosQuitacao`); UI (`EmailStatus/EmailDestino` mapeados nas mensagens 4.3). Contratos consistentes por leitura estática. Roteiro de reenvio (T51) fora do lote.

### Requisitos não funcionais

- Segurança/LGPD: sem senha/e-mail/corpo em log ou fila; mensagens genéricas ao usuário. Para o DevSecOps: `TIdSSLIOHandlerSocketOpenSSL` sem verificação de certificado (`VerifyMode` padrão), PDF com dados do cliente na pasta temp durante o envio (apagado em seguida; retenção 24 h em falha de limpeza), `From` fixo.
- Desempenho/usabilidade: chamada síncrona na thread da UI; pior caso conecta 15 s + leitura 30 s por operação SMTP, somando-se ao timeout do Financeiro (ver A12-03).

### Achados (bug-documentation) — nenhum Crítico, 4 Simples

| ID | Sev. | Local | Descrição |
|---|---|---|---|
| A12-01 | Simples | `QuitacaoService.pas:298-302` | Falha ao enfileirar EMAIL é engolida sem log e sem sinal ao chamador; a UI diz "Ele ficou na fila" mesmo sem item na fila. `TQuitacaoService` não tem logger. Sugestão: registrar (log/Logger opcional) e/ou novo estado no resultado (ex.: `EmailNaFila: Boolean`) com texto sem promessa de fila. Registrar também no log a falha de e-mail (só a `Erro` fixa) para diagnóstico. |
| A12-02 | Simples | `EmailSender.pas:84,147` | `From` fixo `nao-responder@erpvendas.local` (domínio inexistente): servidores reais podem recusar/marcar spam; a Root não passa `ARemetente` e o INI não tem campo. Sugestão: campo `[SMTP] Remetente` opcional. Deve ser tratado antes do smoke T54 com SMTP real. |
| A12-03 | Simples | `ConfirmacaoVenda.pas:143-149` + `PosQuitacao` | Rótulo "Aguardando Financeiro..." permanece durante PDF + SMTP (até ~45 s+) e a UI fica bloqueada; o texto engana na fase de e-mail. Sugestão: trocar o rótulo antes do e-mail (callback/estado) ou reduzir timeouts; documentar. |
| A12-04 | Simples | `QuitacaoService.pas:305-309`, `ERPV.App.Root.pas:224-228` | `TQuitacaoService` recebe `FRelatorio`/`FEmailSender` nil sem checagem (AV bruta capturada pelo `except` de `PosQuitacao` como `EAccessViolation`, resultando em e-mail "falhou" + fila, sem diagnóstico). Sugestão: `Assert`/`EInfra` no construtor e teste de composição. |
| R12-1 | Informativo | `EmailSender.pas:172-178` | `utUseExplicitTLS` cobre 587/2525; porta 465 (TLS implícito) não suportada (fora do escopo T48/ADR-007; documentar). |
| R12-2 | Informativo | `EmailSender.pas:148` | Destinatário vem do cadastro; CR/LF no e-mail dependeria de validação do cadastro (T18/UI) — Indy tende a sanear cabeçalhos; conferir no DevSecOps. |

Reprovações críticas: nenhuma. Resolvido neste lote: A11-02 (PDF parcial) confirmado no RelatorioPedido; A11-01 (nil) permanece aberto, mas T49 nunca passa nil (Venda checada antes).

### Não verificável por falta de IDE (ressalva, não reprovação)

Compilação (units novas, uses `IdSMTPBase`/`IdExplicitTLSClientServerBase`/`IdSSLOpenSSL`, nome exato de `E.ErrorCode`); envio real ao Mailtrap com anexo abrível (roteiro 1-3 do cabeçalho de T48); senha errada => 535 => Falha e log sem senha; host inválido/timeout; DLLs OpenSSL ausentes; `ERPV_SMTP_PASSWORD` com prioridade; roteiros 1-4 de T49 (e-mail com PDF, `STATUS=QUITADA` + 1 linha EMAIL PENDENTE, tentativas+1 na repetição, PDF removido da pasta temp); exibição do modal/banner.

### Fechamento estrutural

T48 e T49 `Concluída`; dependências da Seção 4 do TASK.md (T48<-T02,T09; T49<-T38,T47,T48,T37,T68) satisfeitas e sem órfãs; sem tarefa `Bloqueada`. Nenhuma inconsistência que exija redesenho. `TASK.md` não alterado por este agente; A12-01 a A12-04 aguardam criação em `Refatoração Lote-12` pelo orquestrador.

### Veredito por tarefa

- T48: **Aprovada com ressalvas** (A12-02; execução Mailtrap pendente).
- T49: **Aprovada com ressalvas** (A12-01, A12-03, A12-04; execução na IDE pendente).

### Veredito do lote (chapéu QA)

**Aprovado com ressalvas.** Nenhuma reprovação crítica; código não compilado/executado por este agente. Liberado ao chapéu DevSecOps. Pontos para auditoria: verificação de certificado TLS, PDF com PII em pasta temp, logs/fila sem PII, sanitização do destinatário.

## Lote 13 — Reenvio e Pendências (T50-T53) — chapéu QA (2026-09-24)

Método: inspeção estática (leitura + `git diff 1975777..HEAD`) de `ERPV.Negocio.FilaService.pas`, `ERPV.Negocio.PendenciaFila.pas`, `ERPV.Negocio.VendaService.pas`, `ERPV.Negocio.QuitacaoService.pas`, `ERPV.Dados.FilaRepository.pas`, `ERPV.Dados.VendaRepository.pas` (`AtualizarStatus`), `ERPV.UI.FormPendencias.pas`, `ERPV.UI.PendenciasApresentacao.pas`, `ERPV.UI.FormMain.pas`, `ERPV.UI.FormListaVendas.pas`, `ERPV.UI.FormEdicaoVenda.pas`, `ERPV.UI.ConfirmacaoVenda.pas`, `ERPV.App.Root.pas`, `ERPVendas.dpr`/`.dproj`, testes em `tests/`. Nada compilado/executado por este agente (sem IDE Delphi; não existe projeto DUnitX no repositório). Notas de implementação do Executor não foram usadas como base de aprovação.

### Critérios (acceptance-criteria-validation)

**T50** (mock erro500 depois ok: item CONCLUIDO e venda muda de status; falha mantém PENDENTE com tentativas+1)
- GET status antes do POST: venda local já no alvo => `MarcarConcluido` sem POST; GET no alvo => `ConcluirLocal` (commit curto `AtualizarStatus` + `MarcarConcluido`); GET ou local no estado oposto => `Falha` sem POST; demais => POST fora de transação (ADR-006). OK.
- Sucesso => CONCLUIDO + status da venda muda; falha (4xx/5xx/timeout/resposta inválida/status inesperado) => `RegistrarFalha` (PENDENTE, tentativas+1, `ULTIMO_ERRO` mascarado e truncado a 500 no repositório, RF9-05). OK.
- `EInfra` de `AtualizarStatus`/`MarcarConcluido`/`RegistrarFalha` vira `rrFalha` amigável; item segue PENDENTE e reconcilia pelo GET no próximo reenvio. OK. Exceção: `Obter` (l.245/294) não está protegido (ver A4; a UI captura).
- RF10-02: CANCELAMENTO reenvia com motivo `''`; `AtualizarStatus(..., svCancelada, 0, '')` grava NULL (`DefinirTextoOuNulo`/`DefinirDataOuNulo`). Consistente com `QuitacaoService.Cancelar` (motivo não vai para a fila). OK.

**T51** (SMTP corrigido => e-mail chega e CONCLUIDO; falha mantém PENDENTE com erro)
- Regenera PDF do banco (`Obter` + `GerarPdf`), envia, `Limpar` sempre, status da venda intocado, exige `Quitada` e e-mail do cliente; sem e-mail/dado pessoal em mensagens de erro; exceções viram `rrFalha`. OK. Envio real (Mailtrap) pendente.

**T52** (Reenviar conclui => "Item concluído." Info; falha => "Ainda não foi possível: <erro>"; concluído some do filtro; vazio/erro)
- Grade ligada a `IFilaRepository.Listar`; "Somente pendentes" marcado por padrão; `MensagemDeReenvio` reproduz os textos; sucesso Info, falha Aviso; `Recarregar` antes do modal; vazio "Nenhuma pendência."; erro com banner + "Tentar novamente"; reentrância (`FOcupado`). `TFilaService` criado no Root (destruição antes do `QuitacaoService`/repositórios) e injetado em `Configurar`; units no `.dpr` e `.dproj`. OK.
- Com o filtro desmarcado, item CONCLUIDO continua reenviável (A1).

**T53** (chip N e ícone/texto na status bar; "(!)" na lista; botões bloqueados; após reenvio ok o contador desce e os botões liberam)
- Regra única `VendaBloqueadaPorFila` (QUITACAO ou CANCELAMENTO PENDENTE; EMAIL não bloqueia; fila nil não bloqueia), aplicada em `VendaService.ExigirPendente` (Salvar Id>0 e Excluir), `QuitacaoService.Confirmar`/`Cancelar` (antes do POST) e na UI (`AcoesDaVenda`: Editar/Excluir/Confirmar/Cancelar desabilitados, botão vira "Visualizar"; tela de venda abre somente leitura com banner). Defesa em profundidade UI + Service. OK.
- Contador: `ContarPendencias` em `Configurar`, após Confirmar/Cancelar/Editar na lista e após cada Reenviar; falha de banco mantém o último valor. Status bar "Pendências: N" sempre com texto; chip só com N>0 (99+); clicáveis abrem Pendências. Coluna Sinc "(!)" (texto + cor âmbar) via um único `Listar(True)` por recarga. OK.

### Integração (cross-platform-integration-testing)

- T52 <-> T50/T51: `Reenviar(ID, VENDA_ID, StrToTipoFila(TIPO))` com os três tipos; `rrNaoSuportado` só para tipo desconhecido. Consistente.
- T53 <-> fila/T52: `TFilaService.Reenviar` NÃO usa `VendaBloqueadaPorFila` nem `TQuitacaoService`; grava por `IVendaRepository.AtualizarStatus`/`IFilaRepository` diretamente. Logo o Reenviar não é bloqueado pela própria regra de bloqueio e não há ciclo.
- EMAIL (T49/T51): `PosQuitacao` enfileira `tfEmail`; a regra só consulta QUITACAO/CANCELAMENTO; EMAIL pendente não bloqueia (há teste `Email_NaoBloqueia`).
- Regressão Lotes 9/10: `Confirmar`/`Cancelar` mantêm a ordem (status do banco => bloqueio => HTTP), desfechos e mensagens; único acréscimo é o bloqueio antes do POST. `FormListaVendas.AoConfirmar` agora recarrega/notifica em `finally` (cobre `qdIndisponivel` que enfileira). Reentrância do Lote 9 (SG9-04/A3) preservada. `ConfirmacaoVenda` só ganhou texto para falha de `Enfileirar` via marcador `' | Aviso:'` (ver R13-2).
- Regressão Lote 10 (RF10-01/RF10-02): tratamento de `EInfra` em `Cancelar` intacto; RF10-02 coerente com T50 (motivo NULL no reenvio, documentado nos dois services).
- Regressão Lote 12: `PosQuitacao` inalterado; ver A2 (reenvio de QUITACAO não chama pós-quitação).
- Composition root: `VendaService` recebe `FFilaRepository` (criado antes, reordenado corretamente); `FormMain.Configurar` ganhou dois parâmetros opcionais e o `.dpr` os passa.

### Requisitos não funcionais

- Segurança/LGPD (para o DevSecOps): erro da fila mascarado no repositório e exibido na grade; sem log de dado pessoal nos novos units; mensagens de infra genéricas; reenvio de CANCELAMENTO sem motivo (minimização).
- Desempenho/usabilidade: Reenviar é síncrono na thread da UI (GET + POST, ou PDF + SMTP até ~45 s) só com cursor de ampulheta (A6). `CarregarVendasComFila` faz 1 SELECT por recarga. Texto sempre junto de ícone/cor; TabOrder da barra definido; teclado/DPI em T60.

### Achados (bug-documentation) — nenhum Crítico, 6 Simples

| ID | Sev. | Local | Descrição |
|---|---|---|---|
| A1 | Simples | `FormPendencias.pas` `TemSelecao`/`AoReenviar`; `FilaService.Reenviar`/`ReenviarEmail`; `FilaRepository.RegistrarFalha` | Com "Somente pendentes" desmarcado, Reenviar fica habilitado em linha CONCLUIDO. Passos: concluir item EMAIL, desmarcar filtro, selecionar a linha, Reenviar. Esperado: bloqueado. Obtido: novo e-mail ao cliente e `CONCLUIDO_EM` sobrescrito; em falha, `TENTATIVAS`/`ULTIMO_ERRO` do item concluído mudam (UPDATE sem filtro de status). Sugestão: habilitar só se `STATUS='PENDENTE'`, recusar no service e/ou `AND STATUS='PENDENTE'` no UPDATE. |
| A2 | Simples (prioridade alta) | `FilaService.Reenviar`/`ConcluirLocal` vs. `QuitacaoService.PosQuitacao` | QUITACAO concluída via Pendências (reenvio ou reconciliação por GET) nunca gera PDF/e-mail nem enfileira EMAIL, diferente do caminho síncrono T40/T41 (Lote 12). Cenário: Financeiro cai, venda vai à fila, Reenviar conclui => venda Quitada, cliente sem e-mail e sem item EMAIL. Sugestão: extrair a lógica pós-quitação para helper compartilhado e chamá-la quando `Alvo = svQuitada` e a conclusão local for nova. Tratar antes do smoke T54/Lote 16. |
| A3 | Simples | `FormEdicaoVenda.pas` (`FBloqueadaFila`, `AtualizarCancelar`, `AoConfirmar`, `AoExcluir`) | `FBloqueadaFila`/`FSomenteLeitura` só são calculados ao abrir. Confirmar (`qdIndisponivel`) ou Cancelar (`dcEnfileirada`) de dentro da venda enfileira e a tela segue aberta e editável; novo clique cai no bloqueio do Service e a `ERegraNegocio` sobe ao handler global. Sugestão: reavaliar `TemPendenciaFila` após a ação e voltar a somente leitura/fechar com mrOk. |
| A4 | Simples | `PendenciaFila.pas:29-34`, `FilaRepository.ExistePendenciaPorVenda`, `QuitacaoService.Confirmar/Cancelar`, `VendaService.ExigirPendente`, `FilaService.Reenviar` (l.245, 272) | `EInfra` da consulta de fila propaga: `Cancelar` deixa de cumprir "sem exceção para falha esperada" e `Confirmar` levanta antes do POST (fail-safe: nada é enviado). Em `Reenviar`, falha de `Obter`/`ConsultarStatus` não vira `rrFalha`/`RegistrarFalha` (a UI captura e mostra "Ainda não foi possível"). Sugestão: mapear para `dcNaoPermitida`/`rrFalha` amigável, como RF9-01/RF10-01. |
| A5 | Simples | `tests/` | Sem teste de integração do bloqueio em `TVendaService` (Salvar/Excluir) e `TQuitacaoService` (Confirmar/Cancelar não chamam o Financeiro com pendência; EMAIL pendente libera; Reenviar não é bloqueado). Só a regra pura e o `FilaService` têm testes; projeto DUnitX inexistente (nada rodou). |
| A6 | Simples | `FormPendencias.AoReenviar` (família de A12-03) | Reenviar bloqueia a UI por até GET+POST (ou PDF+SMTP) só com ampulheta; sem rótulo "Reenviando..." nem `DefinirEstado` do shell. |
| R13-1 | Informativo | `FormListaVendas.CarregarVendasComFila` | Falha ao listar a fila esconde o Sinc sem aviso (documentado; bloqueio real está nos Services). |
| R13-2 | Informativo | `ConfirmacaoVenda.MARCADOR_AVISO_FILA` | Falha de fila detectada por substring `' | Aviso:'` na mensagem; acoplamento frágil (preferir campo tipado, ver A12-01). |
| R13-3 | Informativo | `FilaService` | GET status não devolve data: quitação concluída no reenvio usa `Now` (igual ao T41). |

Reprovações críticas: nenhuma. Nenhum achado compromete o critério de aceite central de T50-T53.

### Não verificável por falta de IDE (ressalva, não reprovação)

Compilação de todas as units (uses, `TDictionary`, `cxGrid*`, `Configurar` com parâmetros opcionais, `Exit(Falha(...))` dentro de `try/except`); execução dos testes DUnitX (`FilaService`, `PendenciaFila`, `PendenciasApresentacao`; sem projeto de testes); roteiro real com o mock (erro500 => Confirmar => item QUITACAO PENDENTE, chip/status bar/"(!)" sobem, botões bloqueados, Reenviar com mock ok => contador desce, venda Quitada; cancelamento idem com `MOTIVO_CANCELAMENTO` NULL); reenvio EMAIL com Mailtrap; `OnGetDisplayText` em coluna sem campo (Sinc), foco após `Recarregar`, DPI 125%/teclado (T60).

### Fechamento estrutural

T50-T53 `Concluída`; dependências da Seção 4 do TASK.md satisfeitas, sem órfãs e sem tarefa `Bloqueada`; nenhuma inconsistência que exija redesenho. `TASK.md` não alterado por este agente; A1 a A6 aguardam criação em `Refatoração Lote-13` na consolidação pós-DevSecOps.

### Veredito por tarefa

- T50: **Aprovada com ressalvas** (A1, A2, A4; execução com mock pendente).
- T51: **Aprovada com ressalvas** (A1; SMTP real pendente).
- T52: **Aprovada com ressalvas** (A1, A5, A6; compilação/execução pendente).
- T53: **Aprovada com ressalvas** (A3, A4, A5; compilação/execução pendente).

### Veredito do lote (chapéu QA)

**Aprovado com ressalvas.** Nenhuma reprovação crítica; código não compilado/executado por este agente. Liberado ao chapéu DevSecOps. Pontos para auditoria: `ULTIMO_ERRO` exibido na grade (mascaramento), reenvio de e-mail duplicado (A1), PDF com PII em pasta temp no reenvio, guarda de bloqueio no Service (não só na UI), ausência de log nos novos services.


## Lote 15 — Documentação (T56, T57, T58) — chapéu QA (2026-09-24)

Escopo: `docs/roteiro-testes-manuais.md`, `README.md`, `docs/decisoes.md`. Evidência estática (leitura + cruzamento com `src/`, `config/`, `db/`, `tools/`, `.md/adr/`); nada compilado/executado.

### Critérios (acceptance-criteria-validation)

**T56** (cada cenário com passos, dado de entrada e esperado verificáveis; 12 cenários SDD §7)
- C1-C12 presentes e cobrem a lista do SDD §7. Mensagens amostradas contra `src/` e conferidas: "CPF/CNPJ/E-mail invalido", "Documento ja cadastrado", "Informe o nome/CPF/CNPJ/e-mail", "Informe a descrição/unidade", "Informe o cliente", "ao menos um item", "maior que zero", "Cliente inativo não pode receber venda", `Produto "%s" inativo não pode ser vendido`, banners "Venda Quitada/Cancelada: somente leitura", "Venda já quitada não pode ser alterada nem excluída" / "cancelada...", diálogo de confirmação (R$ + "Esta ação envia a quitação ao Financeiro."), assunto "Confirmação de Pedido N", "Segue em anexo...", "Financeiro indisponível. A venda N continua Pendente e foi colocada na fila. Tente novamente em Pendências.", "Resolva em Pendências antes de continuar.", "Ainda não foi possível reenviar este item. Tente novamente.", "Ele ficou na fila; reenvie em Pendências.", "Falha SMTP", "reconciliada pela fila de pendências", "colocado na fila de pendências", "Venda já quitada não pode ser cancelada" / "Venda já está cancelada", "Arquivo de configuracao nao encontrado", "ausente ou vazia", botão "Confirmar cancelamento", status bar "Financeiro: <BaseUrl>". OK.
- Modos do mock (`ok|recusa|erro500|timeout|timeout-post|offline-simulado`), `--port`/`--modo`, rota `/_modo?m=` e variáveis `ERPV_*` conferem com `mock_financeiro.py` e `ERPV.Core.Config.pas`. Seed (2 clientes, 3 produtos) coerente com README.
- Divergências: banner da venda bloqueada (D2), preço 0 (D3), C11 sem "Dado" e C6 sem passos numerados (D4), motivo de cancelamento (D5).
- Motivo de cancelamento: `FormCancelamentoVenda` coleta "Motivo (opcional, até 255)" e grava em `VENDAS.MOTIVO_CANCELAMENTO`; o roteiro não cita texto de mensagem sobre ele (sem divergência de texto), mas nenhum passo o preenche/confere (D5).

**T57** (README cobre instalação para quem não tem contexto; validado de fato em T64)
- Cobre arquitetura, pré-requisitos (32 bits, OpenSSL 1.0.2), FB3, `gbak`/scripts (`db/00_criar_banco.sql`, `01_schema.sql`, `02_seed.sql` existem), INI (seções/chaves conferem com `config/erpvendas.ini.example`), env vars, mock, LGPD, limitações do trial. Caminhos citados existem. "12 cenários" confere com o roteiro. `bin/` e `ERPVENDAS.FBK` inexistentes estão declarados como gerados em T61/T62, com alternativa por scripts: aceitável, não é defeito.
- BaseUrl: INI example traz `http://localhost:5000`; mock escuta em 8080 por padrão. README §4 e roteiro mandam ajustar para 8080, mas §3.3 não avisa (D1).

**T58** (10 ADRs com 1 linha e link; sem texto copiado)
- ADRs 001-010 (+011 extra) com link para arquivos existentes em `.md/adr/`; DEC-01 a DEC-15 listadas (DEC-02 em parágrafo à parte, apontando `ambiente-licencas.md`); sem duplicação de texto.

### Integração (cross-platform-integration-testing): coerência cruzada

- README <-> INI example: seções/chaves e env vars idênticas; única divergência é a porta (D1).
- README/roteiro <-> mock: comando, porta 8080, modos e `curl /_modo` idênticos. Python 3.8+ ok (mock usa `from __future__ import annotations`).
- README <-> roteiro: contagem 12, caminhos e pacote `bin/` iguais em C12 e §2.
- roteiro <-> código: ver D2-D5.
- decisoes.md <-> ADRs/VISAO-PRODUTO §8: links e numeração conferem.

### Requisitos não funcionais

- Segurança/LGPD: nenhum segredo real nos docs (senhas fictícias, CPFs de teste válidos); roteiro pede log sem senha/CPF completo; nota LGPD do README coerente com o comportamento; RF7-04 não contradiz o roteiro.
- Usabilidade dos docs: notação declarada e estrutura legível; ressalvas D4.

### Achados (bug-documentation): nenhum Crítico, 5 Simples + 1 Informativo

| ID | Sev. | Local | Descrição |
|---|---|---|---|
| D1 | Simples | `README.md` §3.3; `config/erpvendas.ini.example` | INI example tem `BaseUrl=http://localhost:5000`; o mock roda em 8080. Roteiro e §4 mandam ajustar, mas §3.3 (INI) não avisa; quem seguir só a instalação testará contra a porta errada. Sugestão: nota em §3.3 ou alinhar o example. |
| D2 | Simples | roteiro C6-B | Cita o banner da venda bloqueada como "Há uma operação pendente no Financeiro. Use Pendências."; o código (`FormEdicaoVenda.pas:682`) exibe "Operação pendente de envio ao Financeiro: somente leitura. Use Pendências." Corrigir o texto (a mensagem de bloqueio do Service em `PendenciaFila.pas` está correta). |
| D3 | Simples | roteiro C2 | "Dado: preço 0/negativo" com esperado "Preço inválido". `ProdutoService` e `FormEdicaoProduto.MensagemCampo` só recusam vazio/negativo (`< 0`); preço 0 é aceito. Trocar por "vazio/negativo" (ou, se 0 deve ser inválido, é bug de código a decidir pelo Gestor). |
| D4 | Simples | roteiro C11 e C6 | C11 sem linha "Dado" (a notação do roteiro exige); C6 tem sub-casos A-E em vez de passos numerados, com passos implícitos (criar venda, `curl /_modo`, Confirmar). Acrescentar Dado em C11 e numerar C6. |
| D5 | Simples | roteiro C9 | Nenhum passo preenche o motivo de cancelamento e confere `MOTIVO_CANCELAMENTO` gravado; reenvio pela fila grava motivo NULL (RF10-02) e não é avisado. Acrescentar passo com "Cliente desistiu" e nota do NULL no reenvio. |
| D6 | Informativo | TASK.md (nota T58) | Diz DEC-02 "em aberto"; `docs/decisoes.md` a marca resolvida na T01 (correto). Atualizar a nota do TASK.md na consolidação. |

Reprovações críticas: nenhuma. Nenhum achado compromete o critério de aceite central de T56-T58.

### Não verificável por falta de IDE/ambiente (ressalva, não reprovação)

Execução real do roteiro (T59) e instalação limpa seguindo o README (T64); existência de `bin/` e `ERPVENDAS.FBK` (T61/T62); teclado/foco de C11 (T60); texto exato do erro de banco em C10 não amostrado.

### Fechamento estrutural

T56-T58 `Concluída`; dependências da Seção 4 do TASK.md satisfeitas (T59, T60, T64 são posteriores), sem órfãs e sem tarefa `Bloqueada`; nada exige redesenho. `TASK.md` não alterado por este agente; D1-D5 aguardam criação em `Refatoração Lote-15` na consolidação pós-DevSecOps.

### Veredito por tarefa

- T56: **Aprovada com ressalvas** (D2, D3, D4, D5).
- T57: **Aprovada com ressalvas** (D1; validação real em T64).
- T58: **Aprovada** (D6 informativo).

### Veredito do lote (chapéu QA)

**Aprovado com ressalvas.** Nenhuma reprovação crítica. Liberado ao chapéu DevSecOps. Pontos para auditoria: ausência de segredos/dados reais nos docs, mascaramento de log e retenção descritos no README §5 conforme o código, `/_modo` do mock sem autenticação (documentado como só-localhost).

## Refatoração Lote-15 — validação (2026-09-24)

Escopo: RF15-01..05 (só texto; validação estática contra `git diff HEAD~1` e `src/`, nada executado).

- RF15-01 Aprovada: banner (`FormEdicaoVenda.pas`), `MSG_BLOQUEIO_FILA`, "Preço inválido" (0 aceito), campo/apoio LGPD do motivo e reenvio com MOTIVO NULL (RF10-02) batem com o código.
- RF15-02 Aprovada com ressalva: C6 e C11 seguem Dado/Passos/Esperado; C6-A Esperado "(código HTTP 422)" não bate com a mensagem real com o mock `recusa` (simples, RF15-07). C6-B..E e F (aponta para C8/timeout-post) conferem.
- RF15-03 Aprovada com ressalva: §3.3 (5000 x 8080) e §5 (campos de `FinanceiroDTOs.pas`, motivo até 255) corretos; o aviso de porta foi inserido no meio da tabela do INI, quebrando a renderização (simples, RF15-06).
- RF15-04 e RF15-05 Aprovadas.
- Sem perda de texto pré-existente; UTF-8 sem BOM, EOL igual ao original (índice LF, cópia de trabalho CRLF por autocrlf).

**Veredito: Aprovado com ressalvas.** Nenhuma reprovação crítica; RF15-06 e RF15-07 criadas em `Refatoração Lote-15`.

## Refatoração Lote-12 — validação (2026-09-24)

Escopo: RF12-01..06 (9 arquivos; leitura de compilação e `git diff HEAD~1`, nada compilado nem executado).

- RF12-01 Aprovada: `eqFalhouSemFila` no fim do enum; usos em src/ (`PosQuitacao`, `ConfirmacaoVenda` `case` e `in [eqFalhou, eqFalhouSemFila]`) cobrem o valor; tests/ não usa `TEmailQuitacao`. `ERPV.Core.Log` na interface; construtor com `ALogger = nil` só na interface; Root passa `FLogger`.
- RF12-02 Aprovada: `Remetente` lido/validado em Config (padrão sem a chave; mensagem fixa), passado no Root; INI antigo sem a chave igual ao anterior.
- RF12-03 Aprovada: `OnFase: TProc<string>` (`System.SysUtils` ok), chamada best-effort; handler anônimo captura `AEspera` (const) e é limpo no `finally`.
- RF12-04 Aprovada: `EmailValido` (unit `Core.Validadores` no `uses`); construtor levanta `EInfra` com nil; nenhum chamador em src/tests passa nil.
- RF12-05 Aprovada com ressalva: `IdSSLOpenSSL`/`IdExplicitTLSClientServerBase` no `uses`; `VerificarPeer` bate com `TIdSSLVerifyPeerEvent`, mas a confirmação depende da IDE (RF12-09); campos novos lidos e usados. REGRESSÃO CONSCIENTE: sem as novas chaves e com `UsaTLS=1` o envio agora falha por falta de `CaFile` (padrão estrito); o `.example` de dev não avisa (RF12-08).
- RF12-06 Aprovada: §11.6 coerente; §11.5 ainda cita `utUseExplicitTLS` (RF12-08c).
- Encoding: nenhum caractere não ASCII novo em EmailSender/Config; acentos só em `ConfirmacaoVenda` (com BOM). `.example`: `CaFile=C:ERPVendasconfigcacert.pem` perdeu as barras (RF12-08a).
- Achados simples (sem retorno ao executor): RF12-07 (hostname, ver segurança), RF12-08, RF12-09.

**Veredito: Aprovado com ressalvas.** Nenhuma reprovação crítica nem erro de compilação óbvio. Liberado ao DevSecOps.

## Refatoração Lote-13 — validação (2026-09-24)

Chapéu QA, por leitura (nada compilado nem executado; sem compilador Delphi). Escopo: RF13-01..07 (commit `1b6da8f`, 13 arquivos).

- **Compilação/regressão por leitura**: `ObterItem` tem a mesma assinatura (out params) na interface, em `TFilaRepository`, `TFilaFake` e `TFilaMemoria` (únicas 3 implementações de `IFilaRepository`; declaração e implementação batem). `TFilaService.Create` com `AQuitacao`/`ALogger = nil` no fim: declaração = implementação; chamadores (Root, Setup dos testes) coerentes. `uses ERPV.Negocio.QuitacaoService` na interface do FilaService sem ciclo (QuitacaoService só usa Core/Dominio e `PendenciaFila`; nenhuma unit de Negocio referencia FilaService, só Root/UI/tests). Posse: FilaService não libera FQuitacao/FLogger; Root libera FilaService antes de QuitacaoService e o logger por último. `Nomes: array[TDesfechoReenvio]` cobre os 3 valores.
- **RF13-01**: `Reenviar` -> `ReenviarInterno` valida existência, PENDENTE, venda e tipo antes de qualquer efeito (sem RegistrarFalha/HTTP/e-mail); `EInfra` do `ObterItem` vira `rrFalha`. `RegistrarFalha` com `AND STATUS = 'PENDENTE'`, 0 linhas não é erro. UI: `PodeReenviarItem` lê o STATUS bruto ('PENDENTE'); o Tipo enviado pela UI é o da coluna, então o item EMAIL continua funcionando.
- **RF13-02**: pós-quitação só em `ConcluirLocal` com `AAlvo = svQuitada` (transição feita no reenvio via GET ou POST); não roda em venda já quitada localmente, nem em cancelamento; `rrConcluido` inalterado se o pós falhar (try/except + `ExecutarPosQuitacao` já defensivo); reaproveita `PosQuitacao` (RF12-01, `eqFalhouSemFila` tratado no `case`).
- **RF13-03/07**: `RecalcularBloqueioFila`, tratamento local só de `ERegraNegocio` (re-raise se não bloqueada), `FConfirmando` (RF9-02), `EnterAcionaSalvar`/`CMDialogKey` (RF7-01) e RF7-02 preservados; `DefinirOcupado` restaura o estado no finally; símbolos usados existem (`clERPVTextoSecundario`, `ERPVEspaco16`, `FGrade`, `BtnFechar`).
- **RF13-04/05/06**: máscara única em `Falha` (mesma Msg vai a `RegistrarFalha` e à UI; resultado esperado do teste confere com `MascararSensiveis`); um log por reenvio só com Ids/tipo/desfecho; `ExigirPendente` libera `AAtual` antes do raise (sem double free); `ERegraNegocio` não descende de `EInfra` (`ERPV.Core.Erros`), então o `raise` dentro do try de Confirmar não é engolido.
- **Testes**: sintaxe DUnitX coerente; defaults do fake (`ItemExiste`/`ItemPendente`, Id 1/2/3 = QUITACAO/CANCELAMENTO/EMAIL, venda 10) mantêm os testes antigos; `TVendaService` com nil de produto é seguro (Salvar/Excluir falham em `ExigirPendente` antes de `Validar`). Cobertura nova: 5 `Item_*`, 6 `PosQuitacao_*`, máscara, 9 `Bloqueio_*`/`Reenviar_ObterEInfra_ViraFalha`.
- **BOM/EOL**: 9 units de src com BOM (Root sem BOM e ASCII, como antes); `tests/ERPV.Testes.FilaService.pas` sem BOM e ASCII puro (grep sem ocorrências); `PendenciaFila.pas` de teste mantém o BOM anterior.

Achados simples (sem retorno ao executor; viram tarefas em `Refatoração Lote-13`, RF13-01..07 seguem `Concluída`):
- RF13-08: `MensagemDeReenvio` descarta a mensagem do pós-quitação quando `Concluiu`; o operador não vê "e-mail pendente/não enfileirado" (o RF13-02 fica silencioso na UI).
- RF13-09: `RecalcularBloqueioFila` pode levantar `EInfra` dentro do handler/pós-fluxo (vai ao handler global).
- RF13-10: confirmar na IDE (compilação dos testes e da form, foco/seleção da grade, suíte completa).

Nenhum erro de compilação certo encontrado; dúvidas de API concentradas em RF13-10.

**Veredito: Aprovado com ressalvas.** Sem reprovação crítica. Liberado ao DevSecOps.

## Refatoração Lote-11 — validação (2026-09-24)

Validação por leitura (nada compilado/executado). Escopo: RF11-01..06 (HEAD 69598c5).

- RF11-01: `GerarPdf(nil)` => EInfra + log; `Caminho`/`Result` inicializados antes do try, calculados dentro; except apaga parcial só com `Caminho <> ''` e dentro da pasta temp; `Create` com repositório nil levanta EInfra antes de atribuir campos (destruidor sem campos a liberar); LogAviso/LogErro nil-safe, nenhuma chamada direta a FLogger restante (só dentro deles); assinatura `Erro(const; AExcecao: Exception = nil)` confere. OK.
- RF11-03: variáveis declaradas (`Caminho, Sufixo: string; Guid: TGUID`), CreateGUID/GUIDToString/StringReplace em System.SysUtils (na uses); LimparAntigos casa `Pedido_*.pdf`. OK.
- RF11-06: `PastaPdfTempValida` correta (Copy(...,3,MaxInt) começa após "C:", então o ':' proibido só vale após a posição 2; Exit(True) dentro do for válido; CharInSet com literais). INI de exemplo `C:\ERPVendas\temp\pdf`, espaços/acentos e barra final aceitos; recusados relativo, `C:`, `C:\`, `\srv\x`. PastaPdfTemp é lida só do INI (LerObrigatoria, sem override por ERPV_*), então a validação cobre o valor final. Config.pas ASCII sem BOM, EOL sem CR. OK.
- RF11-04: TratarFalha('relatorio') com MSG_FALHA_RELATORIO fixa; coerente com RelatorioDataSet. OK.
- RF11-05 (DFM): sintaxe íntegra (só propriedades já usadas no arquivo, inteiros). Geometria do cabeçalho sem sobreposição: linha 1 (título 3704..39158; VENDA_ID 4233..21431; data 46302..86302; status 94986..134986), linha 2 nome 4233..196233 (top 13229..17462), linha 3 CPF 4233..39233 e e-mail 42000..192000 (top 18521..22754), rótulos das colunas top 26723/26988..31221 < band 31750; direita 196233 < 210000-6350. DisplayFormat em DATA_VENDA, PRECO_UNITARIO, SUBTOTAL, VALOR_TOTAL. Não resolvido (não é reprovação, exige Designer): WordWrap/Stretch (texto longo trunca), descrição ~100 caracteres no Detail, quebra de página, independência de locale do DisplayFormat, aceitação de `hh:nn` — viram RF11-07 e RF11-08. "Concluída com limitação" aceitável: layout não quebra compilação/DFM, limitação documentada e coberta por tarefa.
- BOM/EOL: RelatorioPedido e VendaRepository com BOM; Config e .dfm sem BOM; sem CR nos arquivos; acentos só em units com BOM (README/.md UTF-8). OK.

Nenhum erro de compilação certo; dúvida de API só em DisplayFormat (RF11-08). Ressalva cosmética: célula de RF11-01 no TASK.md contém um caractere de tabulação no lugar de `\t` de "try" (herdado, sem efeito).

Novas tarefas: RF11-07 (conferir cabeçalho/Detail/paginação no Designer), RF11-08 (formato pt-BR/locale e DisplayFormat), RF11-09 (ponto-ponto e unidade mapeada em PastaPdfTempValida).

**Veredito: Aprovado com ressalvas.** Sem reprovação crítica. Liberado ao DevSecOps.


## Refatoração Lote-3 — validação (2026-09-24)

Chapéu QA, por leitura (nada compilado/executado). Commit 17dbc05 (RF3-01..03).

- RF3-01: `clERPVTextoSobreDestaque = TColor($FFFFFF)` é branco em qualquer ordem de bytes (mesmo valor de `clWhite`); nome/formato/comentário coerentes com os vizinhos. FormMain (~l.270) e Tema.EstilizarBotao (NormalText/HotText/PressedText/Font.Color) usam o token; ambas as units já têm `ERPV.UI.Tokens` no uses. Grep em `src/UI` por `clWhite|clBlack|clSilver|clGray|TColor(|$RRGGBB` fora de Tokens: zero. Outros literais (clRed/clBlue/RGB( etc.): nenhum. OK.
- RF3-02: FormBaseLista.pas começa com EF BB BF, diff de 1 linha (só a 1ª), CRLF preservado. Todas as .pas de `src/UI` têm BOM; as 7 .pas sem BOM em `src/` e `tests/` são ASCII puro. OK.
- RF3-03: linha removida do meio da lista uses do `.dpr` mantém a sintaxe (vírgulas intactas, `ERPV.UI.Tokens` termina com `;`); `.dproj` íntegro (só 1 linha `DCCReference` removida). Nenhuma outra referência a `ERPV.UI.FormTesteTema` no repositório além do próprio arquivo (utilitário manual em `src/UI`), do comentário de FormBaseLista e das notas do TASK.md. Nenhum roteiro em `docs/` manda abrir o form de teste. Nota cosmética (sem tarefa): a nota histórica da T68 no TASK.md ainda diz que o form está "no .dproj" (era verdade na época; superada pela RF3-03).
- Notas do TASK.md de RF3-01..03: uma linha por célula, honestas (declaram "não compilado nem executado"). Detalhe irrelevante: o critério do RF3-01 cita FormMain "~linha 209", hoje ~270.
- Pendência de verificação real (não é reprovação): compilar/abrir a tela principal na IDE e conferir aparência inalterada (faixa de marca e botão Primário).

**Veredito: Aprovado com ressalvas** (só a verificação em compilação real, herdada de todo o lote). Sem reprovação crítica nem simples nova. Liberado ao DevSecOps.

## Refatoração Lotes 6, 8, 9 e 10 (documentação) — validação (2026-09-24)

Chapéu QA, por leitura (nada compilado/executado). Commit 484fe9c (RF6-03, RF8-02, RF9-04, RF10-04); 5 arquivos, só comentário/texto.

- Nenhuma linha executável alterada nas 3 units: as linhas adicionadas/removidas ficam todas dentro do bloco `(* ... *)` de cabeçalho (Root l.3-106, FinanceiroClient l.3-64, QuitacaoService l.3-74); os textos novos não contêm `*)` nem `(*`; o `*)` de fechamento continua na mesma posição e o `interface` vem logo depois. BOM/EOL preservados: QuitacaoService com BOM UTF-8, Root e FinanceiroClient sem BOM, mesma convenção de EOL do commit anterior (blobs LF, checkout CRLF), TASK/UX-SPEC idem.
- Fidelidade: Root (construtor monta Venda/Cliente/Produto/Fila repos, Cliente/Produto/Venda services, Financeiro, RelatorioPedido, EmailSender, Quitacao e Fila; Destroy em ordem inversa) confere com o cabeçalho. FinanceiroClient: Root instancia com BaseUrl/TimeoutMs/ApiKey/Logger; mock com porta padrão 8080 (mock_financeiro.py e README); `CMaxMensagem = 200`; só EmailSender é DCCReference em Integracao (.dproj). QuitacaoService: `Quitada` (CHECK de VENDAS) e `FILA_INTEGRACAO` conferem com db/01_schema.sql; motivo limitado a 255 e enfileirado com '' (`Enfileirar(..., tfCancelamento, '')`); OnFase/ExecutarPosQuitacao/logger opcional existem. Roteiro do timeout-post concorda com tools/mock-financeiro/README.md (não quitar via curl antes; 1 POST no log; FILA_INTEGRACAO sem QUITACAO PENDENTE).
- UX 4.3: as 6 linhas novas têm o mesmo número de colunas (3) das vizinhas e os textos batem literalmente com FormCancelamentoVenda.pas (recusa, enfileirada, resposta inválida, `A venda não pode ser cancelada.`, apoio LGPD) e com as mensagens de dcNaoPermitida de QuitacaoService.Cancelar.
- Tabelas do TASK.md: as 11 linhas alteradas (T25, T27-T30, T33, T34, T38, T41, T42, RF6-03, RF8-02, RF9-04, RF10-04) mantêm 12 barras; sem quebra de linha real. T25/T27-T30 sem "Detalhes:" vazio nem `ERPV.Temp.TesteT27`; T33/T34 sem "stubs"; T38/T41/T42 sem reaberturas resolvidas; a pendência real (compilação/execução na IDE, prova T41 pelo usuário) foi mantida. Nenhuma ocorrência remanescente de `FILA_SINCRONIZACAO`/`STATUS=QUITADA` em units, SQL ou docs vivos (só em texto histórico de relatórios e das linhas RF9-04/RF10-04).
- Ressalvas simples (viraram tarefas): RF6-05 (comentários do Root ~l.142/~l.188 ainda citam "próximos incrementos"; nota de T25 ainda chama `ListarDataSet`/`ExisteVendaPor*` de stubs, hoje implementados por T26; a própria nota de RF6-03 já declarava o item do Root como pendente); RF10-06 (nota de RF10-04 diz que as menções de FILA_SINCRONIZACAO/STATUS=QUITADA foram mantidas, superado por RF9-04). Os IDs RF6-04 e RF10-05 não foram reutilizados: já constam de relatórios anteriores como achados absorvidos por RF6-01/RF10-04.
- Pendência de verificação real (não é reprovação): compilar na IDE (comentários de cabeçalho bem formados, confirmado só por leitura).

Checagem estrutural: RF6-03, RF8-02, RF9-04 e RF10-04 `Concluída`; dependências coerentes (RF9-04 sobre o cabeçalho do QuitacaoService que RF10-04 já tinha editado: o texto final contém ambos os ajustes, sem conflito); nenhuma tarefa `Bloqueada`; Bloqueio 006 não afeta os lotes. Os lotes 6/8/9/10 têm outras linhas RF já `Concluída` e validadas por leitura antes (RF6-01/02, RF8-01/03, RF9-01/02/03/05, RF10-01/02/03); esta chamada só acrescenta as 4 de documentação.

**Veredito: Aprovado com ressalvas.** Sem reprovação crítica. Liberado ao DevSecOps (feito abaixo, no SECURITY-REVIEW).
