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
