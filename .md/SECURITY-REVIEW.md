# SECURITY-REVIEW — ERP Vendas (Delphi)

Produzido pelo Validador (chapéu DevSecOps), depois da aprovação funcional
do chapéu QA (`QA-REPORT.md`, Lote 1: Aprovado). Base: `SDD.md` Seção 7
(Requisitos de Segurança), `GUARDRAILS.md` (regras 11-19), `PRD-TECNICO.md`.

## Lote 1 — Ambiente e infraestrutura externa (D1)

Escopo aplicável a este lote (sem código Delphi ainda): segredo/credencial
commitado (GUARDRAILS regra 16), exposição de dado pessoal em dado de demo
(regra 18), integridade dos artefatos de dados que servirão de 2ª barreira
para validação futura (regra 11/12), e consistência do que já foi
documentado sobre segurança operacional para as tarefas futuras.

### 1. Varredura de segredo/credencial commitado (GUARDRAILS regra 16)

Varredura por padrão de senha/host/token/chave/masterkey em todos os
artefatos produzidos pelo lote:

| Artefato | Resultado |
|---|---|
| `db/01_schema.sql` | Nenhuma credencial real. Menções a `SYSDBA`/`-password <senha>` são só comentário de exemplo de como *invocar* o `isql` externamente (placeholder `<senha>`, não valor real) — conforme já indicado pela própria nota de implementação de T03. Sem `CONNECT`/`CREATE DATABASE` embutido. |
| `db/02_seed.sql` | Idem acima; nenhuma credencial embutida; nenhuma linha de conexão. |
| `tools/mock-financeiro/mock_financeiro.py` | Nenhum segredo; servidor local (`127.0.0.1` padrão) sem autenticação no `_modo` — README já documenta essa limitação e recomenda não expor fora de localhost/rede de dev (adequado para ferramenta de desenvolvimento, ADR-009, fora do pacote de entrega). |
| `tools/mock-financeiro/README.md` | Nenhum segredo. |
| `docs/contrato-api-financeiro.md` | Nenhuma credencial; `X-Api-Key` tratado apenas como conceito (header opcional), sem valor de exemplo real. |
| `docs/ambiente-licencas.md` | Nenhuma chave de licença/número de série. Seção 10 do próprio arquivo já autodeclara essa confirmação; conferido de fato: nenhuma ocorrência de chave/serial nas ~470 linhas do arquivo — só nomes de arquivo de licença (`RB Professional (Trial) License.txt`) e texto de limitação, nunca o conteúdo secreto. Placeholders de senha em exemplos de código (`'<senha do painel>'`, `'<usuario do painel>'`) explicitamente marcados como não-reais, com nota "nunca commitar; só em INI/env, ADR-007/008". |

**Achado**: nenhum. Regra 16 respeitada em todos os artefatos do lote.

### 2. Exposição de dados sensíveis (GUARDRAILS regra 17/18, `sensitive-data-exposure-check`)

- `db/02_seed.sql`: dados pessoais (nome, CPF/CNPJ, endereço, telefone,
  e-mail) presentes, mas **claramente fictícios** (nomes "Exemplo",
  domínios `@example.com`/`@mailtrap-sandbox.test`) — conforme GUARDRAILS
  regra 18 ("dados de demo fictícios"). Não é exposição real de dado de
  titular.
- `tools/mock-financeiro/mock_financeiro.py`: log (`log_message`) registra
  apenas método/rota/status, sem corpo de requisição/resposta — não grava
  CPF/CNPJ, valores ou qualquer dado pessoal em log, alinhado à regra 17
  (ainda que a regra 17 seja escrita pensando no log da aplicação Delphi
  futura, o mock já nasce alinhado ao mesmo princípio).
- `docs/contrato-api-financeiro.md`: confirma que ao Financeiro só trafegam
  IDs, valores e itens — nenhum dado pessoal no payload de integração,
  conforme SDD.md §7 e GUARDRAILS regra 18.

**Achado**: nenhum.

### 3. Integridade/2ª barreira de dados (GUARDRAILS regra 11/12, SDD §7 "Injeção/integridade")

- `db/01_schema.sql` implementa CHECK/UNIQUE/FK como segunda barreira
  (`CK_VENDAS_STATUS`, `CK_ITENS_QTD`, `CK_PRODUTOS_PRECO`,
  `CK_CLIENTES_TIPO`, `CK_FILA_TIPO`, `CK_FILA_STATUS`, `UQ_CLIENTES_DOC`),
  consistente com a exigência de que validação de Service não seja a única
  barreira. `NUMERIC(15,2)` em todo valor monetário (nunca `Double`/`Float`),
  atendendo à regra 12. FK com `ON DELETE CASCADE` restrito a
  `VENDA_ITENS -> VENDAS` (não em cascata para CLIENTES/PRODUTOS, coerente
  com a regra de inativação em vez de exclusão física da regra 19 — a ser
  implementada em Service no Lote 6).

**Achado**: nenhum.

### 4. Compliance (LGPD básica, SDD §7)

- Seed com CPF/CNPJ de teste (dígitos verificadores válidos, mas titulares
  fictícios) e e-mails de sandbox — sem coleta de dado real de titular.
  Conforme.
- Nenhuma tarefa deste lote envolve tratamento de dado pessoal real (ainda
  não há aplicação rodando); compliance obrigatório aplicável a este lote
  está atendido.

**Achado**: nenhum compliance obrigatório em aberto.

### 5. Requisitos de segurança operacional para o próprio chapéu DevOps (preparação adiantada)

Registrado aqui para uso do próprio Validador (chapéu DevOps) quando
`infrastructure-as-code-provisioning`/`cicd-pipeline-configuration` rodar:

- Gestão de secrets: `erpvendas.ini` (real) nunca deve entrar em
  repositório nem em pipeline de CI/CD; usar variável de ambiente/secret
  manager do ambiente de deploy para senha SMTP/ApiKey (já é a diretriz do
  `TASK.md` Seção 1 e GUARDRAILS regra 16 — DevOps só precisa herdar, não
  criar exceção).
- `.gitignore` atual (raiz) ainda não lista `erpvendas.ini`/`*.FDB`/pasta de
  log/PDF temp — isso é esperado só a partir de T07 (Lote 2, esqueleto do
  projeto Delphi, que cria essas pastas); **não é achado deste lote**, só
  fica anotado aqui para o Validador conferir de novo na validação do
  Lote 2 (a Seção 1 do `TASK.md` já lista isso como parte do critério de
  aceite de T07).
- Mock do Financeiro (`tools/mock-financeiro/`) é ferramenta de dev/demo,
  fora do pacote de produção (ADR-009) — não deve ser incluído em nenhum
  artefato de deploy/build de produção; DevOps deve garantir que o
  pipeline de build (T61) não empacote a pasta `tools/`.

### 6. Achados de relevância estratégica (sinalização ao Gestor)

Nenhum achado deste lote atinge o critério de relevância estratégica
(nenhuma decisão de negócio/compliance em aberto). Os 3 riscos não
bloqueantes de T01 (runtime packages do DevExpress para T61, validade do
trial, milissegundos do `THTTPClient`) são de natureza técnica/operacional,
já documentados e rastreáveis em `docs/ambiente-licencas.md` — não exigem
decisão de negócio agora; serão revisitados quando T34/T61 forem
executadas.

### Veredito do lote (chapéu DevSecOps)

**Aprovado**, sem achado de severidade alta/crítica nem compliance
obrigatório em aberto, e sem débito registrado. Libera o lote para o
fechamento estrutural e, quando decidido pelo usuário, para `/deploy`
(quando aplicável — este lote não contém código executável a publicar; a
preparação de infraestrutura/CI-CD segue o timing padrão de `validador.md`,
assim que o `SDD.md`/próximos lotes com código estiverem prontos).

## Lote 2 — Núcleo Delphi (D1)

Auditoria feita depois da aprovação funcional do chapéu QA (`QA-REPORT.md`,
Lote 2: Aprovado, T07-T13). Escopo: primeiro lote com código Delphi
executável — composition root, config, log, exceções, conexão de banco,
domínio e esqueleto de projeto/UI. Base: `SDD.md` Seção 7, `GUARDRAILS.md`
regras 11, 16-19, 21, 26, ADR-002, ADR-007, ADR-008. Verificação por leitura
linha a linha do `git diff`/código-fonte das 15 units do lote — não a nota
de implementação do Executor.

### 1. Segredo/credencial commitado (GUARDRAILS regra 16)

| Artefato | Resultado |
|---|---|
| `config/erpvendas.ini.example` | Todos os valores são claramente fictícios (`senha_ficticia_dev`, `senha_ficticia_smtp`, `usuario_ficticio_mailtrap`, `sandbox.smtp.mailtrap.io`, caminhos locais de exemplo). `ApiKey` vazio (DEC-07). Comentário no topo do arquivo já documenta as 3 variáveis de ambiente preferenciais. Nenhuma credencial real. |
| `.gitignore` (raiz) | `erpvendas.ini` (arquivo real) e `config/*.ini` (com exceção explícita `!config/erpvendas.ini.example`) estão listados; também cobre `*.dcu/*.dcp`, `logs/`, `*.pdf`, `*.exe/*.res`, `*.lic/*.key/*.license/*.slip` (licenças DevExpress/ReportBuilder). Cumpre a lacuna já antecipada no `SECURITY-REVIEW.md` do Lote 1 (Seção 5). |
| `git ls-files \| grep -iE ".ini$\|.fdb$\|logs/"` | Vazio — nenhum INI real, `.FDB` ou pasta de log versionado. |
| `git log --stat` de todo o lote (`f291f91..6070679`) | Só arquivos `.pas`/`.dpr`/`.dproj`/`.md` alterados; nenhum `.FDB`/log/PDF de teste commitado por engano. |
| `src/Core/ERPV.Core.Config.pas` | Segredos (`Banco.Senha`, `SMTP.Senha`, `Financeiro.ApiKey`) resolvidos por `LerComVariavelDeAmbiente`: variável de ambiente (`ERPV_BANCO_SENHA`, `ERPV_SMTP_PASSWORD`, `ERPV_FINANCEIRO_APIKEY`) checada e usada **antes** do INI (`GetEnvironmentVariable` primeiro, só cai no `AIni.ReadString` se vazia) — prioridade de ambiente sobre INI confirmada linha a linha, conforme ADR-007/008 e a instrução do prompt. |
| `src/Dados/ERPV.Dados.Conexao.pas` | Senha do banco só passa por `FConnection.Params.Add('Password=' + FConfiguracao.Banco.Senha)` (propriedade de conexão do FireDAC, nunca concatenada em SQL) e nunca é passada a `FLogger`/`MessageDlg`. |

**Achado**: nenhum.

### 2. SQL sempre parametrizado (GUARDRAILS regra 11)

`ERPV.Dados.Conexao.pas` (T12) é a única unit do lote que toca banco, e seu
escopo é só conexão/transação (`IniciarTransacao`/`Confirmar`/`Desfazer`) —
sem nenhuma query de negócio. Confirmado: nenhuma concatenação de string
formando SQL em nenhuma unit do lote; a única ocorrência de `ExecSQL`
(`'SELECT 1 FROM RDB\$DATABASE'`) está dentro do roteiro de verificação
manual em comentário de cabeçalho (não é código de produção), usa uma
constante literal sem interpolação de dado externo, e nem chegaria a
constituir injeção mesmo se fosse código real. Os `Params.Add('Database=' +
...)`/`'User_Name=' + ...`/`'Password=' + ...` são propriedades de conexão
do FireDAC (`TFDConnection.Params`), não comandos SQL. `src/Dominio/*`
(T08) não referencia `FireDAC.*`/`Data.DB` além dos 4 Contratos que usam
`TDataSet` só como tipo de retorno de interface (ADR-010), sem SQL embutido.

**Achado**: nenhum.

### 3. Exposição de dado sensível em log (GUARDRAILS regra 17, `sensitive-data-exposure-check`)

`ERPV.Core.Log.pas` (T10): `GravarLinha` força **toda** mensagem (inclusive
o `AExcecao.Message` concatenado em `Erro`) a passar por
`MascararSensiveis` antes de tocar o arquivo — não existe caminho de escrita
que pule essa função (nenhum método público grava string crua). Mascaramento
revisado regex a regex:
- CNPJ formatado e só-dígitos, CPF formatado e só-dígitos: cobertos, com
  `\b` de fronteira de palavra e ordem CNPJ→CPF (evita CNPJ de 14 dígitos
  ser parcialmente capturado pela regra de CPF de 11).
- E-mail: preserva 1 caractere + domínio inteiro.
- Rede de segurança extra: `(?i)\b(senha|password|apikey|api_key|token|secret)\b\s*[:=]\s*\S+` → substitui o valor por `******`, mesmo se o chamador
  cometer o erro de logar a chave/valor bruto na mensagem — reduz (não
  elimina) o risco de erro humano em chamadas futuras (T14+).
- Falha ao gravar log é engolida (best effort) — não derruba a aplicação,
  conforme ADR-008, e não é um caminho por onde dado sensível vazaria de
  outra forma (é só ausência de log, não exposição).

Verificado também: `ERPV.Dados.Conexao.pas` e `ERPV.Core.Erros.pas`
(`TTratadorDeExcecoes.AoTratarExcecao`) sempre chamam `FLogger.Erro`/
`FLogger.Aviso`/`FLogger.Info` (nunca escrevem em arquivo por conta própria),
então toda mensagem técnica que chega ao log passa pelo mascaramento acima,
inclusive a mensagem original do FireDAC (que pode conter usuário/host do
banco) capturada em `Conectar`/`IniciarTransacao`/`Confirmar`.

**Achado**: nenhum.

### 4. Mensagem ao usuário livre de SQL/caminho sensível/stack/credencial (GUARDRAILS regra 17, ADR-008)

- `EIntegracao`/`EInfra` (caso geral): `MensagemAmigavel` devolve a
  constante fixa `MSG_INTEGRACAO_INFRA`/`MSG_ERRO_INESPERADO`, nunca
  `E.Message` — confirmado no código (`ERPV.Core.Erros.pas`, função
  `MensagemAmigavel`).
- `ERPV.Dados.Conexao.pas`: toda falha do FireDAC (`Conectar`,
  `IniciarTransacao`, `Confirmar`) captura a exceção original, grava o
  detalhe técnico completo (que pode ter Database/host/usuário) só no log,
  e relança `EInfra.Create(MSG_FALHA_CONEXAO)`/`EInfra.Create(MSG_FALHA_TRANSACAO)`
  — mensagens fixas, sem interpolar nada do erro original. Confirmado que a
  mensagem exibida é **idêntica** para "banco offline" e "senha errada"
  (mesma constante `MSG_FALHA_CONEXAO` nos dois casos) — não permite ao
  usuário/atacante distinguir os dois cenários pela mensagem de erro, um
  cuidado adicional correto (evita enumeração de credencial válida por
  diferença de mensagem).
- **Achado específico do prompt — `EInfraMensagemSegura`/`EConfiguracao`**
  (commit `966a508`, revisão de segurança independente da revisão funcional
  já feita pelo chapéu QA):
  1. Conferidas as 3 mensagens que `EConfiguracao` pode lançar
     (`ValidarArquivo`, `ValidarSecoesObrigatorias`, `LerObrigatoria`,
     `ERPV.Core.Config.pas` linhas 187-219): as três usam `CreateFmt` com
     apenas `FCaminhoArquivo`/`ACaminho` (caminho do próprio
     `erpvendas.ini`) e nome de seção/chave (`'Banco'`, `'Financeiro'`,
     `'SMTP'`, `'Relatorio'`, `'Log'`, ou o nome da chave lida) — nenhuma
     interpola valor de segredo (`Senha`/`ApiKey` nunca são lidos antes da
     validação de presença, e mesmo que fossem, a mensagem de
     `LerObrigatoria` só usa `AChave`, o nome da chave, nunca `Result`/o
     valor). Nenhuma menção a SQL, stack ou host de rede. Confirmado.
  2. Disciplina de uso: hoje `EInfraMensagemSegura` só é herdada por
     `EConfiguracao` (`grep -rn "EInfraMensagemSegura"` retorna só
     declaração/uso em `ERPV.Core.Erros.pas` e `ERPV.Core.Config.pas`) — sem
     uso incorreto atual. Achado de **severidade baixa**: o mecanismo é uma
     subclasse "opt-in" (precisa herdar dela explicitamente, não é o
     comportamento padrão de `EInfra`), e o comentário de cabeçalho da
     classe (`ERPV.Core.Erros.pas` linhas 200-212) já deixa o contrato
     explícito ("quem lançar uma exceção dessa subclasse está afirmando essa
     garantia"), o que mitiga bem o risco de reuso descuidado. Ainda assim,
     não há nenhuma trava estrutural (revisão de código é a única barreira)
     que impeça uma tarefa futura (T17+) de criar `EInfra` derivada dessa
     subclasse com uma mensagem que acidentalmente inclua dado sensível —
     o nome da classe e o comentário são fortes, mas dependem de quem
     escreve a próxima subclasse ler e respeitar o contrato. **Recomendação
     (não bloqueante, sem ação corretiva obrigatória agora)**: quando uma
     próxima tarefa (ex.: futura mensagem de infraestrutura "segura")
     precisar herdar de `EInfraMensagemSegura`, o Validador (chapéu
     DevSecOps) deve auditar a mensagem daquela nova subclasse com o mesmo
     rigor do item 1 acima antes de aprovar o lote — já é o comportamento
     padrão desta skill (`static-security-analysis` roda em todo lote), não
     precisa de tarefa nova em `Refatoração Lote-X` agora; registrado aqui
     como nota de atenção para a próxima auditoria que tocar
     `ERPV.Core.Erros.pas`.
  3. Caminho do INI exposto (`ACaminho`/`FCaminhoArquivo`, valor padrão
     `ExtractFilePath(ParamStr(0)) + 'erpvendas.ini'`): é um caminho de
     disco local (pasta do próprio executável), não expõe host de banco,
     usuário do SO, nome de máquina de rede interna nem qualquer segredo —
     é exatamente a informação que o usuário final precisa para localizar e
     corrigir o arquivo. Quando `ACaminhoIni` é passado explicitamente pelo
     chamador (parâmetro opcional do construtor, hoje sem nenhum chamador no
     lote além do padrão), o valor também é só um caminho de arquivo, sob
     controle de quem constrói `TConfiguracao` — não há cenário no código
     atual em que esse caminho viria de entrada não confiável do usuário
     final em tempo de execução. Confirmado: não constitui vazamento de
     informação sensível de infraestrutura.

**Achado**: 1 achado de severidade **baixa** (item 2 acima) — observação de
processo (auditar a próxima subclasse de `EInfraMensagemSegura` quando
surgir), já coberta pelo próprio ritual de auditoria contínua deste agente;
não bloqueia o lote, não gera débito com prazo nem tarefa em
`Refatoração Lote-X` (mitigação já suficiente via nome de classe + comentário
de contrato, sem custo de manutenção adicional a impor agora).

### 5. Compliance (LGPD básica, SDD §7)

Nenhuma tarefa deste lote trata dado pessoal real em runtime além do
mascaramento de log (Seção 3 acima) e da configuração de conexão (sem PII).
Nenhum compliance obrigatório em aberto.

### 6. Requisitos de segurança operacional para o próprio chapéu DevOps

- Confirma-se a partir deste lote (T07) que `.gitignore` cobre `erpvendas.ini`,
  `logs/`, `*.pdf`, `*.lic/*.key/*.license/*.slip` — pipeline de CI/CD
  (`cicd-pipeline-configuration`) deve continuar usando variável de
  ambiente/secret manager para `ERPV_BANCO_SENHA`/`ERPV_SMTP_PASSWORD`/
  `ERPV_FINANCEIRO_APIKEY` em vez de gerar um `erpvendas.ini` real versionado
  em qualquer etapa do build.
  - Observabilidade: `ERPV.Core.Log.pas` já mascara CPF/CNPJ/e-mail/segredo
  antes de gravar — qualquer coleta futura desses logs por ferramenta de
  observabilidade (DevOps) herda essa proteção automaticamente, sem exigir
  filtro adicional na ingestão.
- Firebird embedded/servidor: a string de conexão (`Database=`) vem de
  `TConfiguracaoBanco.Caminho`, lido do INI — DevOps deve garantir que o
  ambiente de produção não exponha esse INI/variável de ambiente fora do
  processo da aplicação (ex.: não logar variáveis de ambiente do processo em
  ferramenta de CI/CD).

### 7. Achados de relevância estratégica (sinalização ao Gestor)

Nenhum. O achado de severidade baixa da Seção 4 é uma nota de processo para
a próxima auditoria, não uma decisão de negócio/compliance.

### Veredito do lote (chapéu DevSecOps)

**Aprovado**, sem achado de severidade alta/crítica nem compliance
obrigatório em aberto. Há 1 achado de severidade baixa (Seção 4, item 2 —
disciplina de uso futuro de `EInfraMensagemSegura`), já com mitigação
suficiente registrada (nome de classe + comentário de contrato) e sem
necessidade de tarefa em `Refatoração Lote-X` nem prazo — vira apenas nota
de atenção para a próxima auditoria de `ERPV.Core.Erros.pas`. Libera o lote
para o fechamento estrutural (checagem do Validador) e, com a dupla
aprovação QA+DevSecOps deste lote, para `/deploy` quando o usuário decidir
(preparação de infraestrutura/CI-CD segue em paralelo desde o início,
conforme timing padrão).

## Lote 3 — Casca de UI, tokens e tema (D2)

Escopo: `ERPV.UI.Tokens`, `ERPV.UI.Tema`, `ERPV.UI.Icones`, `ERPV.UI.FormMain`, `ERPV.UI.FormBaseLista`, `ERPV.UI.FormBaseEdicao`, `scripts/gerar-icones.js`, `assets/icones`. QA do lote: Aprovado com ressalvas. Análise por leitura de código (sem SAST automatizado disponível); sem recompilação.

### 1. Segredo/credencial no repositório
`scripts/gerar-icones.js` só importa `fs`, `path`, `zlib` (gera PNG localmente, sem rede, sem `eval`/`child_process`, sem credencial). `assets/` contém apenas 48 PNGs (nenhum outro tipo de arquivo). Nenhuma senha/token/chave nas units do lote. Sem achado.

### 2. Forms sem SQL/regra/HTTP (GUARDRAILS)
`FormMain`, `FormBaseLista`, `FormBaseEdicao` não referenciam FireDAC, Dados nem cliente HTTP; `FormMain` depende só de Tokens/Tema/Icones e dos Services de Cliente/Produto. A URL do Financeiro chega por parâmetro (`Configurar`) e é só exibida. Sem achado.

### 3. Mensagens ao usuário
Nenhum `MessageDlg`/`ShowMessage`/`MessageBox` nos forms do lote; tudo passa por `Notificar` (o único `Vcl.Dialogs` em `Tema` é a implementação de `Notificar`). Mensagens do shell são fixas e sem dado sensível. Sem achado.

### 4. Camadas ADR-001/010
UI -> Negocio (Services) apenas; sem referência a `Dados`. Sem achado.

### 5. Tokens (cores/fontes)
Todas as cores e fontes vêm de `ERPV.UI.Tokens`, exceto `clWhite` (texto da faixa de marca em `FormMain` e texto/hover/pressed do botão Primário em `Tema.EstilizarBotao`). **Achado 1 (baixa, qualidade/consistência, não segurança):** vira RF3-01 (já declarado em parte pelo Executor).

### 6. `ERPV.UI.Icones`
Degrada sem exceção (pasta ausente, arquivo ausente ou corrompido, tamanho divergente: ignorado; todas as rotinas públicas com try/except). Só lê `assets\icones\{16,24,32}\<nome>.png`, onde `<nome>` vem de constantes fixas (`ERPVIcone*`), nunca de entrada do usuário: sem path traversal. A busca da pasta sobe no máximo 7 níveis a partir do `.exe` procurando `assets\icones` (leitura apenas); risco residual desprezível. Sem achado.

### 7. BOM/encoding
`FormMain`, `FormBaseEdicao`, `Icones`, `Tema`, `Tokens` com BOM UTF-8. **Achado 2 (baixa):** `FormBaseLista.pas` sem BOM (hoje só ASCII, sem mojibake; risco se entrar acento). Vira RF3-02.

### 8. Superfície de release
**Achado 3 (baixa):** `ERPV.UI.FormTesteTema` (form de teste do tema) continua no `.dpr`/`.dproj`; fora do fluxo, mas seria compilado no build final. Vira RF3-03.

### 9. Compliance e operacional
Sem dado pessoal manipulado neste lote. Nenhum requisito operacional novo para o chapéu DevOps (nota herdada: perfil Debug com `DCC_UsePackages=true` a revisar antes do build de T61, já registrado em T68). Nada de relevância estratégica para o Gestor.

### Veredito do lote (chapéu DevSecOps)
**Aprovado com débito baixo** (achados 1-3, RF3-01 a RF3-03). Sem achado alto/crítico nem compliance em aberto. Libera para `/deploy` quando o usuário decidir.

## Lote 4 — Cadastro de Clientes (D2)

Escopo: `ERPV.Dados.ClienteRepository`, `ERPV.Negocio.ClienteService`, `ERPV.Core.Validadores`, `FormListaClientes`, `FormEdicaoCliente`. QA do lote: Aprovado com ressalvas. Análise por leitura de código (sem SAST automatizado disponível); sem recompilação.

### 1. Segredo/credencial no repositório
Varredura por `password/senha/apikey` em `.pas/.dpr/.ini/.sql/.js`: só `config/erpvendas.ini.example` com valores fictícios, leitura por variável de ambiente e a montagem de `Password=` em `Conexao.pas` (já auditada no Lote 2). Nenhum segredo nas units do Lote 4. Sem achado.

### 2. SQL parametrizado (regra 11)
`ClienteRepository`: INSERT/UPDATE/DELETE/SELECT/existe-por-documento usam `ParamByName` para todo valor. A listagem concatena apenas fragmentos de SQL constantes (`AND ATIVO = TRUE`, bloco de busca); o texto do usuário entra só como parâmetro, com `%`, `_` e `\` escapados. Sem SQL em form, Service ou Dominio. Sem achado.

### 3. Log e dados sensíveis (regra 17)
O repositório loga só a operação e a exceção do FireDAC via `TLogger.Erro` (que mascara CPF/CNPJ/e-mail e redige senha, verificado na T10); nenhum valor de parâmetro é passado ao log. Forms e Service não logam. Sem achado.

### 4. Mensagens ao usuário e achados
Mensagens do repositório são fixas e amigáveis (sem SQL/caminho/credencial); a UI mostra `E.Message` apenas de `EErpVendas` e cai em texto genérico para qualquer outra exceção. **Achado 1 (baixa):** o repositório levanta `EInfra` (não `EInfraMensagemSegura`) para duplicidade/em uso/não encontrado; hoje funciona porque a UI usa `E.Message`, mas via `Application.OnException` sairia a mensagem genérica. É a nota de disciplina já prevista no Lote 2. Falha para o lado seguro (não vaza). Vira RF4-02, prazo antes do Lote 16.

### 5. Camadas ADR-001/010
Grep em `Negocio`, `Dominio` e `Core`: `Vcl`/`FireDAC` só aparecem em comentários, exceto `Vcl.Dialogs` em `ERPV.Core.Erros` (tratador de exceções, exceção documentada e aceita no Lote 2). `Negocio` não referencia `Dados`. Forms dependem só de `TClienteService`, sem SQL/regra de negócio. Sem achado.

### 6. Compliance (LGPD básica) e operacional
CPF/e-mail tratados como dado pessoal: mascarados em log, não expostos em mensagem. Nenhum requisito operacional novo para o chapéu DevOps. Nada de relevância estratégica para o Gestor.

### Veredito do lote (chapéu DevSecOps)
**Aprovado com débito baixo** (achado 1, RF4-02). Sem achado alto/crítico nem compliance em aberto. Libera para `/deploy` quando o usuário decidir.

## Lote 5 — Cadastro de Produtos (D2)

Escopo: `ERPV.Dados.ProdutoRepository`, `ERPV.Negocio.ProdutoService`, `FormListaProdutos`, `FormEdicaoProduto` e a integração em `FormMain`/`ERPV.App.Root`. QA do lote: Aprovado com ressalvas. Análise por leitura de código (sem SAST automatizado disponível); sem recompilação.

### 1. Segredo/credencial no repositório
Nenhum segredo nas units do Lote 5. A unit temporária `ERPV.Temp.TesteT22` foi removida (não há arquivo `*Temp*` no repositório). Sem achado.

### 2. SQL parametrizado (regra 11)
`ProdutoRepository`: INSERT/UPDATE/DELETE/SELECT com `ParamByName` para todo valor; a listagem concatena só fragmentos constantes (`AND ATIVO = TRUE`, bloco de busca), e o texto do usuário entra como parâmetro `:BUSCA` com `%`, `_` e `\` escapados. Preço em `Currency`, nunca Double; `CK_PRODUTOS_PRECO` atua como 2ª barreira (regra 12). Sem SQL em Form, Service ou Dominio. Sem achado.

### 3. Log e dados sensíveis (regra 17)
O repositório só loga operação e exceção FireDAC via `TLogger.Erro` (mascaramento verificado no Lote 2); nenhum valor de parâmetro é logado. Produto não contém dado pessoal. Forms e Service não logam. Sem achado.

### 4. Mensagens ao usuário
Mensagens fixas e amigáveis. A lista usa `E.Message` só para `EErpVendas` e texto genérico para o resto. A edição trata `EValidacao` e deixa o restante subir para `Application.OnException` (mensagem genérica, lado seguro). **Achado 1 (baixa):** o repositório levanta `EInfra` em vez de `EInfraMensagemSegura` (mesmo padrão de RF4-02); já coberto por RF5-01. **Observação (informativa):** `Excluir` com 0 linhas afetadas não avisa; é integridade, não segurança; também em RF5-01.

### 5. Camadas ADR-001/010 e integração
`ProdutoService` usa só Core/Dominio/`Data.DB`; `Negocio` não referencia `Dados`. Forms dependem só de `TProdutoService`. `App.Root` monta repositório e serviço e libera na ordem correta (serviço, repositório, conexão). `FormMain` embute a lista sem lógica de dados. Sem achado.

### 6. Compliance (LGPD básica) e operacional
Sem dado pessoal em Produto; nada novo para LGPD. Nenhum requisito operacional novo para o chapéu DevOps. Nada de relevância estratégica para o Gestor.

### Veredito do lote (chapéu DevSecOps)
**Aprovado com débito baixo** (achado 1, já coberto por RF5-01; nenhuma tarefa nova). Sem achado alto/crítico nem compliance em aberto. Libera para `/deploy` quando o usuário decidir.

## Lote 6 — Vendas: dados e regras (D3)

Escopo: `ERPV.Dados.VendaRepository`, `ERPV.Negocio.VendaService`, `TClienteService.Excluir`/`TProdutoService.Excluir` (T30), `ERPV.App.Root` e as chamadas de `Excluir` em `FormListaClientes`/`FormListaProdutos`/`FormListaVendas`. QA do lote: Aprovado com ressalvas (RF6-01..RF6-03, não duplicados aqui). Análise por leitura de código (sem SAST automatizado disponível); sem recompilação.

### 1. Segredo/credencial no repositório
Nenhum segredo nas units do Lote 6. Sem achado.

### 2. SQL parametrizado e injeção (regra 11)
Todo valor entra por `ParamByName` (INSERT/UPDATE/DELETE/SELECT/existência). A única montagem dinâmica é `ListarDataSet` (T26): concatena apenas as constantes `SQL_LISTAR_STATUS`/`SQL_LISTAR_CLIENTE`/`SQL_LISTAR_ORDEM`, escolhidas por `<> ''`/`> 0`; o texto de `AStatusFiltro` entra só como `:STATUS` e o cliente como `:CLIENTE_ID` (inteiro). Sem ordenação ou coluna vinda do chamador. Sem injeção possível. Sem SQL em Service/UI. Valores monetários em `Currency`; `CK_VENDAS_STATUS` e `CK_ITENS_QTD` como 2ª barreira. Sem achado.

### 3. Integridade de estado (RF6-01)
Confirmado por leitura: em `TVendaService.Salvar` (Id > 0), `ExigirPendente` lê o status do banco (correto), mas `Alterar` grava `Status`, `DataQuitacao` e `MotivoCancelamento` do objeto do chamador (`PreencherMestre`/`SQL_ALTERAR`). Um chamador pode transitar Pendente -> Quitada/Cancelada por fora de `AtualizarStatus`/fluxo de quitação; o CHECK só valida o domínio do texto, não a transição. Consequência: contorna RN-02/RN-06 (efeitos da quitação/cancelamento, como fila de e-mail e data/motivo consistentes, ficam de fora) e pode deixar venda Quitada sem `DataQuitacao` ou Cancelada sem motivo. Achado correlato **RF6-04**: em `Incluir`, o `Status` é forçado a Pendente, mas `DataQuitacao`/`MotivoCancelamento` do chamador são gravados assim mesmo.
Classificação: **Média** (RF6-01) e **Baixa** (RF6-04). Justificativa: o serviço é o único ponto de entrada, hoje só a UI o consome e ela não expõe status na edição; app desktop monousuário, sem fronteira de confiança nem exploração externa; sem perda de dado sensível. Não é alta/crítica, então não bloqueia. Sobe para Alta se algum consumidor externo (importação, API, novo form) passar a montar `TVenda` a partir de entrada não confiável, ou se o Lote 9 (`QuitacaoService`) depender de a quitação ser exclusiva de `AtualizarStatus`. Correção (poucas linhas, no Service): em `Salvar`, copiar `Status/DataQuitacao/MotivoCancelamento` de `Atual` para `AVenda` antes de `Alterar`; em Id = 0, zerar `DataQuitacao` e `MotivoCancelamento`. Prazo: antes de iniciar o Lote 9 (T38).

### 4. Log e dados sensíveis (regra 17, LGPD)
O repositório só loga operação + exceção FireDAC via `TLogger.Erro` (mascara CPF/CNPJ/e-mail e redige senha, verificado na T10); nenhum valor de parâmetro vai ao log. A lista (T26) traz `CLIENTE_NOME` para a grade, mas nome não é logado nem entra em mensagem. Service não loga. Mensagens de validação incluem só a descrição do produto (dado não pessoal); não incluem nome, CPF/CNPJ ou e-mail do cliente. Os diálogos de confirmação de exclusão mostram nome/descrição só na tela do operador. Sem achado.

### 5. Mensagens ao usuário e EInfra
Mensagens do repositório são fixas e amigáveis, sem SQL, caminho ou credencial; o detalhe técnico vai só ao log. `ERegraNegocio`/`EValidacao` têm texto em português sem dado técnico. As três chamadas de `Excluir` na UI usam `E.Message` só para `EErpVendas` e `MSG_ERRO_GENERICO` para o resto (lado seguro). **Achado 2 (baixa):** o repositório levanta `EInfra` e não `EInfraMensagemSegura` (padrão RF4-02/RF5-01, RF6-02 do QA); já coberto, sem tarefa nova. Observação: `Excluir` de venda inexistente é silencioso (integridade, não segurança; RF6-02).

### 6. Camadas ADR-001/010 e Root
`VendaService`, `ClienteService` e `ProdutoService` usam só Core/Domínio/`Data.DB`; `Negocio` não referencia `Dados`. `ERPV.App.Root` cria `VendaRepository` antes dos serviços que o recebem e libera na ordem inversa antes da conexão. A UI só depende dos Services. Transação única mestre+itens. Sem achado.

### 7. Compliance (LGPD básica) e operacional
CPF/CNPJ/e-mail continuam mascarados em log e ausentes de mensagens. Nenhum requisito operacional novo para o chapéu DevOps. Nada de relevância estratégica para o Gestor; a observação de regra do QA (inativado depois da criação bloqueia editar venda Pendente) é decisão de negócio já sinalizada por ele, sem componente de segurança.

### Achados do lote

| # | Achado | Severidade | Situação |
|---|---|---|---|
| RF6-01 | `Salvar` em edição grava Status/DataQuitacao/Motivo do chamador (transição fora do fluxo de quitação) | Média | Débito com prazo: antes do Lote 9 (T38); tarefa em `Refatoração Lote-6` |
| RF6-04 | `Incluir` grava DataQuitacao/Motivo do chamador com Status forçado Pendente | Baixa | Débito, mesma correção e prazo de RF6-01 |
| Achado 2 | `EInfra` em vez de `EInfraMensagemSegura` | Baixa | Coberto por RF6-02; antes do Lote 16 |

### Veredito do lote (chapéu DevSecOps)
**Aprovado com débito** (RF6-01 média; RF6-04 e achado 2 baixos). Sem achado alto/crítico nem compliance obrigatório em aberto; sem risco de injeção; sem vazamento de dado sensível. Não bloqueia deploy. Pendente no fechamento estrutural: registrar RF6-01 e RF6-04 em `Refatoração Lote-6` com o prazo acima.

Escala para: nenhum (sem bloqueio). Gestor: sem relevância estratégica. Coordenador: não. Executor: correção de RF6-01/RF6-04 via `Refatoração Lote-6`, não imediata.

## Lote 7 — Vendas: telas (D3)

Escopo: `ERPV.UI.FormListaVendas` (T31), `ERPV.UI.FormEdicaoVenda` (T32) e a integração em `ERPV.UI.FormMain` (destino `dsVendas`). QA do lote: Aprovado com ressalvas (RF7-01..RF7-03, RF7-05; não duplicados aqui). Análise por leitura de código e busca textual (sem SAST automatizado; sem recompilação). Itens de T42 (`ERPV.UI.ConfirmacaoVenda`, botões Confirmar) são do Lote 9 e só citados.

### 1. Segredo/credencial no repositório
Nenhum segredo, string de conexão, caminho ou credencial nas duas units nem na integração do `FormMain`. Sem achado.

### 2. Forms sem SQL/HTTP/regra (GUARDRAILS, ADR-001/010)
Busca por `SELECT/INSERT/UPDATE/DELETE`, `.SQL`, `TFDQuery` e clientes HTTP = 0 nas duas telas. `uses` só de `Negocio` (Venda/Cliente/Produto/Quitação), Domínio e UI; nenhuma referência a `Dados`. A regra vive em `TVendaService`. O único cálculo na tela é prévia de exibição (qtd x preço do produto). Sem achado.

### 3. Dado de tela como fonte de verdade / integridade de estado
- `MontarVenda` preenche só `Id`, `ClienteId` e, por item, `ProdutoId` e `Quantidade`. Preço, subtotal e total não são enviados; após `Salvar` a tela relê por `Obter` e exibe o que o serviço calculou. Colunas Preço/Subtotal com `Editing := False` e `Focusing := False`; `Appending/Deleting/Inserting := False` na grade. Quantidade inteira 1..999999 no editor, revalidada pelo serviço.
- Status/DataQuitacao/Motivo: a tela não tem controle que os edite e `MontarVenda` não os atribui; o `TVenda` novo nasce com `Status = svPendente`, `DataQuitacao = 0`, `Motivo = ''` (construtor do domínio). Como `ExigirPendente` lê o status do banco e a edição só grava para Pendente, o caminho da UI é Pendente -> Pendente. **RF6-01/RF6-04 continuam latentes no serviço e não são exploráveis por estas telas**; a tela não os agrava nem mitiga. Mantêm o prazo já registrado (antes de T38); não são reabertos.
- Somente leitura (Quitada/Cancelada): `Validar` retorna False de imediato, Salvar oculto, controles desabilitados. A habilitação de Editar/Excluir na lista usa o status exibido na grade (dado de tela), mas é só conveniência: a barreira real é `ExigirPendente` no serviço. Sem achado.

### 4. Mensagens ao usuário (ADR-008, regra 17)
`E.Message` só é usado quando `E is EErpVendas` (lista: carga, filtro de clientes e Excluir) ou em `EValidacao`/`ERegraNegocio` (edição); qualquer outra exceção vira `MSG_ERRO_GENERICO`/`MSG_ERRO_LISTA`, sem SQL, caminho ou stack. Na edição, exceção diferente (ex.: `EInfra`) sobe ao handler global, mesmo padrão dos Lotes 4-6. Saída sempre por `Notificar` ou rótulos inline; sem `MessageDlg`/`ShowMessage`. Risco residual: `EErpVendas` inclui `EInfra` e o repositório usa `EInfra`, não `EInfraMensagemSegura`; os textos hoje são fixos e amigáveis (verificado no Lote 6), logo é o **achado 2 já registrado** (Baixa), sem tarefa nova. Mensagens de exclusão citam só o Nº da venda; nenhuma tem nome, CPF/CNPJ ou e-mail.

### 5. Log e vazamento (regra 17, LGPD)
Nenhuma das telas nem a integração chama `TLogger`, `OutputDebugString` ou `WriteLn`. Não há dado pessoal em log a partir da UI; o detalhe técnico de erro fica só no repositório (mascarado, T10). Sem achado.

### 6. Compliance (LGPD básica)
Nome do cliente aparece na coluna Cliente da lista e no filtro; nome e **CPF/CNPJ** aparecem no dropdown do lookup de cliente da edição (`ListColumns` NOME + CPF_CNPJ, sem máscara). É exibição ao operador do sistema, dentro da finalidade (identificar o cliente, distinguir homônimos), sem ir a log, mensagem ou terceiros: não é violação. **Achado 1 (Baixa, minimização):** o CPF/CNPJ completo no dropdown poderia ser mascarado para reduzir exposição por olhar de terceiros; decisão de UX/negócio, sem prazo obrigatório. E-mail não é exibido nestas telas.

### 7. Integridade de estado: duplo envio (Salvar/Excluir)
- **Salvar:** `Confirmar` -> `Validar` (chama `Salvar` síncrono) -> `mrOk`. VCL é single-thread e `Salvar` bloqueia a fila de mensagens, então um segundo clique/Enter só é tratado depois; em sucesso o form já fechou. Em falha de validação/regra, `FVendaId` não muda e nada é gravado. Em falha após gravar (ex.: `Obter` lançando), `FVendaId` já recebeu o Id real e um novo Salvar vira **alteração** da mesma venda, não duplicata. Transação única mestre+itens (Lote 6). Sem achado.
- **Excluir:** exige `Notificar(utnPergunta)` modal antes; após excluir, `Recarregar` refaz a seleção. Excluir repetido sobre o mesmo Id é silencioso no serviço (RF6-02, integridade, não segurança). Sem achado novo.
- T42 (fora do escopo): o helper desabilita controles durante a espera; a edição confirma a versão gravada (RF7-05 do QA), a validar no Lote 9.

### 8. Integração `FormMain`
`dsVendas` só cria a lista se `FVendaService <> nil`, libera a anterior antes, usa `FreeAndNil` e fecha por `PostMessage` (sem liberar o form dentro do próprio handler). Serviços são do Root e as telas não os liberam. Sem achado.

### Achados do lote

| # | Achado | Severidade | Situação |
|---|---|---|---|
| Achado 1 | CPF/CNPJ completo no dropdown de cliente da edição (sem máscara) | Baixa | Débito opcional (decisão de UX/negócio). Se aceito, `Refatoração Lote-7`, prazo antes do Lote 16 |
| Achado 2 (herdado) | `EInfra` vs `EInfraMensagemSegura` via `E.Message` em `EErpVendas` | Baixa | Coberto por RF6-02/RF4-02/RF5-01; antes do Lote 16 |
| RF6-01 / RF6-04 (herdado) | Transição de status/DataQuitacao/Motivo por `Salvar` | Média / Baixa | Não explorável pelas telas do Lote 7; prazo mantido: antes do Lote 9 (T38) |

### Veredito do lote (chapéu DevSecOps)
**Aprovado com débito baixo** (achado 1 novo; achado 2 e RF6-01/RF6-04 herdados). Sem achado alto/crítico nem compliance obrigatório em aberto; sem SQL/HTTP/regra nas telas; sem vazamento em log ou mensagem; dado de tela não é fonte de verdade; duplo envio não duplica venda. Não bloqueia deploy.

Escala para: nenhum (sem bloqueio). Gestor: sem relevância estratégica. Coordenador: não. Executor: nada imediato; RF6-01/RF6-04 seguem via `Refatoração Lote-6` antes de T38.


## Lote 8 — Cliente REST do Financeiro (D3)

Escopo: `ERPV.Integracao.FinanceiroDTOs` (T33), `ERPV.Integracao.FinanceiroClient` (T34-T36) e o ponto de uso em `ERPV.Negocio.QuitacaoService`/`ERPV.App.Root` (só segredos/log/mensagem). QA do lote: RF8-01/RF8-02 (não duplicados aqui). Análise por leitura de código (sem SAST automatizado disponível); sem recompilação. Referências: SDD §7, GUARDRAILS 16/17/18, ADR-004/006/007/008.

### 1. Segredo/credencial no repositório (regra 16, ADR-007)
Grep por `apikey|password|senha|secret|token = valor` em `src/`, INI e docs: nenhum valor literal; `ApiKey` só chega por `TConfiguracao` (env `ERPV_FINANCEIRO_APIKEY` com prioridade sobre o INI) e entra no `TFinanceiroClient.Create` pelo `Root`. Sem dependência de terceiros nova (só RTL: `System.Net.HttpClient`, `System.JSON`). Sem achado.

### 2. ApiKey, corpo e log (regra 17)
`X-Api-Key` vai só em cabeçalho, e só se `ApiKey <> ''`; nunca em URL, mensagem ou log. `MontarUrl` = BaseUrl + rota fixa + `IntToStr(id)`. O log grava apenas método, rota (com id numérico da venda), código HTTP e `E.ClassName` (sem URL/cabeçalho/corpo/`E.Message`); corpo de requisição e resposta não são logados. `TResultadoFinanceiro.Indisponivel`/`RespostaInvalida` têm texto fixo. Sem achado.

### 3. Transporte, redirect e timeouts
`HandleRedirects := False` (3xx vira Indisponível, sem seguir para host arbitrário nem reenviar a ApiKey); `ConnectionTimeout/SendTimeout/ResponseTimeout` = `TimeoutMs` (padrão positivo garantido em `Config`). Sem achado. **Observação SG8-04:** a BaseUrl não tem esquema validado; `http://localhost:8101` é aceitável só em dev/mock. Em produção, a ApiKey e o payload trafegariam em claro se a URL for `http://` remota. Não é achado de código; vira requisito operacional (seção 6).

### 4. Resposta não confiável (JSON malicioso/enorme, mensagem ao usuário)
- Parse tolerante: `ParseJSONValue` em try/except, raiz não-objeto descartada, campos desconhecidos ignorados, status por `TryStrToStatusVenda` (whitelist), `vendaId` via `StrToIntDef`. Sem execução de conteúdo e sem eco do corpo em `RespostaInvalida`. Corpo enorme: `ContentAsString` lê tudo em memória sem teto (app desktop, endpoint interno; timeout limita o tempo). Risco de DoS local baixo.
- **Exceção não capturada (RF8-01):** `TryIsoToDateTime` só captura `EConvertError`; qualquer outra exceção do `ISO8601ToDate` sobe por `AInterpretar` (fora do try de `Executar`), atravessa `Enviar`/`QuitacaoService` e chega ao `Application.OnException` (T11). Impacto de confidencialidade: **nenhum vazamento** — o tratador global mostra mensagem genérica e loga com mascaramento; a exceção não carrega dado sensível (só o texto de data do Financeiro). Impacto de robustez/integridade: um `dataQuitacao` malformado num 200 aborta `ConfirmarQuitacao` antes de `AtualizarStatus` e antes da fila/reconciliação (T40/T41): o Financeiro fica Quitada, o local Pendente e sem reenvio. Quebra a promessa "falha esperada vira resultado, nunca exceção" do cliente. Um Financeiro comprometido/defeituoso consegue disparar isso à vontade.
- **Mensagem do Financeiro exibida (SG8-02):** `ExtrairMensagem` devolve o texto do campo `mensagem` do 4xx sem limite de tamanho nem remoção de caracteres de controle, e `QuitacaoService` a repassa "íntegra" à UI (`'Quitação recusada pelo Financeiro: ' + Mensagem`). Sem injeção (texto vai a label/diálogo VCL, sem SQL/HTML/comando; não é gravado em banco nem log), mas uma mensagem gigante ou com quebras de linha/controle pode deformar o diálogo ou induzir o operador (texto arbitrário com aparência de instrução do sistema). Um Financeiro legítimo não devolve dado pessoal aí por contrato, mas nada impede.

### 5. LGPD/dado pessoal em payload
Quitação: `vendaId`, `clienteId` (id numérico), `valorTotal`, itens (`produtoId`, `quantidade`, `precoUnitario`) — sem nome, CPF/CNPJ, e-mail ou endereço; bate com o contrato v1.0 (minimização OK). Cancelamento: `vendaId` + `motivo` (texto livre do operador, já exigido pelo contrato/RN); **SG8-03 (baixa):** o campo livre pode receber dado pessoal digitado pelo operador e é enviado ao Financeiro sem filtro — aceitável para o contrato, mas a UI de cancelamento (Lote 9+) deve orientar a não inserir CPF/e-mail. Log: nada disso é logado. Compliance obrigatório: sem pendência.

### 6. Requisitos de segurança operacional para o chapéu DevOps
Produção: BaseUrl com `https://` e certificado válido (validar contra o cert, sem desabilitar verificação); `ERPV_FINANCEIRO_APIKEY` só por variável de ambiente/secret, INI sem a chave; mock (`tools/mock-financeiro`, http) só em dev/staging local, fora do pacote de release.

### Achados do lote

| # | Achado | Severidade | Situação |
|---|---|---|---|
| SG8-01 (= RF8-01) | `TryIsoToDateTime` captura só `EConvertError`; exceção escapa do cliente e deixa venda Pendente sem fila/reconciliação. Sem vazamento de dado | Média (robustez/integridade; segurança: baixa) | Débito com prazo: antes do fechamento do Lote 9 (T38-T41); mesma correção do QA (`except on Exception`, ou capturar em `Enviar` ao redor de `AInterpretar` devolvendo `RespostaInvalida`); tarefa em `Refatoração Lote-8` |
| SG8-02 | Mensagem 4xx do Financeiro sem limite/sanitização, exibida ao operador | Baixa | Débito: truncar (ex.: 200 chars) e trocar controles/quebras por espaço em `ExtrairMensagem`; prazo antes do Lote 16 |
| SG8-03 | `motivo` de cancelamento livre pode carregar dado pessoal digitado | Baixa | Débito/orientação de UI no Lote 9+; sem código no Lote 8 |
| SG8-04 | BaseUrl sem exigência de https (http local só dev) | Baixa (observação) | Requisito de DevOps (seção 6); opcional: aviso no log se `http://` e host não-local |

### Veredito do lote (chapéu DevSecOps)
**Aprovado com débito** (SG8-01 média; SG8-02..04 baixos). Sem achado alto/crítico nem compliance obrigatório em aberto; ApiKey e corpos fora de log/URL/mensagem, redirects desligados, timeouts aplicados, payload minimizado. Não bloqueia deploy. Pendente no fechamento estrutural: registrar SG8-01 (junto com RF8-01) e SG8-02 em `Refatoração Lote-8` com os prazos acima. Nota: sobe para Alta se o SG8-01 deixar de ser tratado antes de a quitação ir a produção com Financeiro real, pelo risco de divergência de estado entre sistemas.

Escala para: nenhum (sem bloqueio). Gestor: sem relevância estratégica. Coordenador: não. Executor: correção de SG8-01/SG8-02 via `Refatoração Lote-8`, não imediata.

## Lote 10 — Cancelamento de venda (D4)

Escopo: `ERPV.Negocio.QuitacaoService` (T43, `Cancelar`), `ERPV.UI.FormCancelamentoVenda` (T44) e a integração em `FormListaVendas`/`FormEdicaoVenda`; caminho até `FinanceiroClient.ConfirmarCancelamento`, `VendaRepository.AtualizarStatus` e `FilaRepository.Enfileirar` lido só para rastrear o motivo. QA do lote: RF10-01..05 (não duplicados). Análise **estática por leitura** (sem SAST automatizado, sem Delphi, nada executado). Referências: SDD §7, GUARDRAILS 16/17/18, ADR-005/006/007/008, LGPD.

### 1. Segredo/credencial e dependências (regra 16, ADR-007)
Nenhum segredo literal nas units do lote; `ApiKey` só entra no `TFinanceiroClient` pelo `Root` (env sobre INI), como no Lote 8. Sem dependência de terceiros nova (UI usa só VCL/DevExpress já existentes). Sem achado.

### 2. Autorização e integridade do fluxo (RN-02, ADR-005/006)
Status lido do banco e checado antes de qualquer POST (Quitada/Cancelada/inexistente => `dcNaoPermitida`, sem HTTP); a UI só habilita o botão/menu como conveniência e o service revalida (a UI não é o controle). `AVendaId` é inteiro (sem injeção; rota = `IntToStr`); gravação por parâmetros nomeados (`:MOTIVO`, `:ID`), sem concatenação SQL. HTTP fora de transação. Motivo aparado e limitado a 255 na UI (`MaxLength`), coluna VARCHAR(255). Observação: o service em si não trunca o motivo (limite só na UI); um chamador futuro poderia estourar a coluna, resultando em `EInfra` (ver SG10-01). Sem achado de segurança.

### 3. Motivo livre e LGPD (SG8-03, RF10-03)
- **Fluxo do motivo:** digitado no `TcxTextEdit` => `Trim` => POST ao Financeiro (`motivo` no corpo, HTTPS obrigatório em produção, seção 6) => em sucesso gravado em `VENDAS.MOTIVO_CANCELAMENTO` (dado pessoal potencial persistido localmente, mesma finalidade do Financeiro). Não vai para log (nenhuma chamada a `Logger` em `QuitacaoService` nem em `FormCancelamentoVenda`; o `FinanceiroClient` loga só método, rota, código HTTP e `E.ClassName`), não vai para `ULTIMO_ERRO` da fila (recebe `Resp.Mensagem`, texto fixo do cliente para indisponível) e não aparece em mensagem de UI (a UI mostra id da venda e textos fixos; em `dcRecusada` mostra a `Mensagem` do Financeiro, ver SG10-03). Confirmado por leitura: **ausência de log do motivo está correta**.
- **Orientação ao operador:** ausente (RF10-03). É a pendência prometida em SG8-03: campo livre pode receber CPF/e-mail/telefone/dado de saúde do cliente digitado, e a base legal/minimização (LGPD art. 6º III, necessidade) depende de orientação e, idealmente, de limite de uso. Ainda sem validação de conteúdo. Severidade Baixa (dado voluntário, finalidade legítima, canal HTTPS, sem exposição em log), mas é **item de compliance de minimização não implementado**; não é "compliance obrigatório" bloqueante porque o SDD §7/RN não exige filtro e o tratamento tem base contratual/legítimo interesse; vira tarefa com prazo.
- **Retenção:** motivo fica por tempo indeterminado em `VENDAS`; sem política de retenção/anonimização no SDD. Nota para o Gestor (SG10-02), não bloqueia.
- **Perda do motivo na fila (RF10-02):** sem vazamento; risco inverso (dado não persistido). Nota de segurança: se T50 decidir guardar o motivo na fila/venda para reenvio, o mesmo tratamento LGPD (sem log, orientação) vale para a nova coluna.

### 4. Exposição de dado sensível em mensagens/exceções (RF10-01)
`EInfra` que escapa em `Cancelar` (`:297`, `:307`) chega a `FormCancelamentoVenda.Validar`, que exibe `E.Message` com `Notificar(utnErro)` quando `E is EErpVendas`. Verificado na origem: todos os `EInfra.Create` do `VendaRepository`/`FilaRepository`/`Conexao` usam constantes de mensagem fixas e amigáveis (`MSG_FALHA_GRAVAR`, `MSG_NAO_ENCONTRADA`, `MSG_FALHA_TRANSACAO`...), e o detalhe técnico (E original) vai só para `FLogger.Erro` com mascaramento (`TratarFalha`). Portanto **não há vazamento de SQL, caminho, credencial nem do motivo**; a "mensagem técnica" é só texto genérico e o impacto é de UX/integridade (RF10-01), não de confidencialidade. Exceção não-`EErpVendas` recebe texto genérico (`:165`) e o log fica com o tratador global (T13). Ressalva: como `Validar` não loga, e o texto do log depende de `TLogger` mascarar; o mascaramento existe (`ERPV.Core.Log`, CPF/CNPJ/e-mail/senha/apikey). Sem achado de confidencialidade. Integridade: a possibilidade de o operador repetir o POST após o Financeiro já ter cancelado é risco de divergência de estado (mesma classe de SG8-01); tratada por RF10-01.

### 5. ApiKey, corpo e log (regra 17)
Sem mudança no cliente neste lote. `ConfirmarCancelamento` reutiliza `Enviar`: `X-Api-Key` só em cabeçalho, corpo (com o `motivo`) nunca logado, log = método/rota/HTTP/`ClassName`. O log inclui `ARota`, que contém `vendaId` numérico (identificador, não dado pessoal). Sem achado.

### 6. Requisitos de segurança operacional para o chapéu DevOps
Idênticos ao Lote 8 e reforçados: `https://` com certificado válido em produção (o `motivo` pode conter dado pessoal e trafega no corpo); ApiKey só por variável de ambiente; log da aplicação sem corpo de requisição/resposta (manter assim ao configurar níveis de log de produção); backup do Firebird tratado como dado pessoal (contém `MOTIVO_CANCELAMENTO`).

### Achados do lote

| # | Achado | Severidade | Situação |
|---|---|---|---|
| SG10-01 (= RF10-01) | `EInfra` escapa de `Cancelar` (`AtualizarStatus`/`Enfileirar`); sem vazamento (mensagens fixas), mas permite repetir POST e divergir de estado com o Financeiro; o service também não trunca o motivo a 255 (só a UI) | Média (robustez/integridade; segurança: baixa) | Débito com prazo: antes do fechamento do Lote 11 / antes de T50 (reenvio); mesma correção do QA (capturar `EInfra`, desfecho "cancelado no Financeiro, falha ao gravar local"; aparar `Copy(Motivo,1,255)` no service); tarefa em `Refatoração Lote-10` |
| SG10-02 | `MOTIVO_CANCELAMENTO` retido indefinidamente, sem política de retenção/anonimização | Baixa (observação) | Sinalizado ao Gestor (decisão de negócio/LGPD); sem código |
| SG10-03 | Mensagem 4xx do Financeiro exibida em `dcRecusada` sem limite/sanitização (continuação de SG8-02) e pode ecoar o `motivo` que o Financeiro devolver | Baixa | Débito: mesma correção de SG8-02 em `ExtrairMensagem` (truncar e limpar controles); prazo antes do Lote 16 |
| SG10-04 (= RF10-03, SG8-03) | Diálogo não orienta a não digitar dado pessoal no motivo | Baixa (minimização LGPD) | Débito com prazo: hint curto "Não informe dados pessoais" em `FormCancelamentoVenda`; antes do Lote 16; tarefa em `Refatoração Lote-10` |

RF10-02, RF10-04 e RF10-05: sem implicação de segurança adicional além do registrado acima (RF10-02 ver seção 3).

### Veredito do lote (chapéu DevSecOps)
**Aprovado com débito** (SG10-01 média; SG10-02..04 baixos). Sem achado alto/crítico e sem compliance obrigatório em aberto: motivo não vai a log, fila ou mensagem; mensagens de exceção são fixas; SQL parametrizado; autorização revalidada no service antes do POST; ApiKey/corpo fora de log. Não bloqueia deploy. Pendente no fechamento estrutural: registrar SG10-01 e SG10-04 (e SG10-03 junto a SG8-02) em `Refatoração Lote-10` com os prazos acima. Nota: SG10-01 sobe para Alta se a divergência de estado com o Financeiro puder ocorrer em produção sem reconciliação (T50 ausente) com Financeiro real. Evidência apenas estática (nada compilado/executado).

Escala para: nenhum (sem bloqueio). Gestor: apenas SG10-02 (retenção/anonimização do motivo), informativo e em paralelo. Coordenador: não. Executor: correção de SG10-01/SG10-04 via `Refatoração Lote-10`, não imediata.

### Revalidação (2026-09-23)

Delta do Lote 10 após a correção do BOM: o único diff em `src` desde a auditoria é a inserção de EF BB BF na linha 1 de `QuitacaoService.pas` (e das units do Bloqueio 005), sem mudança de lógica. Sem código novo, a superfície de segurança não mudou: SG10-01 (média) e SG10-02..04 (baixas) continuam válidos, sem alteração de severidade nem de prazo. Nenhum achado novo.

**Veredito DevSecOps: APROVADO COM DÉBITO (inalterado).** Não bloqueia deploy. Evidência apenas estática (nada compilado/executado).

## Lote 9 — Fluxo Confirmar venda (T37-T42) — chapéu DevSecOps

Escopo: `ERPV.Dados.FilaRepository` (T37), `ERPV.Negocio.QuitacaoService.Confirmar` (T38-T41), `ERPV.UI.ConfirmacaoVenda` (T42) e chamadas em `FormListaVendas`/`FormEdicaoVenda`; `ERPV.App.Root` só para segredo. Análise **estática por leitura** (sem SAST automatizado, sem Delphi, nada executado). SG8-01(=RF8-01)/SG8-02/SG8-03 já registrados no Lote 8, referenciados e não duplicados. Referências: SDD §7, GUARDRAILS 16/17/18, ADR-005/006/007/008, LGPD.

### 1. Segredo/credencial e dependências (regra 16, ADR-007)
Nenhum segredo literal nas units do lote. `Root` só repassa `FConfiguracao.Financeiro.ApiKey` ao `TFinanceiroClient` (env sobre INI, Lote 8). Sem dependência nova. Sem achado.

### 2. FilaRepository (T37): SQL, transação, ULTIMO_ERRO
- SQL 100% parametrizado (`:VENDA_ID`, `:TIPO`, `:ERRO`, `:ID`); constantes fixas, sem concatenação de entrada. `Listar` só concatena constantes. Sem injeção.
- Transação curta e só iniciada se o chamador não abriu; `Desfazer` em falha; `Q.Free` em `finally`. Falha vira `EInfra` com texto fixo (`MSG_FALHA_GRAVAR/CONSULTAR`); o detalhe vai só a `FLogger.Erro` (com máscara de `TLogger`). Sem SQL/caminho na mensagem.
- `ULTIMO_ERRO` truncado a 500 (`Copy`, VARCHAR(500)); **não mascarado no repositório**. Origem rastreada: `EnfileirarIndisponivel` grava `Resp.Mensagem` de `rfIndisponivel`, que no cliente é **texto fixo** ("Financeiro indisponivel (...)" / "... código HTTP n"), nunca corpo do Financeiro; a mensagem 4xx (única vinda do Financeiro) **não é enfileirada** (RN-08). Logo, hoje **nenhum dado do Financeiro nem dado pessoal chega a `ULTIMO_ERRO`**; minimização LGPD atendida. Ver SG9-05: a proteção é acidental (depende do contrato do cliente), não do repositório.
- Unicidade PENDENTE por venda+tipo feita por SELECT+UPDATE/INSERT na mesma transação (app monousuário desktop, ADR-005); sem corrida realista.

### 3. QuitacaoService.Confirmar (T38-T41)
- Status lido do banco e exigido Pendente **antes** do POST; `Venda.Free` antes de qualquer trabalho posterior; HTTP sem transação aberta (ADR-006); `AtualizarStatus` em commit curto. Reconciliação por GET só em `rfIndisponivel`, sem novo POST e sem fila quando Quitada. OK.
- Sem log e sem dado pessoal no service; mensagens de `ERegraNegocio` fixas (só o status por `StatusVendaToStr`).
- `EnfileirarIndisponivel` captura `EInfra` e anexa `E.Message` (texto fixo amigável) à mensagem, sem vazamento; o "Aviso: ..." não aparece na UI (a UI usa texto fixo em `qdIndisponivel`).
- **Integridade (Financeiro quitou, local falha):** `AtualizarStatus` (`:208`, `:241`) não é protegido: `EInfra` ali escapa **depois** do 200 Quitada, deixando o local Pendente **sem fila** e sem reconciliação (mesma classe de RF8-01/SG10-01; ver SG9-01).
- **RF8-01/SG8-01 (avaliação com o fluxo real):** o defeito segue no código (`TryIsoToDateTime` só captura `EConvertError`, `FinanceiroDTOs.pas:132`). Efeito no Confirmar: a exceção sai de `ConfirmarQuitacao`, antes de `AtualizarStatus`, fila e reconciliação; a UI relança e o handler global mostra mensagem genérica (sem vazamento). Severidade **real: Média** (não Alta): (a) só dispara com `dataQuitacao` malformado num 200, fora do contrato, e `ISO8601ToDate` lança `EConvertError` para formato/valor inválido na prática, então o tipo não capturado é raro; (b) nada é perdido nem exposto: o operador vê erro, a venda segue Pendente e pode repetir (idempotência RN-06/C3 assumida do contrato); (c) exige Financeiro defeituoso/comprometido, sem escalada de privilégio. Não bloqueia o Lote 9, mas **permanece débito vencido** (prazo do Lote 8 = antes do fechamento do Lote 9): corrigir antes de produção com Financeiro real.

### 4. UI (T42): mensagens e concorrência
- `TextoDesfechoQuitacao` usa textos fixos, exceto `qdRecusado`, que concatena `AResultado.Mensagem` (4xx do Financeiro): **SG8-02 persiste** (sem limite/sanitização; ver RF8-03, não duplicado). Sem SQL/caminho/stack/exceção nas mensagens; exceções relançadas ao handler global (texto genérico + log mascarado). `qdRespostaInvalida` não ecoa corpo.
- Duplo clique/reentrância: pergunta Sim/Não antes de qualquer POST; controles listados desabilitados durante a espera e restaurados em `finally` (também com exceção); chamada síncrona, sem pump de mensagens durante o HTTP, então cliques ficam enfileirados. Cliques enfileirados podem ser entregues depois do `finally`, mas cada novo `Confirmar` exige nova confirmação e o service relê o status (Quitada => `ERegraNegocio`, sem POST; Pendente após falha => novo pedido consciente; a fila não duplica). **Sem POST duplicado silencioso**; risco residual só de UX (SG9-04).

### 5. Bloqueio de edição com fila pendente (T53, aceito)
Não implementado neste lote (aceito). Nota de integridade: como SG9-01/RF8-01 deixam a venda Pendente **sem** item na fila, T53 **não** protege esse cenário: a venda quitada no Financeiro continuaria editável/excluível localmente. A correção deve criar registro de pendência (ou reconciliar), não depender só de T53.

### 6. Compliance (LGPD básica) e operacional
Sem dado pessoal em log, fila (`ULTIMO_ERRO`), mensagem de UI ou exceção; payload de quitação minimizado (Lote 8). Sem compliance obrigatório em aberto. DevOps (Lote 16): sem mudança (https, ApiKey por env, log sem corpo, backup do Firebird como dado pessoal).

### Achados do lote

| # | Achado | Severidade | Situação |
|---|---|---|---|
| SG9-01 | `AtualizarStatus` sem proteção em `Confirmar` (`:208`, `:241`): `EInfra` após o Financeiro quitar deixa o local Pendente, sem fila e sem reconciliação; operador vê erro genérico. Sem vazamento | Média (integridade; segurança: baixa) | Débito com prazo: antes do Lote 11/T50 e antes de produção; capturar `EInfra` ao gravar, enfileirar/registrar pendência e devolver desfecho tipado; junto de SG10-01 (mesmo padrão em `Cancelar`); tarefa em `Refatoração Lote-9` |
| SG9-02 (= RF8-01/SG8-01, reavaliado) | Exceção de parse de data escapa de `ConfirmarQuitacao`: Financeiro Quitada, local Pendente sem fila | Média (confirmada; não sobe a Alta: fora do contrato, sem perda nem vazamento) | Débito **vencido**; corrigir antes de uso com Financeiro real; sobe a Alta/bloqueante se chegar a produção sem correção |
| SG9-03 (= SG8-02, RF8-03) | Mensagem 4xx exibida em `qdRecusado` sem limite/sanitização | Baixa | Referência ao Lote 8; sem tarefa nova; prazo antes do Lote 16 |
| SG9-04 | Cliques enfileirados durante a espera síncrona podem reabrir a pergunta depois do `finally` | Baixa (UX) | Débito opcional: flag de reentrância no fluxo ou descarte de mensagens pendentes; sem POST silencioso |
| SG9-05 | `ULTIMO_ERRO` sem máscara no repositório: hoje só recebe texto fixo, mas T50 gravando mensagem/corpo do Financeiro exporia dado no banco | Baixa (observação) | Débito preventivo: máscara de `ERPV.Core.Log` em `TruncarErro`/`Enfileirar`, revisar quando T50 entrar |

### Veredito do lote (chapéu DevSecOps)
**Aprovado com débito** (SG9-01 e SG9-02 médios; SG9-03..05 baixos). Sem achado alto/crítico e sem compliance obrigatório em aberto: SQL parametrizado, transação curta, HTTP fora de transação, status lido do banco, `ULTIMO_ERRO` só com texto fixo (LGPD/minimização OK), mensagens sem SQL/caminho/exceção, ApiKey fora de log/URL/mensagem. RF8-01 no fluxo real: **Média, não bloqueante**, mas débito vencido e agravado por SG9-01 (dois caminhos de "Financeiro Quitada, local Pendente sem fila", não cobertos por T53). Não bloqueia deploy. Pendente no fechamento estrutural: registrar SG9-01 (com RF8-01 e SG10-01) e SG9-04/05 em `Refatoração Lote-9`. Evidência apenas estática (nada compilado/executado).

Escala para: nenhum (sem bloqueio). Gestor: nenhum item novo (vira relevância estratégica só se SG9-01/SG9-02 forem a produção sem correção). Coordenador: não. Executor: correção de SG9-01/SG9-02 via `Refatoração Lote-8/9`, prioritária antes do Lote 11/T50; SG9-04/05 não imediatos.

## Lote 11 — Relatório e PDF (T45, T46, T47) — chapéu DevSecOps (2026-09-24)

Escopo: `ERPV.Dados.VendaRepository` (`SQL_RELATORIO`, `RelatorioDataSet`, `:104-112`, `:456-477`), `ERPV.Relatorios.RelatorioPedido` (T47), `ERPV.Relatorios.PedidoLayout.pas/.dfm` (T46), `IRelatorioPedido`, montagem em `ERPV.App.Root` (`:223`), `config/erpvendas.ini.example` (`[Relatorio] PastaPdfTemp`) e leitura em `ERPV.Core.Config:259`. QA do lote (A11-01..06, R11-1) não duplicado. Análise **estática por leitura** (sem SAST automatizado, sem Delphi, nada executado). Referências: SDD §7, GUARDRAILS 16/17/18, ADR-007/008, LGPD.

### 1. SQL (injeção)
`SQL_RELATORIO` é constante; único valor variável é `:ID` (`AsInteger`, `:464`). Sem concatenação de entrada; dataset com `ReadOnly`. Falha em `RelatorioDataSet` libera a query e vira `EInfra` de texto fixo (log mascarado). Sem achado (A11-04 é só rótulo de log).

### 2. Path traversal / escape em `Limpar` (`RelatorioPedido.pas:67-74, 116-127`)
`DentroDaPastaTemp` usa `ExpandFileName` (resolve `..`) e prefixo com delimitador final, logo `..\` e `temp2` não escapam; só apaga arquivo existente; fora da pasta gera aviso e não apaga. O nome do PDF é gerado internamente (`Pedido_<Id inteiro>_<timestamp>`), sem entrada de usuário, então não há traversal na geração. Residuais: symlink/junction não resolvidos (A11-06) e `PastaPdfTemp` relativa resolvida contra o diretório corrente (SG11-05). Sem achado alto.

### 3. PDF com dado pessoal em pasta temp (LGPD)
- Conteúdo: nome, CPF/CNPJ (completo), e-mail do cliente + itens/valores. Finalidade legítima (confirmação enviada ao próprio cliente, RF-20); a minimização é aceitável, mas CPF/CNPJ vai completo (SG11-06, observação).
- Ciclo de vida: PDF só é removido se o chamador chamar `Limpar`. Se `Print` falhar após criar arquivo parcial (A11-02) ou o processo cair/o fluxo de e-mail não chegar a `Limpar`, o arquivo com PII **fica na pasta indefinidamente**; não há varredura de arquivos antigos na inicialização (SG11-01).
- Permissões: o exemplo aponta `C:\ERPVendas\temp\pdf`; `ForceDirectories` herda a ACL da raiz `C:\`, que por padrão dá leitura a outros usuários autenticados da máquina; o código não restringe a ACL (SG11-02). Em estação monousuário o risco é reduzido.
- Nome previsível (A11-03): `Pedido_<Id>_<yyyymmddhhnnsszzz>` é adivinhável com Id sequencial; só importa combinado com ACL frouxa (SG11-02).

### 4. Vazamento de caminho/SQL em mensagens e logs
Mensagem ao usuário é `MSG_FALHA_PDF` fixa (sem caminho/SQL). `FLogger.Erro` recebe `AVenda.Id` (inteiro) e a exceção original, que passa pelo mascaramento de `ERPV.Core.Log` (CPF/CNPJ/e-mail/senha/apikey). `Limpar` loga o caminho completo no aviso (`:126`); o nome só contém Id e timestamp (sem PII), caminho é local; aceitável, sem achado. Nenhum dado do cliente entra em log.

### 5. Layout .dfm, segredos e dependência
`mtPedido` sem linhas (`Data` ausente): nenhum dado real/PII no .dfm; `Active = True` sem efeito de dado. Sem segredo literal em nenhuma unit/INI do lote (o INI example só tem caminho). ReportBuilder: componente licenciado já existente (T67); faixa "Demo Copy" do trial é questão de licenciamento/produto (deve sair antes do deploy de produção — nota ao DevOps/Gestor), não vulnerabilidade. Domínio (`IRelatorioPedido`) sem ReportBuilder/FireDAC (ADR-001/010). Sem criptografia/senha no PDF (não exigida no SDD §7).

### 6. Requisitos de segurança operacional para o chapéu DevOps
Criar `PastaPdfTemp` com ACL restrita ao usuário da aplicação (remover herança de "Users/Authenticated Users"), fora de pasta sincronizada/backup (OneDrive, backup do Firebird não deve incluí-la); antivírus/indexação sem exposição da pasta; remover a faixa "Demo Copy" (licença ReportBuilder) antes de produção; backup tratando a pasta como dado pessoal.

### Achados do lote

| # | Achado | Severidade | Situação |
|---|---|---|---|
| SG11-01 (= A11-02 + retenção) | PDF com PII (nome, CPF/CNPJ, e-mail) pode ficar órfão em `PastaPdfTemp` (falha de `Print` em `RelatorioPedido.pas:76-113`, falha de e-mail, queda do app); sem varredura de arquivos antigos | Média (LGPD retenção/minimização) | Débito com prazo: limpar arquivo parcial no `except` de `GerarPdf` + varrer `Pedido_*.pdf` com mais de N horas na inicialização (ou em `Create`); junto de A11-02; tarefa em `Refatoração Lote-11`, antes do smoke T54 |
| SG11-02 (= A11-03) | ACL da pasta herdada e nome previsível (`Pedido_<Id>_<ms>`) permitem a outro usuário local ler/adivinhar PDFs | Baixa (média se estação multiusuário/compartilhada) | Débito: sufixo aleatório (GUID) no nome e, se viável, ACL restrita na criação; requisito operacional ao DevOps; `Refatoração Lote-11` |
| SG11-03 (= A11-06) | `Limpar` não resolve symlink/junction (só prefixo textual) | Baixa (documental) | Registrar limitação; sem correção obrigatória |
| SG11-04 | `PastaPdfTemp` sem validação (relativa, UNC/rede, raiz de unidade); `ForceDirectories` cria o que vier do INI (configuração confiável, controlada por administrador) | Baixa | Débito: exigir caminho absoluto local em `ERPV.Core.Config`; `Refatoração Lote-11` |
| SG11-05 | CPF/CNPJ impresso completo no PDF (minimização, LGPD art. 6º III) | Baixa (observação) | Sinalizar; decisão de conteúdo é do produto/Gestor (o PDF vai ao próprio titular); sem código obrigatório |
| SG11-06 (= A11-01) | `AVenda`/dependências nil geram AV bruta (mensagem do sistema, possivelmente com endereço) em vez de `EInfra` | Baixa | Junto de A11-01; `Refatoração Lote-11` |

A11-04/A11-05/R11-1: sem implicação de segurança adicional.

### Veredito do lote (chapéu DevSecOps)
**Aprovado com débito** (SG11-01 média; SG11-02..06 baixos). Sem achado alto/crítico e sem compliance obrigatório em aberto: SQL parametrizado e somente leitura, `Limpar` confinado à pasta temp, mensagens fixas sem caminho/SQL, log mascarado, sem PII/segredo no .dfm/INI. Não bloqueia deploy. SG11-01 sobe para Alta se, em produção, a pasta ficar em local compartilhado/legível por outros usuários sem limpeza. Pendente no fechamento estrutural: registrar SG11-01, 02, 04 e 06 (com A11-01/02/03) em `Refatoração Lote-11`. Evidência apenas estática (nada compilado/executado).

Escala para: nenhum (sem bloqueio). Gestor: SG11-05 (conteúdo do PDF/máscara do CPF) e licença ReportBuilder antes de produção, informativos e em paralelo. Coordenador: não. Executor: correção via `Refatoração Lote-11`, não imediata. DevOps: requisitos da seção 6.

---

## Lote 12 — E-mail pós-quitação (T48, T49) — chapéu DevSecOps (2026-09-24)

Escopo: `ERPV.Integracao.EmailSender` (T48), `TQuitacaoService.PosQuitacao` (T49, `QuitacaoService.pas:231-304`), `TextoDesfechoQuitacao` (`ERPV.UI.ConfirmacaoVenda.pas:88-102`), `ERPV.Core.Config` (`[SMTP]`, `:251-256`), `FilaRepository` (ULTIMO_ERRO), `EmailValido` (`ERPV.Core.Validadores`). QA do lote (Aprovado com ressalvas) não duplicado. Análise estática manual (sem SAST automatizado no ambiente; Delphi não compila via CLI).

### 1. TLS/SMTP (`EmailSender.pas:164-186`)
- `TIdSSLIOHandlerSocketOpenSSL` é criado sem `SSLOptions.VerifyMode`/`VerifyDepth`/`OnVerifyPeer`/`RootCertFile`: o padrão do Indy é **não verificar** a cadeia nem o hostname. O canal é cifrado, mas qualquer MITM na rota apresenta certificado próprio e a sessão segue (SG12-01).
- `UseTLS := utUseExplicitTLS` é **oportunista** no Indy: se o servidor não anuncia (ou um atacante remove) `STARTTLS`, a sessão continua em texto claro e o `AUTH` (usuário/senha) e o PDF com PII trafegam sem cifra. O modo estrito é `utUseRequireTLS` (SG12-01).
- Contexto: no Mailtrap sandbox (dados fictícios, credencial descartável) o risco é aceitável. Em produção (SMTP real, credencial de conta, PDF com nome/CPF/CNPJ/e-mail do cliente) o vetor vira exposição de credencial + dado pessoal em trânsito; LGPD art. 46 (medidas técnicas). Por isso é Média agora, com **condição de correção antes do primeiro deploy em produção**.
- `sslvTLSv1_2` fixo (sem fallback a SSL3/TLS1.0): correto. Timeouts 15 s/30 s definidos: ok.
- DLLs OpenSSL 1.0.2 (spike T02) estão fora de suporte desde 2019 (SG12-02).

### 2. Credenciais
`Senha` vem de `ERPV_SMTP_PASSWORD` (prioridade) ou INI (fallback texto claro, aceito no ADR-007). Nunca é logada: `LogErro` grava só mensagem fixa + `ClassName`; `LogInfo` sem parâmetros; a mensagem crua de Indy não é usada em lugar algum. Sem segredo literal em unit/INI example. Sem achado; recomenda-se em produção usar só a variável de ambiente (seção 8).

### 3. Erro do SMTP ao usuário
`Enviar` devolve apenas constantes (`MSG_CREDENCIAL`, `MSG_REJEITADO`, `MSG_SSL`, `MSG_CONEXAO`, `MSG_GENERICA`); nenhuma resposta do servidor, host, usuário ou código vaza. A UI (`TextoDesfechoQuitacao`) mostra texto fixo e, no sucesso, o endereço do próprio cliente ao operador (finalidade legítima). Sem achado.

### 4. PII na fila e no log
`PosQuitacao` grava em `ULTIMO_ERRO` só: constantes de `EmailSender`, `'Cliente sem e-mail cadastrado'`, `'Venda não encontrada...'` ou `'Falha ao gerar/enviar e-mail: ' + E.ClassName`; nunca o destinatário nem `E.Message`. Além disso `FilaRepository` mascara (`TLogger.MascararSensiveis`) e trunca a `MAX_ERRO`. Nenhum log do `EmailSender` traz e-mail/CPF. Sem achado. Observação: se `Enfileirar` falha, o `except` de `PosQuitacao` (`:298-302`) engole sem registrar nada (SG12-06).

### 5. Injeção de cabeçalho / CRLF
Assunto e corpo são montados só com `AVendaId` (inteiro) via `Format`: não há entrada de usuário em `Subject`/corpo. O destinatário vem de `Cliente.Email` do banco; a entrada é validada em `ClienteService`/`FormEdicaoCliente` por `EmailValido`, que rejeita qualquer caractere `<= ' '` (inclui CR/LF/TAB), vírgula e ponto e vírgula, e mais de um `@`. Portanto CRLF/múltiplos destinatários não passam pelo caminho normal. Lacuna: `TEmailSender.Enviar` só faz `Trim` e checa vazio, sem revalidar; dado legado/importado/gravado direto no banco chegaria a `Recipients.EmailAddresses` (Indy interpreta vírgula como lista de destinatários; risco de envio do PDF a terceiros) (SG12-03). O anexo é caminho gerado internamente (`Pedido_<Id>_<ts>.pdf`), sem entrada de usuário.

### 6. PDF com PII na pasta temp durante o envio
Ciclo: `GerarPdf` -> `Enviar` (síncrono, até ~15 s de conexão + 30 s de leitura) -> `Limpar` no mesmo `PosQuitacao`, em sucesso e em falha e mesmo com exceção (o `Limpar` fica fora do `try/except`, `:286-292`). O `TIdAttachmentFile` é liberado com `LMsg` no `finally` de `Enviar`, antes do `Limpar`, então não há handle preso impedindo a exclusão. A janela de exposição existe (PDF legível por segundos, até ~45 s em servidor lento) e o resíduo em queda do processo continua coberto por SG11-01/SG11-02 (sem varredura na inicialização, ACL herdada, nome previsível); não é achado novo, mas SG11-01/02 agora têm caminho real de ocorrência (T49 ativo) e o prazo deve ser respeitado (SG12-04).

### 7. Compliance (LGPD)
Finalidade: envio da confirmação ao próprio titular (RF-21), base contratual; minimização: assunto/corpo sem PII, PDF com CPF/CNPJ completo (SG11-05 já sinalizado). Trânsito: ver SG12-01. Terceiro: Mailtrap é serviço externo; enviar dados reais de clientes a ele em dev seria transferência a terceiro sem finalidade (SG12-05). Logs e fila sem PII em claro. Nenhum requisito obrigatório do SDD Seção 7 fica sem atendimento em desenvolvimento/sandbox; o item de TLS é condição para produção.

### 8. Requisitos de segurança operacional para o chapéu DevOps
- Produção: `UsaTLS=1` obrigatório, porta 587/465, senha só por `ERPV_SMTP_PASSWORD` (INI sem `Senha`), conta SMTP de menor privilégio (só envio), rotação de credencial.
- Homologação/dev com Mailtrap: somente dados fictícios (nunca base de produção/cópia com clientes reais).
- Distribuir OpenSSL 1.0.2u (última) ou a versão suportada pelo Indy adotado, com origem/hash conferidos; monitorar EOL.
- Remetente com domínio real e SPF/DKIM/DMARC configurados antes do go-live (o padrão `nao-responder@erpvendas.local` não é entregável na internet).
- Requisitos da seção 6 do Lote 11 (ACL da `PastaPdfTemp`) continuam valendo.

### Achados do lote

| # | Achado | Severidade | Situação |
|---|---|---|---|
| SG12-01 | Sem verificação de certificado TLS (`VerifyMode` padrão vazio, sem `OnVerifyPeer`/CA) e `utUseExplicitTLS` oportunista (downgrade por remoção de STARTTLS): MITM lê usuário/senha SMTP e PDF com PII; aceitável só em Mailtrap sandbox com dados fictícios | Média (Alta se produção sem correção) | Débito com prazo: **antes do primeiro deploy em produção/smoke T54 com SMTP real**; `SSLOptions.VerifyMode := [sslvrfPeer]`, `VerifyDepth`, `OnVerifyPeer` validando cadeia + hostname (`RootCertFile` ou repositório do SO) e `utUseRequireTLS` quando `UsaTLS=1`; tarefa em `Refatoração Lote-12`. Não bloqueia o lote (dev) |
| SG12-02 | OpenSSL 1.0.2 (spike T02) sem suporte, CVEs conhecidos; uso apenas como cliente para host fixo configurado | Baixa | Débito: registrar EOL, usar 1.0.2u e planejar migração (Indy/OpenSSL 1.1+); requisito ao DevOps; `Refatoração Lote-12` (documental) |
| SG12-03 | `TEmailSender.Enviar` não revalida o destinatário (só `Trim`/vazio); CRLF/vírgula em dado legado ou gravado fora do fluxo validado chegaria a `Recipients` | Baixa (defesa em profundidade; caminho normal protegido por `EmailValido`) | Débito: chamar `EmailValido` em `Enviar` e retornar `Falha(MSG_DESTINATARIO)`; teste unitário com lista de destinatários e com CRLF; `Refatoração Lote-12` |
| SG12-04 | PDF com PII legível na pasta temp durante o envio síncrono (até ~45 s) e resíduo em queda do app; sem varredura (continuação de SG11-01/SG11-02) | Baixa (Média se pasta compartilhada; sem código novo no T49) | Sem tarefa nova; vincular T49 ao prazo de SG11-01/02 (antes do smoke T54) |
| SG12-05 | Envio de e-mail com dados reais de cliente ao Mailtrap (terceiro) em dev/homologação | Baixa (operacional/LGPD) | Regra ao DevOps/Gestor: apenas dados fictícios no sandbox; sem código |
| SG12-06 | `PosQuitacao` engole falha de `Enfileirar` (`:298-302`) sem registrar: e-mail perdido sem rastro nem reconciliação; mesma classe de SG9-01 | Baixa (integridade; sem vazamento) | Débito: registrar (log mascarado, só Id da venda) e sinalizar na mensagem da UI; junto de SG9-01; `Refatoração Lote-12` |

Sem achados de: injeção via assunto/corpo, vazamento de senha, PII em log/fila/mensagem, erro do SMTP exposto, traversal no anexo.

### Veredito do lote (chapéu DevSecOps)
**Aprovado com débito** (SG12-01 média com condição de produção; SG12-02..06 baixos). Sem achado alto/crítico e sem compliance obrigatório em aberto no escopo dev/sandbox: credenciais fora do log e do código, mensagens de erro fixas, `ULTIMO_ERRO` sem PII (fixo + mascarado + truncado), assunto/corpo sem entrada de usuário, destinatário validado na origem, PDF apagado em sucesso e falha. Não bloqueia o deploy de homologação/Mailtrap. **SG12-01 sobe para Alta e passa a bloquear deploy em produção com SMTP real** se o certificado não for verificado e o STARTTLS exigido.

Escala para: nenhum bloqueio. Gestor: informativo, SG12-05 (dados reais em serviço externo) e SG11-05 (CPF completo no PDF). Coordenador: não. Executor: correção via `Refatoração Lote-12`, não imediata (SG12-01 antes de produção). DevOps: requisitos da seção 8.

## Lote 13 — Reenvio e Pendências (T50-T53) — chapéu DevSecOps (2026-09-24)

Método: leitura estática de `FilaService`, `FilaRepository`, `PendenciaFila`, `VendaService`, `QuitacaoService`, `FormPendencias`, `PendenciasApresentacao`, `TLogger.MascararSensiveis` e `FinanceiroClient.ExtrairMensagem`, mais o `QA-REPORT.md` do lote (A1-A6, R13-1..3). Nada compilado/executado (sem IDE). Notas do Executor não usadas como base.

### 1. ULTIMO_ERRO na grade (RF9-05)
`TruncarErro` (mascara e depois trunca a 500) é aplicada em `Enfileirar`, `RegistrarFalha` e no incremento; a grade lê só a coluna já gravada. A máscara cobre CPF/CNPJ (formatado ou só dígitos) e e-mail (`u***@dominio`), além de `senha/token/apikey=valor`. `Env.MensagemErro` do SMTP são constantes fixas, sem PII. `Resp.Mensagem` do Financeiro é texto de terceiro (até 200 caracteres, uma linha), mascarado só na persistência. Limite: a máscara não cobre nome, telefone, endereço nem CPF com espaços ou outro formato. Lacuna: a mensagem devolvida à UI por `Falha`/`TResultadoReenvio.Mensagem` (`'Ainda não foi possível: ' + Mensagem`) é o texto CRU, sem `MascararSensiveis`; só a cópia no banco é mascarada (SG13-01).

### 2. PDF com PII na pasta temp no reenvio
`ReenviarEmail`: o `Limpar(Pdf)` roda em sucesso, falha do `Enviar` e exceção (o `except` interno captura tudo antes). Handle liberado no `Enviar`. Falha parcial: se `GerarPdf` lança depois de criar o arquivo, `Pdf=''` e nada é limpo (SG13-03). Sem varredura na inicialização e ACL herdada: continuam SG11-01/02 e SG12-04, com prazo antes do smoke T54.

### 3. Reenvio duplicado (A1) e implicação
Com o filtro desmarcado, Reenviar em item EMAIL `CONCLUIDO` reenvia o PDF com CPF/CNPJ completo ao titular (SG11-05) e sobrescreve `CONCLUIDO_EM`. É repetição ao próprio titular, sem exposição a terceiro; o impacto é de integridade, trilha adulterada e minimização LGPD. Em QUITACAO/CANCELAMENTO concluído, o service checa status local e GET, então não repõe POST, mas `RegistrarFalha` (UPDATE sem `AND STATUS='PENDENTE'`) altera `TENTATIVAS`/`ULTIMO_ERRO` de item concluído. `Reenviar` confia em `AFilaId`, `AVendaId` e `ATipo` vindos separados da UI e não confere se o item existe, é PENDENTE e pertence à venda/tipo (SG13-02).

### 4. Guarda de bloqueio no Service
`VendaBloqueadaPorFila` é aplicada em `VendaService.ExigirPendente` (Salvar Id>0, Excluir) e `QuitacaoService.Confirmar/Cancelar` antes do POST, além da UI: defesa em profundidade correta e fail-safe (falha na consulta da fila impede a ação; A4 é de UX). Sem TOCTOU relevante (desktop monousuário). O pós-quitação ausente (A2) é funcional, não de segurança. Sem achado.

### 5. Logging, EInfra e mensagens ao usuário
`FilaService` e a UI nova não logam (nenhum dado pessoal em log). Contrapartida: sem trilha de quem reenviou/quando (SG13-04). `EInfra` traz mensagens fixas amigáveis, sem SQL; o log técnico do repositório passa pelo mascaramento. `E.Message` só é exposto para `EErpVendas`; demais exceções viram texto genérico. Exceção de `Obter`/`ConsultarStatus` sem proteção (A4) cai na UI com texto genérico: sem vazamento.

### 6. Injeção/SQL
Acessos novos (`SQL_BUSCAR_PENDENTE`, `SQL_INCREMENTAR`, `SQL_CONCLUIR`, `SQL_CONTAR`) parametrizados; `Listar` concatena só constantes conforme o booleano. Sem achado. Aderência a SDD Seção 7, GUARDRAILS e ADR-005/006/007 (POST fora de transação, commit curto, GET antes do repost, PDF sem persistência): OK.

### 7. Compliance (LGPD)
Finalidade e base contratual mantidas (reenvio ao próprio titular). Minimização: cancelamento reenvia sem motivo (positivo); PDF com CPF completo (SG11-05, já sinalizado). Sem compliance obrigatório em aberto.

### 8. Requisitos ao chapéu DevOps
Sem novos além dos Lotes 11 e 12 (ACL da `PastaPdfTemp`, TLS/`ERPV_SMTP_PASSWORD`, dados fictícios no Mailtrap). O smoke deve cobrir reenvio de EMAIL e confirmar pasta temp vazia depois.

### Achados do lote

| # | Achado | Severidade | Situação |
|---|---|---|---|
| SG13-01 | Mensagem de falha exibida ao operador (`Resp.Mensagem` do Financeiro, até 200 caracteres) sem `MascararSensiveis`; máscara não cobre nome/telefone/endereço nem CPF em formato atípico | Baixa | Débito: aplicar `TLogger.MascararSensiveis` em `Falha` antes de devolver à UI; ampliar teste de máscara; `Refatoração Lote-13` |
| SG13-02 | Reenvio sem validar item (PENDENTE, existência, vínculo fila/venda/tipo); A1 reenvia e-mail com PII a item CONCLUIDO e altera `CONCLUIDO_EM`, `TENTATIVAS`, `ULTIMO_ERRO` | Baixa (integridade/minimização; sem exposição a terceiro) | Débito, junto de A1: service obtém o item e recusa se não PENDENTE; UPDATE com `AND STATUS='PENDENTE'`; botão só em PENDENTE |
| SG13-03 | `GerarPdf` com falha parcial pode deixar PDF sem `Limpar`; `Limpar` engole erro sem registro | Baixa | Débito: limpeza por nome previsível/`finally`; varredura na inicialização (SG11-01/02, antes do smoke T54) |
| SG13-04 | Sem trilha de auditoria do reenvio (quem/quando); nenhum log de desfecho, mesmo mascarado | Baixa | Débito: log mascarado só com Id da fila/venda e desfecho; junto de SG9-01/SG12-06 |

Sem achados de: PII em log, injeção SQL, credencial, erro técnico exposto, bloqueio só na UI, exposição a terceiro.

### Veredito do lote (chapéu DevSecOps)
**Aprovado com débito (sem achado bloqueante).** Nenhum alto/crítico e nenhum compliance obrigatório em aberto; SG13-01..04 baixos, com prazo antes do smoke T54/Lote 16, junto dos débitos dos Lotes 11/12. SG12-01 (TLS) continua bloqueando produção com SMTP real.

Escala para: nenhum bloqueio. Executor: correção via `Refatoração Lote-13` (SG13-02 junto de A1; SG13-01 e SG13-03 antes do smoke T54). Gestor: informativo (SG11-05, SG12-05 mantidos). Coordenador: não. DevOps: seção 8.

---

## Lote 15 — Documentação (README.md, docs/roteiro-testes-manuais.md, docs/decisoes.md) — chapéu DevSecOps

Escopo: só documentação; nenhum código alterado. Verificado o que os docs afirmam contra `ERPV.Core.Log`, `ERPV.Core.Config`, `erpvendas.ini.example`, `db/02_seed.sql`, `docs/contrato-api-financeiro.md` e `tools/mock-financeiro`.

### 1. Varredura de segredos e dados pessoais
Nenhum segredo, chave ou credencial real nos três docs. Senhas aparecem só como `<senha>` (README) ou `senha_ficticia_*` (INI example, marcado como fictício). CPFs/CNPJs do roteiro (`52998224725`, `11222333000181`, `39053344705`) são de teste, com e-mails `example.com`/`.test`, coerentes com o seed e com GUARDRAILS regra 18. `.gitignore` cobre `erpvendas.ini` e `config/*.ini`. Sem achado.

### 2. Segredos (SDD Seção 7 / ADR-007)
README §3 confere com o código: `ERPV_BANCO_SENHA`, `ERPV_SMTP_PASSWORD` e `ERPV_FINANCEIRO_APIKEY` existem em `ERPV.Core.Config` e têm prioridade sobre o INI. "Nunca versione o .ini" está correto. O roteiro instrui a preencher senha SMTP no INI do Mailtrap (sandbox, aceitável). Ressalva: `gbak/isql ... -password <senha>` na linha de comando deixa a senha no histórico do shell e na lista de processos, o que é normal em dev, mas o README não sugere `ISC_PASSWORD` (SG15-03).

### 3. /_modo
O mock escuta em `127.0.0.1` por padrão e o README diz "usar só em localhost". Rota sem autenticação, só em mock de dev. O doc não avisa contra `--host 0.0.0.0` nem contra usar o mock fora da máquina de dev (SG15-04).

### 4. Fidelidade da nota LGPD
- Dados tratados, finalidade e PDF só ao e-mail do cliente: conforme o SDD/código.
- "Logs: CPF/CNPJ e e-mail são mascarados": verdadeiro para CPF/CNPJ (formatado ou só dígitos), e-mail e `senha/token/apikey=valor`. A afirmação é ampla demais: não cobre nome, telefone, endereço nem CPF em formato atípico, e a mensagem devolvida à UI não passa pela máscara (SG13-01 já registrado). "Corpo de mensagens não é gravado": coerente com o cabeçalho do Log (SG15-02).
- "Financeiro recebe somente IDs, valores e itens (sem dados pessoais)": verdadeiro para quitação (`vendaId`, `clienteId`, `valorTotal`, `itens`). Impreciso no cancelamento: o contrato envia `motivo` de texto livre, que pode conter dado pessoal (mesmo risco de SG10-04, cujo hint na UI ainda é débito). O `clienteId` é identificador pseudônimo (SG15-01).
- Retenção: descrição fiel (inativação, sem exclusão física, PDF temporário apagado após envio). A nota reconhece que não há prazo de guarda nem expurgo e o delega ao controlador. Não menciona atendimento a pedido de eliminação/anonimização do titular (art. 18), pois a inativação não elimina o dado. É decisão de negócio (SG15-05).

### 5. Sensitive-data-exposure no roteiro
Passos usam dados fictícios. O roteiro exige "log sem senha nem CPF/e-mail completos", o que verifica a máscara real. Sem exposição de credencial nos passos de erro (mensagens amigáveis). O uso de Mailtrap evita e-mail real.

### Achados do lote

| # | Achado | Severidade | Situação |
|---|---|---|---|
| SG15-01 | README diz que o Financeiro não recebe dado pessoal, mas o cancelamento envia `motivo` livre (pode ter PII) e `clienteId` é identificador | Baixa | Débito: reformular ("IDs, valores, itens e, no cancelamento, motivo informado pelo operador"); junto do hint SG10-04. Prazo: antes da entrega (25/09) |
| SG15-02 | "Logs mascaram CPF/CNPJ e e-mail" sem informar o limite (nome, telefone, endereço, formatos atípicos, texto da UI) | Baixa | Débito: acrescentar o limite e citar SG13-01. Prazo: antes da entrega |
| SG15-03 | `-password <senha>` na linha de comando no passo de restauração/isql | Baixa (dev) | Débito: sugerir `ISC_PASSWORD` ou prompt |
| SG15-04 | Sem aviso de não expor o mock (`--host 0.0.0.0`) nem de que `/_modo` é sem autenticação fora do dev | Baixa | Débito: uma linha no README/mock |
| SG15-05 | Retenção sem prazo e sem previsão de eliminação/anonimização a pedido do titular | Baixa (decisão de negócio) | Informativo ao Gestor (definir prazo e procedimento no responsável pelo tratamento); não bloqueia MVP |

Sem achados de: segredo/credencial real, dado pessoal real, nome de variável de ambiente divergente do código, instrução insegura de produção.

### Veredito do lote (chapéu DevSecOps)
**Aprovado com débito (sem achado bloqueante).** Nenhum alto/crítico e nenhum compliance obrigatório em aberto; SG15-01..05 são de baixa severidade e viram tarefas em `Refatoração Lote-15` (correções só de texto, SG15-01/02 antes da entrega de 25/09). Débitos dos Lotes 11 a 13 mantidos; SG12-01 (TLS) continua bloqueando produção com SMTP real.

Escala para: nenhum bloqueio. Executor: correção via `Refatoração Lote-15`. Gestor: informativo (SG15-05, mais SG11-05 e SG12-05 mantidos). Coordenador: não. DevOps: nenhum requisito novo; o pacote de entrega não deve incluir `erpvendas.ini` real.
