unit ERPV.UI.Tema;

{
  T68 (Lote 3) - AplicarTema / ConfigurarGrade / EstilizarBotao / Notificar
  (UX-SPEC.md Secao 3.2/3.3/8, ADR-011).

  Depende de (ja implementada, Concluida): ERPV.UI.Tokens (mesma tarefa,
  criada junto).

  ==========================================================================
  RESPONSABILIDADE DESTA UNIT
  ==========================================================================
  - AplicarTema: aplica o skin DevExpress Office2019Colorful (escolhido e
    confirmado em T01, ver docs/ambiente-licencas.md Secao 5) uma unica vez,
    no composition root/form principal (T13/T14), com fallback para
    LookAndFeel nativo se o skin nao existir/carregar - o app NUNCA falha
    por causa do skin (UX-SPEC Secao 3.2, R-UX-1).
  - ConfigurarGrade: helper unico de estilo de grade (zebra, cabecalho,
    linhas horizontais finas, sem indicador/agrupamento) para qualquer
    TcxCustomGridTableView (bound ou unbound) - nenhuma tela configura estilo
    de grade na mao.
  - EstilizarBotao: aplica um dos 3 papeis de botao (Primario/Secundario/
    Perigoso, UX-SPEC Secao 3.3) a um TcxButton.
  - Notificar: UNICA forma permitida de mensagem ao usuario no projeto a
    partir de T68 (TASK.md Secao 1 "UI", regra critica) - Info = banner
    inline nao bloqueante; Aviso/Erro/Pergunta = dialogo modal (botoes em
    portugues). Nenhuma outra unit de UI deste projeto deve chamar
    MessageDlg/TaskDialog diretamente dai em diante.

  ==========================================================================
  ADVERTENCIA IMPORTANTE SOBRE VERIFICACAO (mesma limitacao de T07/T12/T13)
  ==========================================================================
  Este ambiente de automacao nao compila Delphi nem tem acesso visual ao
  DevExpress Designer/IDE. Os nomes de unit/classe/propriedade DevExpress
  abaixo sao os documentados no manual/padrao de uso conhecido da
  ExpressQuantumGrid/ExpressSkins/ExpressEditors Library; foram usados com
  o maior cuidado possivel, mas PRECISAM ser confirmados pelo usuario na
  IDE (Code Insight/F1) antes/durante a primeira compilacao real. Cada
  assuncao esta documentada no ponto exato do codigo onde e usada, para
  facilitar a conferencia. Se algum nome divergir nesta versao (DevExpress
  VCL 26.1.4, ver docs/ambiente-licencas.md), o ajuste e local (só a
  linha/propriedade em questao), a estrutura logica (skin+fallback, estilo
  de grade via evento de estilo por linha, 3 papeis de botao, Notificar
  banner/modal) nao muda.

  ==========================================================================
  AplicarTema - decisoes de implementacao
  ==========================================================================
  - Skin efetivo: 'Office2019Colorful' (1o da ordem de preferencia do
    UX-SPEC Secao 3.2, confirmado instalado no trial - ver
    docs/ambiente-licencas.md Secao 5, decisao de T01, reaproveitada aqui
    sem reabrir escolha).
  - Units DevExpress (confirmadas por compilacao real na IDE, T68 - a
    suposicao original deste cabecalho estava errada, ver abaixo):
    `dxSkinsForm` (motor de skins/`TdxSkinController`, sempre necessario) e
    `dxSkinOffice2019Colorful` (recurso do skin escolhido) - ambas fazem
    parte do pacote `dxSkinsCoreRS37`/`dxSkinOffice2019ColorfulRS37`
    (Runtime Packages do projeto), mas **"dxSkinsCore" nao e nome de unit**,
    e sim so do pacote - o `.dpk` real do pacote declara
    "contains dxSkinsForm[...]"; a suposicao original deste cabecalho (unit
    `dxSkinsCore`) causava "Undeclared identifier: TdxSkinController" na
    compilacao real, corrigido para `dxSkinsForm`. Classe usada:
    `TdxSkinController` (propriedades `NativeStyle: Boolean` e
    `SkinName: string`, confirmadas no header/`.hpp` do pacote) - basta
    existir UMA instancia deste componente na aplicacao para que todos os
    controles DevExpress passem a pintar pelo skin (comportamento
    documentado da ExpressSkins Library); nenhuma outra unit precisa tocar
    em skin.
  - Guarda de compilacao para o teste de fallback do criterio de aceite
    ("removendo os skins do uses o app abre sem erro"): a dependencia das
    duas units de skin fica isolada atras da diretiva
    `{$DEFINE ERPV_SKIN_DISPONIVEL` logo abaixo. Para reproduzir o cenario
    do criterio de aceite manualmente na IDE: comentar essa `{$DEFINE` +
    as duas linhas `dxSkinsForm`/`dxSkinOffice2019Colorful` do `uses` da
    implementation, recompilar - `AplicarTema` cai direto no fallback
    nativo (ninguem mais referencia classe de skin), sem alterar nenhuma
    outra unit do projeto.
  - Fallback nativo (skin ausente, `{$UNDEF ERPV_SKIN_DISPONIVEL`, OU
    skin presente mas falha em tempo de execucao - ex.: trial expirado):
    `TcxLookAndFeelController` (unit `cxLookAndFeels`) com
    `Kind := lfUltraFlat` e `NativeStyle := False`, conforme UX-SPEC
    Secao 3.2. O resultado visual fino (cores/zebra/selecao) continua
    vindo dos tokens via ConfigurarGrade/EstilizarBotao, que nao dependem
    do skin estar ativo.
  - Idempotente: chamado uma unica vez pelo composition root (T13/T14);
    chamadas repetidas sao no-op (guarda por variavel de unit
    `TemaJaAplicado`).

  ==========================================================================
  ConfigurarGrade - decisoes de implementacao
  ==========================================================================
  - Parametro `TcxCustomGridTableView` (unit `cxGridCustomTableView`) -
    ancestral comum de `TcxGridTableView` (unbound, unit `cxGridTableView`)
    e `TcxGridDBTableView` (bound a TDataSet, unit `cxGridDBTableView`,
    usado pelos repositorios de T17/T21/T25/T37 mais adiante) - assim o
    mesmo helper serve para o form de teste (unbound) e para as telas reais
    (bound), sem duplicar codigo.
  - Zebra: `Styles.ContentOdd`/`Styles.ContentEven` + `Styles.UseOddEvenStyles
    := bTrue` (achado real de compilacao, T68 - a suposicao original deste
    cabecalho, um evento `OnStylesGetContentStyle` direto na view, nao
    existe; a API real e mais simples e ja fica em
    `TcxCustomGridTableViewStyles`, base comum de bound/unbound, sem
    downcast). Dois `TcxStyle` (par/impar) criados uma unica vez e
    reaproveitados por todas as grades (variaveis de unit, nao expostas na
    interface). `Styles.Header` (cabecalho) e `OptionsView.Indicator/
    GroupByBox/ColumnAutoWidth/GridLines` so existem nas classes concretas
    `TcxGridTableViewStyles`/`TcxGridTableOptionsView` (comuns as duas
    subclasses reais usadas neste projeto - `TcxGridTableView` unbound e
    `TcxGridDBTableView` bound), por isso tem downcast seguro isolado
    dentro de `ConfigurarGrade`.
  - Demais ajustes: sem indicador de linha, sem agrupamento, sem selecao de
    celula (selecao de linha inteira), sem grade vertical forte (so
    horizontal 1px, token `clERPVLinhaGrade`), texto do "vazio" plugado via
    `NoDataToDisplayInfoText` (texto passado por quem chama, tela a tela,
    conforme UX-SPEC Secao 4.1 - esta unit so oferece o parametro opcional).

  ==========================================================================
  EstilizarBotao - decisoes de implementacao
  ==========================================================================
  - Parametro `TcxButton` (unit `cxButtons`). Achado real de compilacao
    (T68): `TcxButton` NAO tem propriedade `Style`/`TcxButtonStyle` (a
    suposicao original deste cabecalho estava errada) - a customizacao de
    cor por estado vem de `Colors: TcxButtonColors`
    (Normal/NormalText/Hot/HotText/Pressed/PressedText/Disabled/
    DisabledText), cada uma so tendo efeito se marcada no set
    `AssignedColors` (senao o LookAndFeel/skin decide). Nao ha cor de borda
    separada nessa classe - o efeito "contorno" de Secundario/Perigoso fica
    por conta de Normal=Superficie (fundo claro) + NormalText na cor do
    papel; confirmar visualmente na IDE (roteiro de T68) se o resultado
    bate com UX-SPEC 3.3 ou se precisa de ajuste fino.
  - 3 papeis (UX-SPEC Secao 3.3): Primario = preenchido com
    `clERPVDestaque`/`clERPVDestaqueHover`, texto branco, `fsBold`;
    Secundario = fundo claro, texto `clERPVTextoPrincipal`;
    Perigoso = fundo claro, texto `clERPVErroTexto` - nunca preenchido
    (UX-SPEC 3.3: "perigoso... nunca preenchido").

  ==========================================================================
  Notificar - decisoes de implementacao
  ==========================================================================
  - Info = banner inline nao bloqueante (UX-SPEC 3.3-a): painel `TPanel`
    criado dinamicamente, ancorado no topo do form/container informado (ou
    do form ativo, se nenhum for informado), cores dos tokens de Info,
    auto-oculta em ~6s (TTimer) ou ao clicar - nunca bloqueia a UI.
  - Aviso/Erro/Pergunta = dialogo modal (UX-SPEC 3.3-a): `CreateMessageDialog`
    (unit `Vcl.Dialogs`, API publica e estavel do VCL, nao exclusiva de
    versao) com os botoes renomeados para portugues ("OK"/"Sim"/"Nao"),
    unico ponto do projeto autorizado a criar dialogo modal de mensagem -
    nenhuma outra unit de UI deve chamar MessageDlg/TaskDialog direto dai
    em diante (mesmo padrao ja usado por `ERPV.Core.Erros.TTratadorDeExcecoes`
    para excecao nao tratada, que continua sendo o unico outro ponto
    autorizado, por ser generico de ultima instancia - ver T11).
  - Pergunta devolve `Boolean` (True = usuario confirmou/"Sim") para quem
    chamou decidir a acao; os demais tipos sempre devolvem True (mensagem
    exibida com sucesso).
}

{$DEFINE ERPV_SKIN_DISPONIVEL}

interface

uses
  System.SysUtils, System.Classes, System.UITypes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  ERPV.UI.Tokens, cxGrid, cxGridCustomTableView, cxGridDBTableView, cxGridCustomView,
  cxButtons;

type
  /// <summary>Papel visual de um botao (UX-SPEC Secao 3.3).</summary>
  TUIPapelBotao = (upbPrimario, upbSecundario, upbPerigoso);

  /// <summary>
  ///   Tipo de notificacao ao usuario (UX-SPEC Secao 3.3/4.3). Info = banner;
  ///   Aviso/Erro/Pergunta = modal.
  /// </summary>
  TUITipoNotificacao = (utnInfo, utnAviso, utnErro, utnPergunta);

/// <summary>
///   Aplica o skin DevExpress escolhido (Office2019Colorful) uma unica vez,
///   com fallback para LookAndFeel nativo (lfUltraFlat) se o skin nao
///   existir/carregar. Chamar uma unica vez no composition root/form
///   principal (T13/T14). Idempotente (chamadas repetidas sao no-op).
/// </summary>
procedure AplicarTema;

/// <summary>
///   Estiliza uma view de grade DevExpress (zebra, cabecalho, sem
///   indicador/agrupamento, linhas horizontais finas) conforme UX-SPEC
///   Secao 3.2. AView aceita tanto TcxGridTableView (unbound) quanto
///   TcxGridDBTableView (bound a TDataSet).
/// </summary>
procedure ConfigurarGrade(AView: TcxCustomGridTableView);

/// <summary>
///   Aplica o papel visual (Primario/Secundario/Perigoso) a um TcxButton,
///   conforme UX-SPEC Secao 3.3.
/// </summary>
procedure EstilizarBotao(ABotao: TcxButton; const APapel: TUIPapelBotao);

/// <summary>
///   Unica forma permitida de mensagem ao usuario no projeto (TASK.md
///   Secao 1 "UI"). Info = banner inline (nao bloqueante, AOwnerBanner
///   informa o container onde exibir; se omitido, usa o form ativo).
///   Aviso/Erro/Pergunta = dialogo modal, botoes em portugues. Devolve
///   True em utnPergunta quando o usuario confirma ("Sim"); nos demais
///   tipos sempre devolve True.
/// </summary>
function Notificar(const ATipo: TUITipoNotificacao; const ATexto: string;
  AOwnerBanner: TWinControl = nil): Boolean;

implementation

uses
  Winapi.Windows, Winapi.Messages,
  {$IFDEF ERPV_SKIN_DISPONIVEL}
  // TdxSkinController mora em dxSkinsForm (nao em "dxSkinsCore" - esse e o
  // nome do PACOTE dxSkinsCoreRS37.dpk, nao de uma unit; confirmado no
  // .dpk real do pacote, que declara "contains dxSkinsForm" entre outras).
  // Achado real de compilacao (T68, verificacao manual do usuario na IDE),
  // nao suposicao.
  dxSkinsForm, dxSkinOffice2019Colorful,
  {$ENDIF}
  dxCore, cxLookAndFeels, cxStyles, cxGraphics, cxGridTableView;

const
  ERPVSkinEfetivo = 'Office2019Colorful';
  ERPVBannerAltura = 32;
  ERPVBannerAutoOcultaMs = 6000;

var
  TemaJaAplicado: Boolean = False;

{ ==========================================================================
  AplicarTema
  ========================================================================== }

procedure AplicarSkinComFallback;
{$IFDEF ERPV_SKIN_DISPONIVEL}
var
  SkinController: TdxSkinController;
{$ENDIF}
var
  LookAndFeelController: TcxLookAndFeelController;
begin
  {$IFDEF ERPV_SKIN_DISPONIVEL}
  try
    // Uma unica instancia de TdxSkinController na aplicacao ja basta para
    // que todos os controles DevExpress passem a pintar via skin
    // (comportamento documentado da ExpressSkins Library) - nao precisa
    // ser atribuido a cada control individualmente. Confirmado por
    // execucao real (T68, teste diagnostico sem este try/except): a
    // criacao/SkinName nao lanca excecao neste ambiente - o skin e
    // aplicado sem erro (a aparencia mais palida observada nos controles
    // de teste nao e falha de carregamento do skin, ver nota de status
    // de T68 no TASK.md).
    SkinController := TdxSkinController.Create(Application);
    SkinController.NativeStyle := False;
    SkinController.SkinName := ERPVSkinEfetivo;
    Exit; // skin aplicado com sucesso, nao cai no fallback abaixo
  except
    // Skin presente no uses mas falhou em tempo de execucao (ex.: trial
    // expirado, recurso corrompido) - cai no fallback nativo abaixo, sem
    // propagar erro (R-UX-1: "impacto baixo, ~1h extra de estilos" ja
    // assumido pelo UX-SPEC; aqui o custo e zero, so nao ha skin).
  end;
  {$ENDIF}

  // Fallback nativo (UX-SPEC Secao 3.2): LookAndFeel Kind=lfUltraFlat,
  // NativeStyle=False. O app abre normalmente, so sem o skin colorido -
  // aparencia degrada, nada quebra (RP-7).
  LookAndFeelController := TcxLookAndFeelController.Create(Application);
  LookAndFeelController.NativeStyle := False;
  // Kind fica direto no controller (nao existe "LookAndFeelController.
  // LookAndFeel.Kind" - achado real de compilacao, T68; Kind/NativeStyle
  // sao propriedades de TcxCustomLookAndFeelController, confirmado no
  // header/.hpp do pacote cxLibraryRS37).
  LookAndFeelController.Kind := lfUltraFlat;
end;

procedure AplicarTema;
begin
  if TemaJaAplicado then
    Exit; // idempotente - so o composition root deve chamar, mas protege
          // contra chamada acidental duplicada (ex.: reentrancia de testes)
  AplicarSkinComFallback;
  TemaJaAplicado := True;
end;

{ ==========================================================================
  ConfigurarGrade
  ========================================================================== }

// Guarda os dois TcxStyle (linha par/impar) reaproveitados por todas as
// grades da aplicacao - criados sob demanda, liberados so no encerramento
// do processo (Finalization), sem custo perceptivel (2 objetos leves).
// Achado real de compilacao (T68): a abordagem original (evento
// "OnStylesGetContentStyle" direto na view) nao existe - a API real de
// zebra do ExpressQuantumGrid e mais simples, via Styles.ContentOdd/
// ContentEven + Styles.UseOddEvenStyles (confirmado no header do pacote
// cxGridRS37), sem precisar de classe auxiliar nem evento manual.
var
  FEstiloContentPar: TcxStyle;
  FEstiloContentImpar: TcxStyle;
  FEstiloSelecao: TcxStyle;
  FEstiloHeader: TcxStyle;

procedure GarantirEstilosZebra;
begin
  if FEstiloContentPar = nil then
  begin
    FEstiloContentPar := TcxStyle.Create(nil);
    FEstiloContentPar.Color := clERPVSuperficie;
    FEstiloContentPar.TextColor := clERPVTextoPrincipal;
  end;
  if FEstiloContentImpar = nil then
  begin
    FEstiloContentImpar := TcxStyle.Create(nil);
    FEstiloContentImpar.Color := clERPVZebra;
    FEstiloContentImpar.TextColor := clERPVTextoPrincipal;
  end;
end;

// Achado real de compilacao/execucao (T68): "AView.Styles.Selection" pode
// devolver nil ate ser explicitamente atribuido (criado sob demanda pela
// classe interna do pacote) - fazer "AView.Styles.Selection.Color := X"
// direto crashava com EAccessViolation em cxLibraryRS37 (leitura de nil).
// Mesmo padrao da zebra: cria-se um TcxStyle proprio e ATRIBUI via
// Styles.Selection := ..., nunca le o valor antigo para mutar.
procedure GarantirEstiloSelecao;
begin
  if FEstiloSelecao = nil then
  begin
    FEstiloSelecao := TcxStyle.Create(nil);
    FEstiloSelecao.Color := clERPVSelecaoLinha;
    FEstiloSelecao.TextColor := clERPVTextoPrincipal;
  end;
end;

// Mesmo achado/padrao de GarantirEstiloSelecao acima, aplicado a Header
// (tambem GetValue/SetValue na classe do pacote - mesmo risco de nil).
procedure GarantirEstiloHeader;
begin
  if FEstiloHeader = nil then
  begin
    FEstiloHeader := TcxStyle.Create(nil);
    FEstiloHeader.Color := clERPVSuperficie;
    FEstiloHeader.TextColor := clERPVTextoSecundario;
    FEstiloHeader.Font.Name := ERPVFontePrincipal;
    FEstiloHeader.Font.Size := ERPVTamCabecalhoCol;
    FEstiloHeader.Font.Style := [fsBold];
  end;
end;

procedure ConfigurarGrade(AView: TcxCustomGridTableView);
var
  EstilosCompletos: TcxGridTableViewStyles;
  OpcoesViewCompletas: TcxGridTableOptionsView;
begin
  // Sem indicador de linha, sem agrupamento, sem rodape desnecessario
  // (UX-SPEC Secao 3.2 "cxGrid: TableView sem indicador, sem
  // agrupamento/rodape desnecessarios"). Mesmo caso de "Header" abaixo:
  // Indicator/GroupByBox/ColumnAutoWidth/GridLines so existem na classe
  // concreta TcxGridTableOptionsView (achado real de compilacao, T68),
  // nao na base abstrata do parametro AView - downcast seguro, mesmo par
  // de subclasses reais (TcxGridTableView/TcxGridDBTableView).
  if AView.OptionsView is TcxGridTableOptionsView then
  begin
    OpcoesViewCompletas := TcxGridTableOptionsView(AView.OptionsView);
    OpcoesViewCompletas.Indicator := False;
    OpcoesViewCompletas.GroupByBox := False;
    OpcoesViewCompletas.ColumnAutoWidth := True;
    OpcoesViewCompletas.GridLines := glHorizontal; // so linha horizontal fina, sem vertical forte
  end;
  AView.OptionsSelection.CellSelect := False;      // selecao de linha inteira (padrao de lista) - na base, sem downcast
  AView.OptionsData.Editing := False;           // listas somente leitura (edicao real e nas telas de edicao) - na base, sem downcast

  // Zebra (UX-SPEC "zebra #F8FAFC"): ContentOdd/ContentEven + flag - ja
  // disponiveis em TcxCustomGridTableViewStyles (base comum de bound/
  // unbound), sem precisar de downcast.
  GarantirEstilosZebra;
  AView.Styles.ContentEven := FEstiloContentPar;
  AView.Styles.ContentOdd := FEstiloContentImpar;
  AView.Styles.UseOddEvenStyles := bTrue;

  // Selecao de linha (UX-SPEC "selecao #DCEBFA"): tambem na base comum.
  // Atribuicao direta (nunca ler o valor antigo para mutar - ver
  // GarantirEstiloSelecao acima).
  GarantirEstiloSelecao;
  AView.Styles.Selection := FEstiloSelecao;

  // Cabecalho: "Header" so existe na classe concreta TcxGridTableViewStyles
  // (comum a TcxGridTableView unbound e TcxGridDBTableView bound - ambas
  // as unicas subclasses reais de TcxCustomGridTableView usadas neste
  // projeto), nao na base abstrata do parametro AView - downcast seguro
  // aqui, documentado por ser um achado real de compilacao (T68). Mesma
  // atribuicao direta de GarantirEstiloHeader (nunca mutar o valor lido).
  if AView.Styles is TcxGridTableViewStyles then
  begin
    EstilosCompletos := TcxGridTableViewStyles(AView.Styles);
    GarantirEstiloHeader;
    EstilosCompletos.Header := FEstiloHeader;
  end;

  // Mesmo achado de EstilizarBotao (T68): forcar o redesenho para nao
  // esperar o proximo evento do sistema aplicar os estilos configurados
  // aqui (Styles/Options so tomando efeito visual depois de um repaint).
  AView.Invalidate;
end;

{ ==========================================================================
  EstilizarBotao
  ========================================================================== }

procedure EstilizarBotao(ABotao: TcxButton; const APapel: TUIPapelBotao);
begin
  // TcxButton nao tem propriedade "Style" (achado real de compilacao, T68 -
  // a suposicao original deste cabecalho estava errada). A customizacao de
  // cor por estado vem de `ABotao.Colors` (TcxButtonColors: Normal/
  // NormalText/Hot/HotText/Pressed/PressedText/Disabled/DisabledText),
  // cada uma só tendo efeito se marcada em `AssignedColors` (senao o
  // LookAndFeel/skin decide a cor). TcxButtonColors nao expoe cor de borda
  // separada - a aparencia "contorno" de Secundario/Perigoso fica por conta
  // de Normal=Superficie (fundo branco) + NormalText na cor do papel; se o
  // skin ativo nao desenhar borda visivel o bastante nesse caso, e um
  // ajuste fino de UX a confirmar visualmente na IDE (roteiro de T68, item
  // 4), nao um erro de compilacao.
  ABotao.Font.Name := ERPVFontePrincipal;
  ABotao.Font.Size := ERPVTamCorpo;
  ABotao.Height := ERPVAlturaControle;

  // Causa provavel da pendencia visual (a) de T68, vista na 1a tela real (T15):
  // com o skin global ativo o TcxButton pinta via skin e IGNORA Colors (so o
  // hover aparecia; o primario ficava sem fundo, com texto branco ilegivel).
  // LookAndFeel proprio, sem skin e nao nativo, faz Colors valerem. Atribuir
  // explicitamente marca o valor como "assigned", entao nao herda do master.
  ABotao.LookAndFeel.NativeStyle := False;
  ABotao.LookAndFeel.SkinName := '';
  ABotao.LookAndFeel.Kind := lfFlat;

  case APapel of
    upbPrimario:
      begin
        // Preenchido, texto branco, negrito (UX-SPEC 3.3: primario sempre o
        // mais a direita no rodape de modal / primeiro na barra de lista).
        ABotao.Colors.AssignedColors := [cxbcNormal, cxbcNormalText, cxbcHot,
          cxbcHotText, cxbcPressed, cxbcPressedText];
        ABotao.Colors.Normal := clERPVDestaque;
        ABotao.Colors.NormalText := clWhite;
        ABotao.Colors.Hot := clERPVDestaqueHover;
        ABotao.Colors.HotText := clWhite;
        ABotao.Colors.Pressed := clERPVDestaqueHover;
        ABotao.Colors.PressedText := clWhite;
        ABotao.Font.Color := clWhite;
        ABotao.Font.Style := [fsBold];
      end;
    upbSecundario:
      begin
        // Contorno, texto principal (UX-SPEC 3.3: secundario ao lado do
        // primario).
        ABotao.Colors.AssignedColors := [cxbcNormal, cxbcNormalText, cxbcHot,
          cxbcHotText, cxbcPressed, cxbcPressedText];
        ABotao.Colors.Normal := clERPVSuperficie;
        ABotao.Colors.NormalText := clERPVTextoPrincipal;
        ABotao.Colors.Hot := clERPVFundoApp;
        ABotao.Colors.HotText := clERPVTextoPrincipal;
        ABotao.Colors.Pressed := clERPVFundoApp;
        ABotao.Colors.PressedText := clERPVTextoPrincipal;
        ABotao.Font.Color := clERPVTextoPrincipal;
        ABotao.Font.Style := [];
      end;
    upbPerigoso:
      begin
        // Contorno vermelho, nunca preenchido (UX-SPEC 3.3: "perigoso...
        // nunca preenchido, sempre com confirmacao" - a confirmacao em si e
        // responsabilidade de quem chama, via Notificar(utnPergunta, ...)
        // antes de disparar a acao perigosa).
        ABotao.Colors.AssignedColors := [cxbcNormal, cxbcNormalText, cxbcHot,
          cxbcHotText, cxbcPressed, cxbcPressedText];
        ABotao.Colors.Normal := clERPVSuperficie;
        ABotao.Colors.NormalText := clERPVErroTexto;
        ABotao.Colors.Hot := clERPVErroFundo;
        ABotao.Colors.HotText := clERPVErroTexto;
        ABotao.Colors.Pressed := clERPVErroFundo;
        ABotao.Colors.PressedText := clERPVErroTexto;
        ABotao.Font.Color := clERPVErroTexto;
        ABotao.Font.Style := [];
      end;
  end;

  // Achado real de execucao (T68): a cor do estado Normal (parado) so
  // aparecia depois de um redesenho (ex.: passar o mouse por cima) -
  // Invalidate forca o repaint com as cores ja aplicadas, sem esperar o
  // proximo evento do sistema.
  ABotao.Invalidate;
end;

{ ==========================================================================
  Notificar
  ========================================================================== }

// TNotifyEvent (OnClick/OnTimer) e "of object" - metodo vinculado a uma
// instancia, NAO aceita procedure anonima direto (achado real de
// compilacao, T68: "E2010 Incompatible types: TNotifyEvent e Procedure").
// TERPVFechadorDeBanner e o metodo de instancia real usado como handler.
// Herda de TComponent especificamente para poder ter o Painel como Owner
// (ExibirBannerInfo cria com Create(Painel) mais abaixo) - assim, quando o
// Painel for liberado (por este mesmo Fechar, ou pelo Host ao ser
// destruido), o proprio Fechador e liberado automaticamente pelo mecanismo
// padrao de ownership de TComponent, sem vazamento. Chamar FPainel.Free
// de dentro de um metodo deste proprio objeto (que sera destruido junto)
// e seguro desde que nada mais acesse Self/campos depois - e o caso aqui
// (nenhuma instrucao depois do Free).
type
  TERPVFechadorDeBanner = class(TComponent)
  private
    FPainel: TPanel;
  public
    constructor Create(APainel: TPanel); reintroduce;
    procedure Fechar(Sender: TObject);
  end;

constructor TERPVFechadorDeBanner.Create(APainel: TPanel);
begin
  inherited Create(APainel); // APainel = Owner (ownership, libera este objeto junto)
  FPainel := APainel;
end;

procedure TERPVFechadorDeBanner.Fechar(Sender: TObject);
begin
  if Assigned(FPainel) then
    FPainel.Free; // libera o Painel e, por ownership, este TERPVFechadorDeBanner tambem
end;

procedure ExibirBannerInfo(const ATexto: string; AOwnerBanner: TWinControl);
var
  Host: TWinControl;
  Painel: TPanel;
  Rotulo: TLabel;
  Temporizador: TTimer;
  Fechador: TERPVFechadorDeBanner;
begin
  Host := AOwnerBanner;
  if Host = nil then
  begin
    if Assigned(Screen.ActiveForm) then
      Host := Screen.ActiveForm
    else
      Host := Application.MainForm;
  end;
  if Host = nil then
    Exit; // sem host algum (ex.: chamado antes de qualquer form existir) - no-op

  Painel := TPanel.Create(Host);
  Painel.Parent := Host;
  Painel.Align := alTop;
  Painel.BevelOuter := bvNone;
  Painel.Height := ERPVBannerAltura;
  Painel.Color := clERPVInfoFundo;
  Painel.Cursor := crHandPoint;
  Painel.Hint := 'Clique para fechar';
  Painel.ShowHint := True;

  Rotulo := TLabel.Create(Painel);
  Rotulo.Parent := Painel;
  Rotulo.Align := alClient;
  Rotulo.Layout := tlCenter;
  Rotulo.Alignment := taCenter;
  Rotulo.Font.Name := ERPVFontePrincipal;
  Rotulo.Font.Size := ERPVTamCorpo;
  Rotulo.Font.Color := clERPVInfoTexto;
  Rotulo.Caption := 'i  ' + ATexto; // icone real (ERPVIconeInfo, T69) plugado nas bases de form
  Rotulo.Transparent := True;

  // Fechador e criado com o Painel como Owner: quando o Painel for liberado
  // (Free chamado por Fechar, ou pelo proprio Host ao ser destruido), o
  // Fechador tambem e liberado automaticamente - sem vazamento.
  Fechador := TERPVFechadorDeBanner.Create(Painel);

  Temporizador := TTimer.Create(Painel);
  Temporizador.Interval := ERPVBannerAutoOcultaMs;
  Temporizador.OnTimer := Fechador.Fechar;
  Temporizador.Enabled := True;

  Painel.OnClick := Fechador.Fechar;
  Rotulo.OnClick := Fechador.Fechar;

  Painel.BringToFront;
end;

function ExibirDialogoModal(const ATipo: TUITipoNotificacao; const ATexto: string): Boolean;
var
  Dlg: TForm;
  BotaoOK, BotaoSim, BotaoNao: TComponent;
begin
  Result := True;
  case ATipo of
    utnAviso:
      begin
        Dlg := CreateMessageDialog(ATexto, mtWarning, [mbOK]);
        try
          BotaoOK := Dlg.FindComponent('OK');
          if Assigned(BotaoOK) and (BotaoOK is TButton) then
            TButton(BotaoOK).Caption := 'OK';
          Dlg.ShowModal;
        finally
          Dlg.Free;
        end;
      end;
    utnErro:
      begin
        Dlg := CreateMessageDialog(ATexto, mtError, [mbOK]);
        try
          BotaoOK := Dlg.FindComponent('OK');
          if Assigned(BotaoOK) and (BotaoOK is TButton) then
            TButton(BotaoOK).Caption := 'OK';
          Dlg.ShowModal;
        finally
          Dlg.Free;
        end;
      end;
    utnPergunta:
      begin
        Dlg := CreateMessageDialog(ATexto, mtConfirmation, [mbYes, mbNo]);
        try
          BotaoSim := Dlg.FindComponent('Yes');
          if Assigned(BotaoSim) and (BotaoSim is TButton) then
            TButton(BotaoSim).Caption := 'Sim';
          BotaoNao := Dlg.FindComponent('No');
          if Assigned(BotaoNao) and (BotaoNao is TButton) then
          begin
            TButton(BotaoNao).Caption := 'Não';
            Dlg.ActiveControl := TButton(BotaoNao);
          end;
          Result := Dlg.ShowModal = mrYes;
        finally
          Dlg.Free;
        end;
      end;
  else
    Result := True; // utnInfo nunca chega aqui (tratado em Notificar)
  end;
end;

function Notificar(const ATipo: TUITipoNotificacao; const ATexto: string;
  AOwnerBanner: TWinControl = nil): Boolean;
begin
  case ATipo of
    utnInfo:
      begin
        ExibirBannerInfo(ATexto, AOwnerBanner);
        Result := True;
      end;
  else
    Result := ExibirDialogoModal(ATipo, ATexto);
  end;
end;

initialization

finalization
  FreeAndNil(FEstiloContentPar);
  FreeAndNil(FEstiloContentImpar);
  FreeAndNil(FEstiloSelecao);
  FreeAndNil(FEstiloHeader);

end.
