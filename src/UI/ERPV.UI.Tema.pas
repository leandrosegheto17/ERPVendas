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
  - Units DevExpress assumidas (a confirmar no `uses` do projeto real):
    `dxSkinsCore` (motor de skins, sempre necessario) e
    `dxSkinOffice2019Colorful` (recurso do skin escolhido) - mesmo par de
    pacotes ja apontado em docs/ambiente-licencas.md Secao 5
    ("dxSkinOffice2019Colorful" + "dxSkinsCore"). Classe usada:
    `TdxSkinController` (propriedades `NativeStyle: Boolean` e
    `SkinName: string`) - basta existir UMA instancia deste componente na
    aplicacao para que todos os controles DevExpress passem a pintar pelo
    skin (comportamento documentado da ExpressSkins Library); nenhuma
    outra unit precisa tocar em skin.
  - Guarda de compilacao para o teste de fallback do criterio de aceite
    ("removendo os skins do uses o app abre sem erro"): a dependencia das
    duas units de skin fica isolada atras da diretiva
    `{$DEFINE ERPV_SKIN_DISPONIVEL}` logo abaixo. Para reproduzir o cenario
    do criterio de aceite manualmente na IDE: comentar essa `{$DEFINE}` +
    as duas linhas `dxSkinsCore`/`dxSkinOffice2019Colorful` do `uses` da
    implementation, recompilar - `AplicarTema` cai direto no fallback
    nativo (ninguem mais referencia classe de skin), sem alterar nenhuma
    outra unit do projeto.
  - Fallback nativo (skin ausente, `{$UNDEF ERPV_SKIN_DISPONIVEL}`, OU
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
  - Zebra: `OnStylesGetContentStyle` (evento `TcxGridGetCellStyleEvent`,
    assinatura `procedure(Sender: TcxCustomGridTableView; AItem:
    TcxCustomGridTableItem; ARecordIndex: Integer; var AStyle: TcxStyle) of
    object`) - padrao documentado da ExpressQuantumGrid para alternar cor
    de linha; usa dois `TcxStyle` (par/impar) criados uma unica vez e
    reaproveitados (classe auxiliar interna `TERPVEstiloZebra`, nao
    exposta na interface desta unit).
  - Demais ajustes: sem indicador de linha, sem agrupamento, sem selecao de
    celula (selecao de linha inteira), sem grade vertical forte (so
    horizontal 1px, token `clERPVLinhaGrade`), texto do "vazio" plugado via
    `NoDataToDisplayInfoText` (texto passado por quem chama, tela a tela,
    conforme UX-SPEC Secao 4.1 - esta unit so oferece o parametro opcional).

  ==========================================================================
  EstilizarBotao - decisoes de implementacao
  ==========================================================================
  - Parametro `TcxButton` (unit `cxButtons`), propriedade `Style: TcxButtonStyle`
    (cor de fundo/borda/fonte) - se esta propriedade nao existir tal como
    assumida nesta versao, o ajuste fica isolado dentro desta funcao (nomes
    documentados no comentario do corpo da funcao).
  - 3 papeis (UX-SPEC Secao 3.3): Primario = preenchido com
    `clERPVDestaque`/`clERPVDestaqueHover`, texto branco, `fsBold`;
    Secundario = contorno `clERPVBordaCampo`, texto `clERPVTextoPrincipal`;
    Perigoso = contorno `clERPVErroTexto`, texto `clERPVErroTexto` - nunca
    preenchido (UX-SPEC 3.3: "perigoso... nunca preenchido").

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
  cxGridCustomView, cxGridCustomTableView, cxButtons,
  ERPV.UI.Tokens;

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
  dxSkinsCore, dxSkinOffice2019Colorful,
  {$ENDIF}
  cxLookAndFeels, cxStyles, cxGraphics;

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
    // ser atribuido a cada control individualmente.
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
  LookAndFeelController.LookAndFeel.Kind := lfUltraFlat;
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

type
  // Guarda os dois TcxStyle (linha par/impar) reaproveitados por todas as
  // grades da aplicacao - criados sob demanda, liberados so no encerramento
  // do processo (Finalization), sem custo perceptivel (2 objetos leves).
  TERPVEstiloZebra = class
  private
    class var FEstiloPar: TcxStyle;
    class var FEstiloImpar: TcxStyle;
    class procedure Garantir;
  public
    class procedure AoObterEstiloConteudo(Sender: TcxCustomGridTableView;
      AItem: TcxCustomGridTableItem; ARecordIndex: Integer; var AStyle: TcxStyle);
    class procedure Liberar;
  end;

class procedure TERPVEstiloZebra.Garantir;
begin
  if FEstiloPar = nil then
  begin
    FEstiloPar := TcxStyle.Create(nil);
    FEstiloPar.Color := clERPVSuperficie;
    FEstiloPar.TextColor := clERPVTextoPrincipal;
  end;
  if FEstiloImpar = nil then
  begin
    FEstiloImpar := TcxStyle.Create(nil);
    FEstiloImpar.Color := clERPVZebra;
    FEstiloImpar.TextColor := clERPVTextoPrincipal;
  end;
end;

class procedure TERPVEstiloZebra.AoObterEstiloConteudo(
  Sender: TcxCustomGridTableView; AItem: TcxCustomGridTableItem;
  ARecordIndex: Integer; var AStyle: TcxStyle);
begin
  if ARecordIndex < 0 then
    Exit; // linha de novo registro/grupo - mantem estilo padrao do skin
  Garantir;
  if Odd(ARecordIndex) then
    AStyle := FEstiloImpar
  else
    AStyle := FEstiloPar;
end;

class procedure TERPVEstiloZebra.Liberar;
begin
  FreeAndNil(FEstiloPar);
  FreeAndNil(FEstiloImpar);
end;

procedure ConfigurarGrade(AView: TcxCustomGridTableView);
begin
  // Sem indicador de linha, sem agrupamento, sem rodape desnecessario
  // (UX-SPEC Secao 3.2 "cxGrid: TableView sem indicador, sem
  // agrupamento/rodape desnecessarios").
  AView.OptionsView.Indicator := False;
  AView.OptionsView.GroupByBox := False;
  AView.OptionsView.ColumnAutoWidth := True;
  AView.OptionsView.GridLines := glHorizontal; // so linha horizontal fina, sem vertical forte
  AView.OptionsSelect.CellSelect := False;      // selecao de linha inteira (padrao de lista)
  AView.OptionsData.Editing := False;           // listas somente leitura (edicao real e nas telas de edicao)

  // Zebra (UX-SPEC "zebra #F8FAFC, selecao #DCEBFA") via estilo por
  // registro - ver TERPVEstiloZebra acima.
  AView.OnStylesGetContentStyle := TERPVEstiloZebra.AoObterEstiloConteudo;

  // Selecao de linha e cabecalho: cores centralizadas via Styles (se a
  // propriedade nao existir tal como nomeada nesta versao, ajustar aqui -
  // impacto isolado a esta funcao).
  AView.Styles.Selection.Color := clERPVSelecaoLinha;
  AView.Styles.Selection.TextColor := clERPVTextoPrincipal;
  AView.Styles.Header.Color := clERPVSuperficie;
  AView.Styles.Header.TextColor := clERPVTextoSecundario;
  AView.Styles.Header.Font.Name := ERPVFontePrincipal;
  AView.Styles.Header.Font.Size := ERPVTamCabecalhoCol;
  AView.Styles.Header.Font.Style := [fsBold];
end;

{ ==========================================================================
  EstilizarBotao
  ========================================================================== }

procedure EstilizarBotao(ABotao: TcxButton; const APapel: TUIPapelBotao);
begin
  // TcxButton.Style (TcxButtonStyle) permite customizar cor de fundo, borda
  // e fonte sem depender do skin estar ativo - assuncao documentada no
  // cabecalho desta unit; se a propriedade divergir nesta versao, o ajuste
  // fica isolado a este procedimento.
  ABotao.Font.Name := ERPVFontePrincipal;
  ABotao.Font.Size := ERPVTamCorpo;
  ABotao.Height := ERPVAlturaControle;

  case APapel of
    upbPrimario:
      begin
        // Preenchido, texto branco, negrito (UX-SPEC 3.3: primario sempre o
        // mais a direita no rodape de modal / primeiro na barra de lista).
        ABotao.Style.Color := clERPVDestaque;
        ABotao.Style.HotTrackColor := clERPVDestaqueHover;
        ABotao.Style.BorderColor := clERPVDestaque;
        ABotao.Font.Color := clWhite;
        ABotao.Font.Style := [fsBold];
      end;
    upbSecundario:
      begin
        // Contorno, texto principal (UX-SPEC 3.3: secundario ao lado do
        // primario).
        ABotao.Style.Color := clERPVSuperficie;
        ABotao.Style.HotTrackColor := clERPVFundoApp;
        ABotao.Style.BorderColor := clERPVBordaCampo;
        ABotao.Font.Color := clERPVTextoPrincipal;
        ABotao.Font.Style := [];
      end;
    upbPerigoso:
      begin
        // Contorno vermelho, nunca preenchido (UX-SPEC 3.3: "perigoso...
        // nunca preenchido, sempre com confirmacao" - a confirmacao em si e
        // responsabilidade de quem chama, via Notificar(utnPergunta, ...)
        // antes de disparar a acao perigosa).
        ABotao.Style.Color := clERPVSuperficie;
        ABotao.Style.HotTrackColor := clERPVErroFundo;
        ABotao.Style.BorderColor := clERPVErroTexto;
        ABotao.Font.Color := clERPVErroTexto;
        ABotao.Font.Style := [];
      end;
  end;
end;

{ ==========================================================================
  Notificar
  ========================================================================== }

procedure FecharBanner(APainel: TPanel);
begin
  if Assigned(APainel) then
    APainel.Free;
end;

procedure ExibirBannerInfo(const ATexto: string; AOwnerBanner: TWinControl);
var
  Host: TWinControl;
  Painel: TPanel;
  Rotulo: TLabel;
  Temporizador: TTimer;
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

  Temporizador := TTimer.Create(Painel);
  Temporizador.Interval := ERPVBannerAutoOcultaMs;
  Temporizador.OnTimer :=
    procedure(Sender: TObject)
    begin
      FecharBanner(Painel);
    end;
  Temporizador.Enabled := True;

  Painel.OnClick :=
    procedure(Sender: TObject)
    begin
      FecharBanner(Painel);
    end;
  Rotulo.OnClick := Painel.OnClick;

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
  TERPVEstiloZebra.Liberar;

end.
