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
- Status: **Aberto**
