# BLOCKERS — ERP Vendas (Delphi)

## Bloqueio 001 — 2026-09-22
- Reportado por: executor (chapéu Build, T01)
- Escalado para: usuário
- Artefato/trecho afetado: `TASK.md` — Lote 1, T01 ("Ambiente e licenças: instalar
  Delphi ... hello world compilando com os 4 ... fechar DEC-02 ... incluir S3 ...
  listar skins do trial DevExpress")
- Descrição: o ambiente de execução deste Executor (worktree de automação, máquina
  Windows sem interação gráfica) não tem Delphi/Embarcadero, Firebird, DevExpress
  VCL nem ReportBuilder instalados (verificado: `dcc32`/`delphi` ausentes do PATH;
  nenhuma pasta Embarcadero/Borland/Firebird/DevExpress em
  `C:\Program Files` nem `C:\Program Files (x86)`). O critério de aceite de T01 é
  inerentemente manual e depende de IDE gráfica instalada e licenciada
  (Delphi Community/trial, DevExpress trial, ReportBuilder trial) numa máquina de
  desenvolvimento real — instalação interativa vinculada a conta/licença pessoal,
  fora do escopo de uma tarefa de codificação automatizada. Não é possível, portanto,
  produzir o "hello world" compilando com os 4 componentes, testar a conexão FireDAC
  real, rodar um `TppReport` real, fechar DEC-02 com uma versão real observada, nem
  listar os skins reais disponíveis no trial DevExpress — qualquer um desses dados,
  se registrado, seria evidência fabricada.
- Impacto se não resolvido: T01 é a primeira tarefa do projeto e bloqueia (via
  dependência declarada em `TASK.md` Seção 3/4) T02, T03, T07, T14, T15, T68 e,
  transitivamente, praticamente todo o restante do plano — nenhuma tarefa de
  Lote 2 em diante pode ser fechada com evidência real de compilação/execução
  Delphi enquanto o ambiente de desenvolvimento real não existir ou não for
  disponibilizado ao Executor.
- Sugestão: (a) o usuário executa a instalação real (Delphi Community/trial,
  Firebird 3.0, DevExpress VCL trial, ReportBuilder trial) na própria máquina de
  desenvolvimento e roda o roteiro descrito em `docs/ambiente-licencas.md` §4-6,
  preenchendo a tabela de versões/validade e a lista de skins; ou (b) o usuário
  disponibiliza a uma futura instância do Executor um ambiente com esses
  componentes já instalados para que o roteiro seja executado e T01 seja fechada
  com evidência real. Em ambos os casos, a tarefa fica `Bloqueada` (não
  `Concluída`) até essa evidência real existir.
- Status: **Resolvido (2026-09-22)** — usuário instalou Delphi 13 Community
  Edition, Firebird 3.0.14.33856-0 (Win32), DevExpress VCL 26.1.4 (trial) e
  ReportBuilder Professional 23.04 (demo, sem prazo) na máquina de
  desenvolvimento real. Evidência do "hello world" (cxButton + TFDConnection
  conectado via FireDAC ao Firebird + TppReport) confirmada rodando, sem
  erros. T01 marcada `Concluída` em `TASK.md`. Detalhes completos em
  `docs/ambiente-licencas.md`.

## Bloqueio 002 — 2026-09-22
- Reportado por: executor (chapéu Delphi, T67 — Spike S2)
- Escalado para: usuário
- Artefato/trecho afetado: `TASK.md` — Lote 1, T67 ("Spike S2: ReportBuilder
  trial gera PDF a partir de DataSet ... PDF de 1 página abre no leitor;
  limitações (marca d'água/aviso) anotadas em `docs/ambiente-licencas.md`")
- Descrição: o ambiente de execução deste Executor (worktree de automação,
  máquina Windows sem interação gráfica) não tem acesso ao Report Designer da
  IDE — só consegue inspecionar estaticamente os arquivos instalados do
  ReportBuilder Professional 23.04 em
  `C:\Program Files (x86)\Embarcadero\Studio\37.0\RBuilder\Lib`. Por essa via,
  foi possível confirmar que a edição instalada tem, sim, um dispositivo
  nativo de exportação para PDF (classe `TppPDFDevice`, arquivo
  `ppPDFDevice.dcu`, com suporte adicional a PDF/A, assinatura digital,
  criptografia e leitor de PDF embutido via `pdfium.dll`) — documentado em
  `docs/ambiente-licencas.md` §3.1. Porém **não é possível, sem a IDE aberta,
  de fato criar um `TppReport` ligado a um `DataSet`, desenhar um layout,
  exportar para PDF, abrir o PDF resultante num leitor, nem confirmar
  visualmente se o texto/aviso da Digital Metaphors (ou alguma marca d'água do
  trial) aparece no PDF exportado** — o motor de renderização/exportação é
  distribuído só como `.dcu` compilado (sem fonte legível), então essa
  confirmação não dá para obter por leitura estática de arquivo; exige rodar o
  Report Designer de verdade. Registrar esse resultado como obtido seria
  evidência fabricada.
- Impacto se não resolvido: T67 é dependência declarada de T46 (layout
  ReportBuilder "Confirmação de Pedido") e T57 (README com nota de limitação
  do trial) em `TASK.md` Seção 3/4 — ambas ficam sem a confirmação real de que
  a exportação para PDF funciona e sem saber se a marca d'água precisa constar
  como limitação conhecida no `README.md`. O critério de aceite de T67
  ("PDF de 1 página abre no leitor; limitações anotadas") é inerentemente
  manual e não pode ser fechado sem essa evidência.
- Sugestão: usuário, na IDE com o Report Designer aberto, no ambiente real:
  (a) criar um `TppReport` simples ligado a um `TDataSet` em memória (ex.: um
  `TFDMemTable` com 2-3 linhas fictícias); (b) desenhar um layout mínimo no
  Report Designer (cabeçalho + 1-2 campos do dataset já basta para o spike);
  (c) exportar para PDF usando o filtro de exportação do ReportBuilder
  (`TppPDFDevice`, confirmado disponível — ver `docs/ambiente-licencas.md`
  §3.1); (d) abrir o PDF gerado num leitor e confirmar que abre normalmente e
  se aparece algum texto da Digital Metaphors/marca d'água nele; (e) reportar
  o resultado (print/descrição) para uma futura instância do Executor
  registrar em `docs/ambiente-licencas.md` e fechar T67 com evidência real.
  Até lá, a tarefa fica `Bloqueada` (não `Concluída`) em `TASK.md`.
- Status: **Resolvido (2026-09-22)** — usuário gerou o PDF real na IDE
  (`ppReport1.DeviceType := dtPDF` + `TextFileName` + `PDFSettings.OpenPDFFile`,
  API correta confirmada no manual oficial `RBuilder.pdf`, não a hipótese
  inicial via `TppPDFDevice`). PDF de 1 página, abriu normal no Acrobat, dados
  corretos; marca d'água da Digital Metaphors confirmada presente no PDF
  exportado. T67 marcada `Concluída` em `TASK.md`. Detalhes em
  `docs/ambiente-licencas.md` §3.2.

## Bloqueio 003 — 2026-09-22
- Reportado por: executor (chapéu Delphi, T02 — Spike S1)
- Escalado para: usuário
- Artefato/trecho afetado: `TASK.md` — Lote 1, T02 ("Spike S1: envio SMTP real
  com Indy + OpenSSL ... e-mail chega ao Mailtrap/Ethereal com anexo PDF de
  teste; parâmetros TLS e DLLs anotados em `docs/ambiente-licencas.md`") e
  Seção 2 ("Spikes Técnicos", linha S1 = T02).
- Descrição: o ambiente de execução deste Executor (worktree de automação,
  máquina Windows sem interação gráfica) permite inspecionar estaticamente o
  ambiente e o código-fonte do Indy, mas não permite (a) criar uma conta real
  no Mailtrap/Ethereal (serviço externo, exige cadastro), nem (b) compilar e
  rodar um projeto VCL de teste na IDE gráfica para de fato enviar um e-mail.
  Pela via estática, foi possível confirmar, com evidência real (detalhada em
  `docs/ambiente-licencas.md` §11): (1) as DLLs que o Indy 10.6.3.11 (embutido
  no Delphi 13) exige para SSL/TLS no Windows — `ssleay32.dll` +
  `libeay32.dll` (ou `libssl32.dll` como alternativa de `ssleay32.dll`),
  família OpenSSL 1.0.2 ou anterior, conforme constantes lidas diretamente em
  `IdSSLOpenSSLHeaders.pas` — **não estão presentes** em `C:\Windows\System32`,
  `C:\Windows\SysWOW64`, em nenhum diretório do `PATH`, nem em lugar algum da
  instalação do Delphi/RAD Studio; (2) as únicas DLLs OpenSSL encontradas na
  máquina (`libssl-1_1.dll`/`libcrypto-1_1.dll`, empacotadas pelo
  ReportBuilder) são da família OpenSSL 1.1.x, com nome de arquivo diferente
  do que o Indy procura, e o próprio código-fonte do Indy declara não suportar
  essa família (comentário explícito citando que a 1.1.0 "made MAJOR changes
  we do not support yet"). Isso confirma de forma real a incerteza R-02 do
  spike: sem baixar e instalar a DLL correta, o caminho "com TLS" do
  `TIdSSLIOHandlerSocketOpenSSL` vai falhar ao carregar a biblioteca SSL. Não
  é possível, porém, produzir a evidência final exigida pelo critério de
  aceite (e-mail de fato chegando ao Mailtrap/Ethereal, com e sem TLS, com
  anexo PDF) sem a IDE aberta e uma conta real — registrar esse resultado como
  obtido seria evidência fabricada.
- Impacto se não resolvido: T02/S1 bloqueia (via `TASK.md` Seção 3/4) T03,
  T05, T06 (paralelizáveis apenas depois que T02 estiver decidida) e,
  principalmente, deixa T48 (`EmailSender`/`IEmailSender` real) sem parâmetro
  de porta/TLS confirmado — T48 só tem estimativa firme depois do resultado
  de S1 (nota no `TASK.md` Seção 2). Sem o download da DLL OpenSSL correta,
  qualquer tentativa de envio com TLS vai falhar em tempo de execução.
- Sugestão: usuário, na máquina de desenvolvimento real, com a IDE aberta: (a)
  baixar um build Win32 do OpenSSL 1.0.2 compatível com Indy (histórico:
  `indy.fulgan.com/SSL/`; alternativa se fora do ar: repositório
  `IndySockets/OpenSSL-Binaries` no GitHub) e colocar `libeay32.dll` +
  `ssleay32.dll` na pasta do `.exe` de teste; (b) criar uma conta gratuita no
  Mailtrap ou Ethereal; (c) seguir o roteiro passo a passo documentado em
  `docs/ambiente-licencas.md` §11.4 (parâmetros exatos de `TIdSMTP`/
  `TIdSSLIOHandlerSocketOpenSSL`, com e sem TLS, anexo PDF de teste); (d)
  reportar o resultado (sucesso/falha, porta que funcionou, mensagem de erro
  se houver, sem incluir senha) para uma futura instância do Executor
  registrar em `docs/ambiente-licencas.md` §11 e fechar T02 com evidência
  real. Até lá, a tarefa fica `Bloqueada` (não `Concluída`) em `TASK.md`.
- Status: **Resolvido (2026-09-22)** — usuário baixou as DLLs OpenSSL 1.0.2
  Win32 corretas, criou conta sandbox no Mailtrap e testou com sucesso os dois
  cenários (com TLS na porta 587, sem TLS na porta 2525), ambos com o anexo
  PDF confirmado no inbox. T02 marcada `Concluída` em `TASK.md`. Detalhes em
  `docs/ambiente-licencas.md` §11.5.

## Bloqueio 004 — 2026-09-23
- Reportado por: executor (chapéu UI, T46 — Layout ReportBuilder "Confirmação de Pedido")
- Escalado para: usuário
- Artefato/trecho afetado: `TASK.md` — Lote 11, T46 (bloqueia T47 e, via T47, T49)
- Descrição: o layout exige bandas do ReportBuilder (cabeçalho, detalhe, resumo,
  rodapé), `TppLabel`/`TppDBText` e `TppDBPipeline` ligado ao DataSet de T45
  (`TVendaRepository.RelatorioDataSet`). O Executor não tem acesso ao Report
  Designer e a instalação local do RBuilder 23.04 só traz `.dcu` (sem `.pas`,
  demos ou `RBuilder.pdf`), então montar o layout por código seria improvisar API
  sem evidência e não seria conferível ("leitura clara, sem estouro de coluna").
  `docs/ambiente-licencas.md` §3.2 só valida `dtPDF`/`TextFileName`/
  `PDFSettings.OpenPDFFile` com componentes soltos no form.
- Impacto se não resolvido: T47 (`IRelatorioPedido`) e T49 (pós-quitação com PDF
  anexo) ficam sem layout; Lote 11 não fecha.
- Sugestão: (1) usuário desenha o layout no Report Designer (TDataModule/TForm
  `ERPV.Relatorios.PedidoLayout` com `ppReport` + `ppDBPipeline`, colunas:
  VENDA_ID, DATA_VENDA, STATUS, VALOR_TOTAL, CLIENTE_NOME, CLIENTE_CPF_CNPJ,
  CLIENTE_EMAIL, PRODUTO_DESCRICAO, QUANTIDADE, PRECO_UNITARIO, SUBTOTAL; 1 linha
  por item) e um Executor escreve o registro no `.dpr`/`.dproj`, a unit
  consumidora e o roteiro manual; ou (2) usuário fornece unit/`.dfm`/`.rtm` de
  referência para o Executor seguir por código.
- Status: **Resolvido (2026-09-23)** — usuário desenhou o layout no Report Designer (opção 1); Executor registrou a unit no `.dpr`/`.dproj` e adicionou `AtribuirDados`/`Visualizar` + roteiro. T46 volta a `Concluída` (pendente de compilação na IDE); T47 desbloqueada.

## Bloqueio 005 — 2026-09-23
- Reportado por: validador (chapéu QA, validação do Lote 9 — achado A1, crítica)
- Escalado para: executor
- Artefato/trecho afetado: `TASK.md` — Lote 9, T42 (voltou a `Em andamento`); mesma correção vale para as units de T37/T38-T41
- Descrição: `src/UI/ERPV.UI.ConfirmacaoVenda.pas`, `src/Negocio/ERPV.Negocio.QuitacaoService.pas` e `src/Dados/ERPV.Dados.FilaRepository.pas` têm caracteres acentuados e estão gravadas em UTF-8 **sem BOM**; as demais units acentuadas do projeto têm BOM. O Delphi 10.3+ lê arquivo sem BOM como ANSI, então os textos literais de UX 4.3 (e as mensagens de erro/fila) sairiam com mojibake. É o mesmo problema de RF7-05 (Lote 7).
- Impacto se não resolvido: mensagens de desfecho da Confirmação ilegíveis; T42 não cumpre "texto literal de UX 4.3". DevSecOps do Lote 9 não foi executado (fluxo parou na reprovação crítica).
- Sugestão: regravar as 3 units em UTF-8 com BOM (sem alterar o conteúdo), conferir que nenhuma outra unit nova acentuada ficou sem BOM (varredura `src/`), e rodar `/executar_tarefa T42` (ou `/executar` no Lote 9); depois `/validar lote 9` de novo. Achados simples A2-A5 do QA serão agendados em `Refatoração Lote-9` na revalidação.
- Status: **Resolvido (2026-09-23)** — correção de BOM em 3 units (`ConfirmacaoVenda`, `QuitacaoService`, `FilaRepository`): EF BB BF prefixado sem alterar o resto dos bytes (+3 bytes cada, CRLF preservado); varredura de `src/` e `.dpr` não achou outra unit acentuada sem BOM. T42 volta a `Concluída` (pendente de compilação na IDE) e segue para `/validar lote 9`.

## Bloqueio 006 — 2026-09-24
- Reportado por: usuário (a partir do parecer ad hoc do coordenador sobre o achado da validação da RF9-02)
- Escalado para: usuário, com parecer do gestor quando o tema for retomado — **decisão adiada de propósito para o FIM do projeto**
- Artefato/trecho afetado: fluxo Confirmar/Cancelar (`QuitacaoService`), `FILA_INTEGRACAO`, `docs/contrato-api-financeiro.md` (v1.1, proposta C3), SDD R-03, ADR-005/006
- Descrição: garantir **idempotência** (reenviar a mesma quitação/cancelamento sem efeito duplicado no Financeiro nem no local) e o comportamento de **saga** (falha gera compensação/rollback coerente entre Financeiro e banco local). Parecer do coordenador: *parcialmente previsto*. Idempotência hoje = reconciliação por GET `/status` antes de repostar (T41, T50/T51) + no máximo 1 item PENDENTE por venda+tipo na fila (ADR-005, só por aplicação, sem constraint) + status como fonte da verdade. Saga formal NÃO prevista: a decisão é consistência eventual por fila + reconciliação (forward-recovery, ADR-005/006) e o contrato v1.0 não tem operação de estorno da quitação (só POST quitação, POST cancelamento e GET status; cancelar só vale para venda Pendente, RN-02/DEC-09). Idempotência real do POST depende da proposta C3 do contrato v1.1, **sem confirmação do time C#** (SDD R-03: dívida aceita); para o POST de cancelamento nem há proposta. Lacunas apontadas: (1) UI de Confirmar/Cancelar ignora a mensagem do service e diz "Financeiro indisponível... colocada na fila" quando na verdade o Financeiro já quitou e a gravação local falhou (efeito da RF9-01); (2) `Cancelar` não reconcilia por GET antes de enfileirar; (3) sem retry/reconciliação imediata após "Financeiro OK e local falhou"; (4) unicidade da fila sem índice único parcial; (5) falha de `Enfileirar` do e-mail engolida (SG12-06); (6) crash entre POST e commit local sem item na fila não dispara reenvio (aceito, ADR-006/R-04).
- Impacto se não resolvido: risco residual de quitação/cancelamento duplicado ou de operador enganado por mensagem imprecisa; nenhuma tarefa atual depende disso. **Este bloqueio NÃO impede a execução das demais tarefas** (`/executar`, `/executar_tarefa` e `/validar` devem ignorá-lo e seguir a fila normalmente); só deve ser retomado quando TODAS as tarefas do TASK.md estiverem `Concluída`/`Validado`, antes do encerramento do projeto e antes de `/deploy` para produção.
- Sugestão (propostas do coordenador, ainda NÃO viraram tarefas): M1 (UI ~1 h) exibir a mensagem do service e distinguir "Financeiro indisponível" de "Financeiro quitou, gravação local falhou" (desfecho novo; mexe no enum do ADR-006, que é imutável, então exige nota ou novo ADR); M2 (~2-3 h) `Cancelar` reconcilia por GET antes de enfileirar; M3 (~2 h) retry curto/reconciliação após falha local; M4 (~1-2 h, opcional) índice único parcial na fila PENDENTE por venda+tipo; M5 (~1 h) sinalizar falha de `Enfileirar` do e-mail (SG12-06); M6 (~2 h) teste com fake do gateway (POST=Indisponível, GET=Quitada), já com o modo `timeout-post` do mock (RF9-03). Decisões que dependem do usuário/Gestor: (a) cobrar do time C# a confirmação da C3 e estender a idempotência ao POST de cancelamento (mudança de contrato, registrar em `docs/contrato-api-financeiro.md`, GUARDRAILS 13); (b) se o C# não confirmar, manter a dívida aceita (SDD R-03) ou bloquear o reenvio manual de QUITACAO quando o GET não confirmar o estado; (c) rota de estorno no Financeiro está fora do escopo v1 e só o Gestor pode abri-la. Limitação do parecer: o coordenador leu `Confirmar`/`Cancelar` por grep e não T37-T44 linha a linha; conferir antes de transformar em tarefas.
- Status: **Aberto (adiado)** — retomar no fim do projeto, com todas as tarefas prontas, antes do encerramento/deploy.
