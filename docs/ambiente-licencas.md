# Ambiente e Licenças — ERP Vendas (Delphi)

Tarefa: T01 (Lote 1). Status: **Concluída** — 4 componentes instalados,
verificados na máquina de desenvolvimento real em 2026-09-22, e evidência do
"hello world" confirmada (Seção 8).

## 1. Componentes instalados (evidência real, verificada em 2026-09-22)

| Componente | Edição | Versão exata | Arquitetura | Validade da licença/trial |
|---|---|---|---|---|
| Delphi (RAD Studio) | Community Edition | Delphi 13, build **37.0.60542.8024** (Indy 10.6.3.11 embutido) | Win32 + Win64 | Registrado — **367 dias restantes** a partir de 2026-09-22 |
| Firebird | Server, modo SuperServer, rodando como serviço Windows | **3.0.14.33856-0** | **Win32** (instalado em `Program Files (x86)`) | N/A (FOSS) |
| DevExpress VCL | Trial | **26.1.4** | Win32/Win64 (integrado à IDE) | Trial padrão de 30 dias a partir da instalação (2026-09-22) → **~2026-10-22** (confirmar data exata no DevExpress License Manager) |
| ReportBuilder | **Professional** (licença "Demo Software") | **23.04**, pacote "for Delphi 13" (release 27/05/2026) | Win32/Win64 (`Studio\37.0\RBuilder\Lib\Win32` e `Win64`) | **Sem prazo de expiração** — ver limitações na Seção 3 |

Ambiente confirmado: Windows 11 (build 26200.9457), 64-bit.

Nenhuma chave, número de série, ou credencial está (ou será) registrada neste
arquivo, em conformidade com `GUARDRAILS.md` regra 16.

## 2. Como cada item foi verificado (evidência, não afirmação)

- **Delphi**: lido diretamente da caixa "About Embarcadero® Delphi" na IDE
  aberta pelo usuário (Community Edition, versão e dias de licença exibidos ali).
- **Firebird**: `isql -z` executado pelo usuário no terminal, saída:
  `ISQL Version: WI-V3.0.14.33856 Firebird 3.0`. Pasta de instalação em
  `C:\Program Files (x86)\Firebird\Firebird_3_0` confirma build **Win32**.
- **DevExpress VCL**: versão **26.1.4** lida do título do instalador ("VCL
  26.1.4 Trial Version Setup") durante a instalação pelo usuário.
- **ReportBuilder**: confirmado por leitura direta dos arquivos instalados em
  `C:\Program Files (x86)\Embarcadero\Studio\37.0\RBuilder\` — arquivo
  `Release.doc` contém "ReportBuilder for Delphi 13 — Version 23.04"; arquivo
  `RB Professional (Trial) License.txt` confirma a edição **Professional** e o
  texto integral da licença "demo" (sem data de expiração, só limitação de
  páginas/marca d'água — ver Seção 3).

## 3. Limitações da licença "demo" do ReportBuilder (Seção nova, achado do S2)

Lido diretamente do arquivo `RB Professional (Trial) License.txt` instalado:

- Saída de relatório limitada a **5 páginas**.
- **Sem suporte, sem atualizações** — é software gratuito fornecido "as is".
- **Sem data de expiração** (diferente do DevExpress, que expira em 30 dias).
- Segundo a página de download da Digital Metaphors, a saída impressa também
  traz **nome e telefone da Digital Metaphors impressos no topo** de cada
  página, e o Report Designer exibe uma **tela de aviso ("nag screen")** toda
  vez que é aberto.

**Impacto em T46/T47/T67 (spike S2):** o relatório "Confirmação de Pedido" do
MVP é curto (cabeçalho, cliente, itens, total, status) e deve caber
folgadamente em 1 página — o limite de 5 páginas não deve ser um problema
funcional. O nome/telefone da Digital Metaphors no topo da página impressa é
um artefato visual do trial que precisa ser mencionado no `README.md` (T57)
como limitação conhecida do ambiente de desenvolvimento (não aparece se o
cliente comprar a licença completa). A geração de **PDF** (T47, via
`IRelatorioPedido`) deve ser testada especificamente no spike S2 (T67) para
confirmar se esse texto também aparece no PDF gerado ou só na impressão física
— isso ainda está pendente de verificação (ver Seção 8, item pendente do S2).

### 3.1 Mecanismo de exportação para PDF (achado do S2, por inspeção de arquivos — sem GUI)

Verificado por leitura direta dos arquivos instalados em
`C:\Program Files (x86)\Embarcadero\Studio\37.0\RBuilder\Lib\Win32` (e
equivalente em `Win64`), sem abrir a IDE:

- A edição Professional 23.04 **tem, sim, um dispositivo de exportação para
  PDF nativo**: a classe `TppPDFDevice` (arquivo `ppPDFDevice.dcu`),
  confirmada por strings de RTTI legíveis no binário compilado (ex.:
  `TppPDFDevice.AddDigitalSignature`, `TppPDFDevice.ValidateAttachments`,
  `TppPDFDevice.DoOnGetPDFSignaturePassword`). `TppPDFDevice` herda de
  `TppFileDevice` (mesma base dos demais exportadores de arquivo:
  `ppDocxDevice`, `ppHTMLDevice`, `ppRTFDevice`, `ppXLSDevice`/`ppXlsxDevice`,
  `ppTIFFDevice`, `ppImageDevice`), então o padrão de uso (`PrinterSetup`/
  `Device` do `TppReport`, ou instanciar o device e chamar `Print`) segue a
  mesma API dos outros exportadores dessa suíte.
- Há suporte adicional avançado no mesmo grupo de units: PDF/A (2, 3, 3-ZF —
  `ppPDFA2Device.dcu`, `ppPDFA3Device.dcu`, `ppPDFA3ZFDevice.dcu`),
  assinatura digital (`ppPDFDigitalSignature.dcu`,
  `ppPDFDigitalSignatureDlg.dcu`/`.dfm`), criptografia (`ppPDFEncrypt.dcu`),
  metadados/outline/camadas (`ppPDFMetadata.dcu`, `ppPDFOutline.dcu`,
  `ppPDFLayer.dcu`) e até um leitor de PDF embutido via `pdfium.dll`
  (`ppPdfiumCore.dcu`, `ppPdfiumLib.dcu`,
  `ppPDFReader_PDFIum.dcu`/`ppPDFReader_WPViewPDF.pas`) — confirma que a
  geração de PDF não é um recurso limitado/ausente na licença demo; a
  limitação documentada na Seção 3 é de páginas (5) e marca d'água/aviso
  impresso, não de funcionalidade de exportação.
- **Limitação da inspeção**: o motor de renderização/exportação (`ppPDFDevice`
  e as ~50 units `ppPDF*` correlatas em `Lib\Win32`/`Lib\Win64`) é distribuído
  **só como `.dcu` compilado**, sem `.pas` fonte. Isso significa que não dava
  para ler no código onde exatamente o aviso da Digital Metaphors é injetado
  na saída — só gerando um PDF de verdade (feito na Seção 3.2 abaixo).
- **Correção de API (importante para T47):** a hipótese registrada acima —
  usar diretamente a classe `TppPDFDevice` via `PrinterSetup`/`Device` do
  `TppReport` — **não é o padrão correto** e não compila (`TppReport` não tem
  propriedade `Device`; `TppReport.DeviceType` é um **enum** de `ppTypes`, não
  uma string/objeto). O padrão real, confirmado no manual oficial
  (`RBuilder.pdf`, seção "PDF" — ver Seção 3.2), **não precisa instanciar
  `TppPDFDevice` em código nenhum**: usa só `ppReport1.DeviceType := dtPDF`
  (unit `ppTypes`) + `ppReport1.TextFileName` + `ppReport1.PDFSettings`.

### 3.2 PDF gerado de verdade — evidência real (fecha o critério de aceite de T67)

Gerado em 2026-09-22, a partir do mesmo projeto "hello world" de T01 (form com
`ppReport1` ligado a um `TFDMemTable`/`ppDBPipeline1` com 3 linhas fictícias).
Código real que funcionou (confirmado pelo manual oficial `RBuilder.pdf`,
seção "PDF" — não precisa de nenhum componente `TppPDFDevice` no form):

```pascal
uses
  ppTypes;

procedure TForm1.cxButton1Click(Sender: TObject);
begin
  ppReport1.ShowPrintDialog := False;
  ppReport1.DeviceType := dtPDF;
  ppReport1.PDFSettings.OpenPDFFile := True;
  ppReport1.TextFileName := 'C:\Temp\teste-relatorio.pdf';
  ppReport1.Print;
end;
```

**Resultado, confirmado visualmente no PDF aberto (Adobe Acrobat, via
`OpenPDFFile`):**
- PDF de **1 página**, abre normalmente, sem erro.
- As 3 linhas de dados do `TFDMemTable` aparecem corretas (Cliente Teste
  1/2/3, Produto A/B/C, valores em `R$`).
- **A marca d'água do trial aparece, sim, no PDF exportado** (não só na
  impressão física) — texto completo, no rodapé da página:
  ```
  ReportBuilder Professional™ - Demo Copy
  Version 23.04
  Digital Metaphors Corporation
  Telephone: 214.239.9471
  E-Mail: sales@digital-metaphors.com
  ```
- O mesmo aviso ("Thank you for evaluating ReportBuilder") também aparece na
  barra de status do **Report Designer** e do **Print Preview** em tempo de
  design/execução — é a mesma limitação da licença demo, presente em todos os
  pontos de saída (designer, preview e PDF exportado).

**Impacto confirmado para T46/T47/T57:** o relatório "Confirmação de Pedido"
do MVP vai sair com esse bloco de aviso da Digital Metaphors até o projeto
usar uma licença ReportBuilder comprada — **precisa constar como limitação
conhecida no `README.md` (T57)**, para não pegar o cliente/usuário final de
surpresa. Funcionalmente não impede nada (RF-19/20 seguem cumpridos: o PDF é
gerado, tem os dados corretos, cabe em 1 página).

## 4. Spike S3 — resultado (evidência real, lida do código-fonte instalado)

**Objetivo (a): driver FireDAC para Firebird na edição Community.**
Confirmado — **disponível sem licença adicional**. Verificado pela presença
dos arquivos compilados:
```
...\Studio\37.0\lib\win32\release\FireDAC.Phys.FB.dcu
...\Studio\37.0\lib\win32\release\FireDAC.Phys.FBDef.dcu
```
(e equivalentes em `win64`/`win64x`, debug/release) — o driver está incluído
de fábrica na Community Edition, para Win32 e Win64.

**Objetivo (b): propriedades de timeout do `THTTPClient`.**
Confirmado por leitura do fonte `System.Net.URLClient.pas` (classe base
`TURLClient`, herdada por `THTTPClient`): existem exatamente três
propriedades, todas `Integer`:
- `ConnectionTimeout`
- `SendTimeout`
- `ResponseTimeout`

**Achado importante para T34 (ADR-004):** os valores dessas propriedades são
em **milissegundos**, não segundos (`DefaultConnectionTimeout = 60000` =
60 s, por padrão). O `TASK.md`/ADR-004 fala em "timeout padrão 10 s do INI" —
ao implementar T34, o valor lido do INI (em segundos) precisa ser
**multiplicado por 1000** antes de ser atribuído a `ConnectionTimeout`/
`ResponseTimeout`. Documentado aqui para não se perder até lá.

## 5. Skins DevExpress disponíveis (evidência real — decisão fechada)

Lista completa lida diretamente dos arquivos `.skinres` instalados em
`DevExpress\VCL\ExpressSkins Library\Binary Skin Files` (55 skins):

AllSkins, Basic, Black, Blue, Blueprint, Caramel, Coffee, Darkroom, DarkSide,
DevExpressDarkStyle, DevExpressStyle, Foggy, GlassOceans, HighContrast,
iMaginary, Lilian, LiquidSky, LondonLiquidSky, McSkin, Metropolis,
MetropolisDark, MoneyTwins, Office2007Black, Office2007Blue, Office2007Green,
Office2007Pink, Office2007Silver, Office2010Black, Office2010Blue,
Office2010Silver, Office2013DarkGray, Office2013LightGray, Office2013White,
Office2016Colorful, Office2016Dark, Office2019Black, **Office2019Colorful**,
Office2019DarkGray, Office2019White, Pumpkin, Seven, SevenClassic, Sharp,
SharpPlus, Silver, Springtime, Stardust, Summer2008, TheAsphaltWorld,
TheBezier, Valentine, VisualStudio2013Blue, VisualStudio2013Dark,
VisualStudio2013Light, VS2010, Whiteprint, WXI, Xmas2008Blue.

**Skin escolhido: `Office2019Colorful`** — é o primeiro da ordem de
preferência definida em `UX-SPEC.md` §3.2 ("Office2019Colorful" /
"Office2016Colorful" / "Office2013White" / "Basic" / "Metropolis" / "VS2010")
que está de fato disponível nesta instalação — não foi necessário descer para
o 2º da lista, nem usar o fallback nativo do ADR-011.

**Pacote a incluir no `uses`/no `.dproj`** (registrado no
`ExpressSkins Library\Packages`, a confirmar o nome exato do `.dpk` ao montar
o esqueleto em T07/T68): `dxSkinOffice2019Colorful` + `dxSkinsCore` (núcleo,
sempre necessário).

**Confirmação em T68 (Lote 3):** `ERPV.UI.Tema.AplicarTema`
(`src/UI/ERPV.UI.Tema.pas`) usa exatamente esse mesmo skin — `Office2019Colorful`
— e o mesmo par de units (`dxSkinsCore` + `dxSkinOffice2019Colorful`), sem
reabrir a escolha feita acima em T01. A decisão não muda; T68 só implementa a
aplicação do skin (com fallback para `TcxLookAndFeelController`/
`lfUltraFlat` se o skin não carregar em runtime) e o helper de estilo de
grade/botão/notificação em cima dele. Detalhe de verificação (compilação e
conferência visual do skin realmente pintando a UI) ainda pendente de
confirmação do usuário na IDE — ver roteiro na nota de T68 em `TASK.md`.

## 6. Decisão de arquitetura (fecha DEC-02 e alinhamento entre componentes)

**Plataforma-alvo do projeto: Win32.** Coerente entre:
- Delphi: compila para Win32 e Win64 (ambos instalados).
- Firebird: instalado como build **Win32** (`Program Files (x86)`).
- DevExpress VCL: integrado para ambas as arquiteturas.
- ReportBuilder: `.dcu` presentes para Win32 e Win64.

Isso fixa a arquitetura para T02 (DLLs OpenSSL/Indy), T61 (build final) e
T64 (instalação limpa): tudo em **32 bits**.

## 7. DEC-02 (sintaxe-alvo) — fechada

Delphi 13 instalado. Sintaxe-alvo continua conforme já fixado no `TASK.md`
Seção 1: compatível com Delphi 10.3+, sem recursos exclusivos de versões
posteriores — a versão real instalada (13) é superior ao piso mínimo, então
nenhuma diretriz de compatibilidade muda; só fica confirmado que o
desenvolvimento roda na versão mais recente disponível.

## 8. "Hello world" — evidência confirmada (fecha o critério de aceite de T01)

Projeto VCL Form Application criado e testado na IDE, em 2026-09-22:

- **DevExpress**: `cxButton` adicionado ao form.
- **FireDAC + Firebird**: `TFDConnection` (`DriverID=FB`, `Protocol=TCPIP`,
  `Server=localhost`, `Database=C:\Temp\TESTE.FDB`, `User_Name=SYSDBA`) —
  banco de teste criado via `isql` (`CREATE DATABASE`). Botão **Test** do
  FireDAC Connection Editor confirmou conexão bem-sucedida após liberar o
  lock do arquivo (a sessão `isql` que criou o banco precisou ser fechada
  com `QUIT;` antes — o `isql` sem prefixo `localhost:` no `CREATE DATABASE`
  abre o arquivo em modo embedded/direto, retendo lock exclusivo; anotado
  aqui como cuidado prático para quem for criar bancos de teste depois).
- **ReportBuilder**: `TppReport` adicionado ao form.
- **Compilação**: projeto compilou e rodou (F9) sem erro, form abriu com o
  botão DevExpress visível.

### Achado: DevExpress trial exige "Link with runtime packages"

Ao compilar, a IDE acusou: *"To compile your projects with an evaluation
version of DevExpress VCL controls, you must enable the 'Link with runtime
packages' option in the project settings (Project | Options... > Packages >
Runtime Packages)."* — habilitado só para este projeto de teste.

**Risco sinalizado para T61 (build final, "sem pacotes runtime"):** o
`TASK.md` Seção 1 exige build final sem runtime packages ("build único com
DLLs mínimas"). Essa exigência de runtime packages parece ser **restrição do
trial do DevExpress**, não da versão licenciada. Enquanto o projeto real
depender do trial, T61 pode não ser viável exatamente como especificado — só
resolve de fato com uma licença DevExpress comprada antes do build final, ou
revisando a diretriz de T61 para aceitar BPLs do DevExpress como exceção
documentada. Não é bloqueio agora (T61 é do Lote 16, dia D5); só fica
registrado aqui para o usuário decidir a tempo.

### Criação do banco com charset UTF8 (RF4-03)

**Motivo:** a busca das listas (clientes/produtos) usa `COLUNA COLLATE ERPV_CI_AI LIKE ...`, para ignorar caixa e acento. A collation é criada em `db/01_schema.sql` e só existe em banco com `DEFAULT CHARACTER SET UTF8`. Em banco charset NONE, o `UPPER()` do Firebird e o `UpperCase` do Delphi só tratam ASCII: 'JOÃO' e 'ACUCAR' não achavam.

**Comando** (template em `db/00_criar_banco.sql`, sem senha; usar o prefixo `localhost:` por causa do lock descrito acima):

    CREATE DATABASE 'localhost:C:\ERPVendas\dados\ERPVENDAS.FDB' USER 'SYSDBA' PASSWORD '<senha>' DEFAULT CHARACTER SET UTF8;

**Verificação:** `SELECT RDB$CHARACTER_SET_NAME FROM RDB$DATABASE;` deve retornar `UTF8`.

**Atenção:** enquanto o banco existente for `NONE` (ou não tiver a collation `ERPV_CI_AI`), a busca das listas de clientes e de produtos dá erro no aplicativo ("Não foi possível consultar..."). Recrie o banco em UTF8 e reaplique o `01_schema.sql` atualizado antes de usar essas telas.

**Recriar o banco de desenvolvimento:** `DROP DATABASE` (isql conectado ao banco) -> `CREATE DATABASE` com UTF8 -> `db/01_schema.sql` -> `db/02_seed.sql`.

**Resultado do teste real (banco NONE, antes da correção):** 'joão' achou; 'JOÃO' NÃO; 'açúcar' achou; 'acucar'/'ACUCAR' NÃO; 'joao'/'JOAO' em clientes só achavam via e-mail `joao.teste@example.com`. Re-verificação em banco UTF8 pendente do usuário.

## 9. Pendências não bloqueantes

1. **Confirmar a data exata de expiração do trial DevExpress** no License
   Manager (não bloqueante — o cálculo de ~30 dias já está registrado acima).
2. ~~Verificar se o texto "Digital Metaphors" aparece também no PDF gerado~~ —
   **resolvido em 2026-09-22** (Seção 3.2): confirmado, aparece no PDF
   exportado (não só na impressão física). T67 fechada, Bloqueio 002
   resolvido.

## 10. Nenhuma chave/segredo commitado

Confirmado — nenhuma chave de licença, número de série, ou credencial foi
registrada neste arquivo ou em qualquer outro arquivo deste commit.
`config/erpvendas.ini.example` (T09) seguirá com dados fictícios.

## 12. Achado estrutural (T07): Delphi Community Edition não compila via linha de comando

Descoberto em 2026-09-22 ao tentar validar a compilação do esqueleto do
projeto (T07) por automação, sem IDE gráfica: tanto `dcc32.exe` direto quanto
`msbuild ERPVendas.dproj /t:Build` (com `rsvars`/`BDS` configurados
corretamente, `.dproj` importando `CodeGear.Delphi.Targets`) retornam a
mensagem do próprio compilador: *"This version of the product does not
support command line compiling."* — é uma restrição conhecida da edição
**Community**, que só compila através da IDE gráfica (`bds.exe`).

**Armadilha a evitar:** o `msbuild` reporta *"Compilação com êxito, 0 erros"*
mesmo assim, de forma **enganosa** — a pasta de saída (`Win32\Debug\`) fica
vazia, nenhum `.dcu`/`.exe` é gerado de fato. Qualquer verificação futura que
confie só na saída do `msbuild`/`dcc32` para "confirmar" compilação nesta
máquina vai estar checando um resultado falso.

**Impacto no restante do projeto:**
- **Toda tarefa Delphi a partir daqui** (T08 em diante) depende de o usuário
  abrir a IDE e compilar manualmente (F9/Ctrl+F9) para confirmar o critério de
  aceite — o Executor não consegue mais se autoverificar por linha de comando
  como fez nos artefatos não-Delphi do Lote 1 (SQL via `isql`, Python, etc.).
- **Risco para CI/CD (Lote 16, T61/T63/T64) e para qualquer pipeline
  automatizado futuro:** um build headless (servidor de CI sem IDE interativa)
  não é possível com esta edição do Delphi. Se o projeto precisar de
  integração contínua automatizada de verdade, será necessário: (a) uma
  edição paga do Delphi com suporte a compilação via linha de comando
  (Professional/Enterprise/Architect, licenciada), ou (b) manter o processo de
  build sempre manual, via IDE, mesmo em produção. Sinalizado aqui sem decidir
  — decisão de escopo/orçamento do usuário/Gestor.
- Isso reforça o risco RP-1 já registrado no `TASK.md` Seção 5 (capacidade x
  prazo): o gargalo de "revisão/compilação manual pelo dev" é ainda mais
  literal do que o esperado — é a única forma de compilar, não só de revisar.

## 13. Icones (T69, Lote 3)

**Origem/licenca: autoria propria do projeto.** Sem acesso confiavel a um
conjunto MIT/ISC (Lucide/Feather) na execucao, nenhum icone de terceiros foi
copiado e nenhuma licenca foi presumida. Os 16 glifos (traco arredondado, grade
24x24, cores da paleta semantica) sao gerados por `scripts/gerar-icones.js`
(Node, sem dependencias; reproduzivel com `node scripts/gerar-icones.js`).
Uso livre dentro do projeto; se o cliente preferir um conjunto MIT/ISC, basta
substituir os PNGs mantendo os nomes (a licenca do substituto entra aqui).

Arquivos: `assets/icones/{16,24,32}/<nome>.png`, 16 nomes = constantes
`ERPVIcone*` de `src/UI/ERPV.UI.Tokens.pas`: novo, editar, excluir, salvar,
fechar, confirmar, cancelar, buscar, atualizar, reenviar, alerta, erro, info,
sucesso, pasta_vazia, sinc.

**Como carregar (Delphi/DevExpress):** criar uma `cxImageList` central (Height/
Width 16; uma segunda de 24/32 se preciso para DPI alto), e para cada nome
`cxImageList.Add` de um `TPngImage` carregado via `LoadFromFile(pasta +
'\16\' + ERPVIconeNovo + '.png')` (uses `Vcl.Imaging.pngimage`; a pasta
`assets\icones` fica ao lado do .exe no pacote de instalacao, T61). Escolher o
tamanho por DPI: <=96 -> 16, ate 144 -> 24, acima -> 32.
- Botoes: `cxButton.OptionsImage.Images := ImgList; .ImageIndex := i`; o
  `Caption` permanece (regra: nenhum botao so com icone).
- Navegacao: `ImageIndex` do item do menu/nav ao lado do texto.
- Status bar: `Pendencias` = icone `sinc`/`alerta` + texto; banners = `erro`/
  `alerta`/`info`/`sucesso`; grade vazia = `pasta_vazia`.
Integracao nas bases de form/FormMain fica com T14/T15.

## 11. Spike S1 (T02) — Indy `TIdSMTP` + OpenSSL — status: **Bloqueada**

**Tarefa:** T02 (Lote 1). **Status: Bloqueada** — verificação estática do
ambiente concluída com evidência real; o envio de e-mail de fato (critério de
aceite da tarefa) exige IDE gráfica aberta e uma conta Mailtrap/Ethereal, que
esta sessão de automação não tem. Ver `BLOCKERS.md`, Bloqueio 002.

### 11.1 O que foi verificado de fato (evidência real, 2026-09-22)

**Busca pelas DLLs OpenSSL "clássicas" que o Indy desta versão exige
(`libeay32.dll` / `ssleay32.dll` / alt `libssl32.dll`):**

- `C:\Windows\System32` — **ausentes** (busca por `*eay*` e `*ssl*` não
  retornou nenhum arquivo com esses nomes).
- `C:\Windows\SysWOW64` (pasta de DLLs 32 bits, relevante porque a Seção 6
  já fixou o projeto em **Win32**) — **ausentes**.
- Todo diretório do `PATH` do usuário (variável de ambiente completa,
  ~40 diretórios, incluindo `System32`, `WINDOWS`, ferramentas de
  desenvolvimento instaladas) — **ausentes**.
- Instalação do Delphi/RAD Studio (`C:\Program Files (x86)\Embarcadero\`,
  busca recursiva por `libeay32.dll`/`ssleay32.dll`) — **ausentes**. O Indy
  10.6.3.11 embutido no Delphi 13 **não** traz essas DLLs junto — só o código
  Pascal que sabe carregá-las dinamicamente em runtime (`LoadLibrary`).
- Encontrado, mas **não utilizável para o Indy**: `C:\Windows\System32\
  libcrypto.dll` (64 bits, nome sem sufixo de versão, origem não identificada
  — não está na pasta do Delphi nem do Firebird) e, dentro de
  `Studio\37.0\RBuilder\Lib\Win32\` e `\Win64\`, os arquivos
  `libssl-1_1.dll`/`libcrypto-1_1.dll` (datados de 13/04/2018, ~2,6-3,1 MB) —
  esses são binários **OpenSSL 1.1.x** empacotados pelo ReportBuilder para uso
  próprio (nome de arquivo já indica a família 1.1), com nome de arquivo
  incompatível com o que o Indy desta versão procura (ver 11.2). Copiá-los
  para a pasta do executável **não resolveria** o spike sem renomear, e mesmo
  renomeados o header desta versão do Indy declaradamente não suporta a API
  OpenSSL 1.1.x (ver abaixo) — não foram testados por esse motivo.

**Inspeção do código-fonte do Indy 10.6.3.11 instalado** (`C:\Program Files
(x86)\Embarcadero\Studio\37.0\source\Indy10\Protocols\`):

- `IdSSLOpenSSLHeaders.pas`, por volta das linhas 19737-19745, declara em
  bloco `{$IFDEF WINDOWS}`:
  ```pascal
  SSL_DLL_name         = 'ssleay32.dll';   // {Do not localize}
  SSL_DLL_name_alt     = 'libssl32.dll';   // {Do not localize} (build mingw32)
  SSLCLIB_DLL_name     = 'libeay32.dll';   // {Do not localize}
  ```
  Esses são os **únicos** nomes de arquivo que a rotina de carregamento
  dinâmico (`LoadLibrary`) desta versão tenta no Windows — não há lógica
  alternativa para `libssl-1_1.dll`/`libcrypto-1_1.dll` (OpenSSL 1.1.x) nem
  para `libssl-3.dll`/`libcrypto-3.dll` (OpenSSL 3.x) em nenhum outro ponto do
  arquivo (busca textual pelos dois padrões de nome não retornou ocorrência
  alguma).
- O mesmo arquivo documenta a limitação explicitamente, em comentário de
  código (~linha 23117): *"verify the version is OpenSSL 1.0.2 or earlier, as
  OpenSSL 1.1.0 made MAJOR changes that we do not support yet..."* — e a
  constante embutida `OPENSSL_VERSION_TEXT` (linha ~5055) está fixada em
  `'OpenSSL 1.0.1e-fips 11 Feb 2013'`, confirmando que o header foi escrito
  contra a família 1.0.x/0.9.x do OpenSSL.
- `IdSSLOpenSSLHeaders_static.pas` (unit alternativa, para linkagem estática)
  também foi inspecionada — não referencia nomes de DLL Windows nem muda essa
  conclusão; é usada só sob a diretiva `STATICLOAD_OPENSSL`, não é o caminho
  padrão do `TIdSSLIOHandlerSocketOpenSSL`.

### 11.2 Conclusão verificável (sem execução real)

O Indy 10.6.3.11 bundled com o Delphi 13 Community, no caminho padrão
(`IdSSLOpenSSLHeaders.pas`, carregamento dinâmico), **só reconhece** os nomes
de arquivo `ssleay32.dll` + `libeay32.dll` (ou `libssl32.dll` como alt de
`ssleay32.dll`) — isto é, builds do **OpenSSL 1.0.2 ou anterior** compilados
para Windows, na arquitetura correta (Win32, conforme decisão da Seção 6).
Nenhuma DLL com esses nomes exatos foi encontrada em lugar algum verificado
nesta máquina. As DLLs OpenSSL 1.1.x que existem na máquina (do ReportBuilder)
não têm o nome certo e são de uma família de API que este header
declaradamente não suporta — não é uma questão de simplesmente renomear.

**Isso confirma, de forma real (não hipotética), a incerteza alta descrita em
R-02**: sem uma DLL correta disponível, `TIdSSLIOHandlerSocketOpenSSL` vai
falhar ao carregar SSL (`EIdOSSLLoadingLibraryError`/similar) assim que o
código tentar `Connect` com `UseTLS <> utNoTLSSupport`. O caminho "sem TLS"
(porta 25/2525, `UseTLS = utNoTLSSupport`) não depende dessas DLLs e deveria
funcionar sem instalar nada — mas ainda depende de uma conta
Mailtrap/Ethereal real para ser comprovado.

### 11.3 O que fica pendente (só o usuário pode fazer, com a IDE aberta)

Esta sessão de automação não consegue: (a) criar uma conta gratuita real no
Mailtrap ou Ethereal (serviço externo, exige e-mail/cadastro), (b) compilar e
rodar um projeto VCL de teste na IDE gráfica, nem (c) baixar e instalar as
DLLs OpenSSL corretas sem risco de "inventar" uma versão não verificada. Por
isso a tarefa fica `Bloqueada`, não `Concluída` nem com resultado forjado.

### 11.4 Roteiro passo a passo para quando o usuário puder testar

**Passo 0 — obter as DLLs corretas (se ausentes, como confirmado acima):**
Baixar um build Win32 do OpenSSL 1.0.2 compilado especificamente para uso com
Indy — historicamente distribuído em `indy.fulgan.com/SSL/` (pode estar fora
do ar; se sim, buscar um mirror atual, por exemplo o repositório
`IndySockets/OpenSSL-Binaries` no GitHub, que publica os mesmos binários
`libeay32.dll`/`ssleay32.dll` Win32 32-bit). Colocar as duas DLLs na mesma
pasta do `.exe` compilado (mais simples e não polui o `PATH`/`System32` da
máquina) — **não** commitar essas DLLs no repositório (binário de terceiros,
fora do escopo de versionamento de código-fonte).

**Passo 1 — criar a conta de teste:** Mailtrap (mailtrap.io, plano free,
"Email Testing" → inbox sandbox) ou Ethereal (ethereal.email, gera
usuário/senha temporários na hora, sem cadastro persistente). Copiar
host/porta/usuário/senha exibidos no painel.

**Passo 2 — projeto de teste mínimo (VCL Console ou Form Application),
componentes `TIdSMTP` + `TIdMessage` + `TIdAttachmentFile` +
`TIdSSLIOHandlerSocketOpenSSL`:**

- **Com TLS (STARTTLS explícito, porta 587 — modo mais comum no Mailtrap):**
  ```pascal
  IdSSLIOHandlerSocketOpenSSL1.SSLOptions.Method := sslvTLSv1_2; // header não
    // conhece sslvTLSv1_3; usar sslvSSLv23 se sslvTLSv1_2 for recusado, para
    // negociação automática pelo servidor
  IdSSLIOHandlerSocketOpenSSL1.SSLOptions.SSLVersions := [sslvTLSv1_2];
  IdSMTP1.IOHandler := IdSSLIOHandlerSocketOpenSSL1;
  IdSMTP1.Host := 'sandbox.smtp.mailtrap.io'; // ou host do Ethereal
  IdSMTP1.Port := 587;
  IdSMTP1.UseTLS := utUseExplicitTLS;
  IdSMTP1.AuthType := satDefault; // login/senha do Mailtrap/Ethereal
  IdSMTP1.Username := '<usuario do painel>';
  IdSMTP1.Password := '<senha do painel>'; // nunca commitar; só em INI/env, ADR-007/008
  ```
- **Sem TLS (para o cenário de fallback do spike, se o provedor permitir
  porta em texto puro — nem todo Mailtrap aceita; testar com a porta
  alternativa não-TLS informada no painel, se existir):**
  ```pascal
  IdSMTP1.IOHandler := nil; // ou TIdIOHandlerStack padrão
  IdSMTP1.Host := '<host>';
  IdSMTP1.Port := 25; // ou porta alternativa sem TLS do provedor
  IdSMTP1.UseTLS := utNoTLSSupport;
  ```
- **Mensagem com anexo PDF de teste:**
  ```pascal
  IdMessage1.From.Address := 'teste@erpvendas.local';
  IdMessage1.Recipients.EMailAddresses := '<endereço do inbox de teste>';
  IdMessage1.Subject := 'Teste Spike S1 - ERPVendas';
  IdMessage1.Body.Text := 'Anexo de teste.';
  TIdAttachmentFile.Create(IdMessage1.MessageParts, 'C:\Temp\teste.pdf');
  IdSMTP1.Connect;
  try
    IdSMTP1.Send(IdMessage1);
  finally
    IdSMTP1.Disconnect;
  end;
  ```

**Passo 3 — critério de aceite:** confirmar no inbox do Mailtrap/Ethereal que
o e-mail chegou com o anexo PDF, repetindo o teste nos dois modos (com e sem
TLS) e anotando aqui: porta exata usada, se `Connect` teve sucesso, mensagem
de erro completa (sem senha) em caso de falha, e nome/tamanho/origem exata das
DLLs que funcionaram.

**Passo 4 — reportar o resultado** (ao usuário decidir rodar de novo o
Executor, ou diretamente): atualizar esta Seção 11 com o resultado real
(sucesso/falha, parâmetros que funcionaram) e então marcar T02 como
`Concluída` em `TASK.md`. Se TLS não funcionar de forma alguma mesmo com as
DLLs corretas, seguir o "impacto se falhar" já previsto no `TASK.md` Seção 2
(usar Mailtrap sem TLS, documentar, e reestimar T48 sobre esse resultado).

### 11.5 Resultado real — evidência confirmada (fecha o critério de aceite de T02)

Testado em 2026-09-22, a partir do mesmo projeto "hello world", com conta
sandbox real criada no **Mailtrap** (`sandbox.smtp.mailtrap.io`, TLS
"Optional — STARTTLS on all ports", auth PLAIN/LOGIN/CRAM-MD5):

**DLLs OpenSSL 1.0.2 Win32** (`libeay32.dll` + `ssleay32.dll`, baixadas do
mirror `IndySockets/OpenSSL-Binaries` no GitHub) copiadas para a pasta do
`.exe` — **funcionaram**: nenhum erro de carregamento de SSL ocorreu.

**Cenário 1 — com TLS (porta 587, `UseTLS := utUseExplicitTLS`,
`IdSSLIOHandlerSocketOpenSSL1.SSLOptions.Method := sslvTLSv1_2`):**
`IdSMTP1.Connect` + `Send` **bem-sucedido**. E-mail "Teste Spike S1 - COM TLS"
recebido no inbox do Mailtrap, com o anexo `teste-relatorio.pdf` presente e
abrível ("Attachments (1)").

**Cenário 2 — sem TLS (porta 2525, `IdSMTP1.IOHandler := nil`,
`UseTLS := utNoTLSSupport`):** `Connect` + `Send` **bem-sucedido**. E-mail
"Teste Spike S1 - SEM TLS" recebido no inbox, também com o anexo PDF
confirmado.

**Nota de diagnóstico registrada durante o teste:** a 1ª tentativa falhou com
`EIdSMTPReplyError: Invalid credentials` — não foi problema de TLS/DLL, foi
senha copiada incompleta do painel do Mailtrap (campo vem mascarado,
`****xxxx`; é preciso revelar/copiar o valor completo antes de colar no
código). Depois de corrigir a senha, os dois cenários funcionaram de primeira.

**Conclusão do spike (fecha R-02):** com a DLL OpenSSL 1.0.2 Win32 correta
instalada junto ao executável, `TIdSMTP` + `TIdSSLIOHandlerSocketOpenSSL`
funciona normalmente com TLS explícito (porta 587) contra um provedor real
(Mailtrap); o caminho sem TLS (porta 2525) também funciona como fallback. Não
é necessário adotar o fallback "sem TLS" do "impacto se falhar" do `TASK.md`
Seção 2 — o caminho principal (com TLS) já está validado. Para T48
(`EmailSender` real), usar os mesmos parâmetros: DLLs OpenSSL 1.0.2 Win32
junto ao `.exe`, `sslvTLSv1_2`, `utUseExplicitTLS`, porta configurável pelo
INI (padrão 587).

### 11.6 Lote 12 / E-mail — notas de segurança e DevOps (SG12-02, SG12-05)

- **OpenSSL 1.0.2 está sem suporte (fim de vida desde 2019).** Usar a última
  da série, **1.0.2u** (`libeay32.dll` + `ssleay32.dll`, Win32). Uso restrito
  a cliente SMTP para o host fixo configurado. Origem registrada até agora:
  mirror `IndySockets/OpenSSL-Binaries` (GitHub), usado no spike T02 (§11.5).
  Versão exata e SHA-256 do pacote efetivamente usado: **a preencher na T61
  (build/pacote): registrar origem e SHA-256 das DLLs.** Migração futura:
  Indy/OpenSSL 1.1+.
- **Mailtrap/Ethereal só com dados fictícios.** Nunca usar e-mail, CPF ou PDF
  de cliente real na caixa de teste: ela retém as mensagens e é um terceiro
  externo (SG12-05).
- **Produção:** senha SMTP somente pela variável de ambiente
  `ERPV_SMTP_PASSWORD` (tem prioridade sobre o INI; ver
  `src/Core/ERPV.Core.Config.pas`), nunca no `erpvendas.ini`. SPF/DKIM/DMARC:
  ver README (SMTP).
