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
