unit ERPV.UI.FormListaVendas;

{
  T31 (Lote 7) - Lista de Vendas (UX-SPEC 2.4, 4.1, 4.2). Herda TFormBaseLista.
  Mesmo desenho de TFormListaClientes/TFormListaProdutos. Sem SQL/regra: tudo via
  TVendaService (lista/exclusao) e TClienteService (opcoes do filtro de cliente).

  - Colunas: Nº (ID), Data, Cliente, Total (R$ pt-BR a direita), Situacao
    (chip = texto + cor de fundo/fonte: Pendente/Quitada/Cancelada) e Sinc
    (RESERVADA para T53; fica vazia).
  - Filtros: Situacao (Todas/Pendente/Quitada/Cancelada) e Cliente (Todos/...).
  - UX 4.2: Editar/Excluir so habilitam se a venda esta Pendente. Quitada/
    Cancelada: o botao Editar vira "Visualizar" (abre a mesma tela) e Excluir
    fica desabilitado.
  - "Cancelar venda" (T44): SOMENTE no menu de contexto (e dentro da venda).
    Habilitado so para venda Pendente selecionada com QuitacaoService injetado
    (UX 4.2); abre o dialogo ERPV.UI.FormCancelamentoVenda e recarrega a lista.
    Sucesso = banner Info "Venda N cancelada.".
  - Novo/Editar/Visualizar: TFormEdicaoVenda (T32), ShowModal = mrOk se gravou.
  - O TDataSet devolvido pelo servico e de posse desta tela.
}

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.UITypes, System.Variants, Data.DB,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics, Vcl.Menus,
  cxControls, cxTextEdit, cxGraphics, cxClasses, cxCustomData, cxData, cxDBData, cxGridCustomView,
  cxGridCustomTableView, cxGridTableView, cxGridDBTableView, cxGridLevel, cxGrid,
  cxButtons,
  ERPV.UI.Tokens, ERPV.UI.Tema, ERPV.UI.FormBaseLista,
  ERPV.Negocio.VendaService, ERPV.Negocio.ClienteService,
  ERPV.Negocio.ProdutoService, ERPV.Negocio.QuitacaoService;

type
  TFormListaVendas = class(TFormBaseLista)
  private
    FVendaService: TVendaService;
    FClienteService: TClienteService;
    FProdutoService: TProdutoService;
    FDataSet: TDataSet;
    FDataSource: TDataSource;
    FOnFechada: TNotifyEvent;
    FClienteIds: TArray<Integer>; // paralelo a FCmbCliente.Items (indice 0 = Todos)
    FPnlFiltros: TPanel;
    FLblStatus: TLabel;
    FCmbStatus: TComboBox;
    FLblCliente: TLabel;
    FCmbCliente: TComboBox;
    FQuitacaoService: TQuitacaoService;
    FBtnConfirmar: TcxButton;
    FLblEspera: TLabel;
    FMenu: TPopupMenu;
    FItemCancelar: TMenuItem;
    FGrade: TcxGrid;
    FNivel: TcxGridLevel;
    FView: TcxGridDBTableView;
    FColId: TcxGridDBColumn;
    FColData: TcxGridDBColumn;
    FColTotal: TcxGridDBColumn;
    FColStatus: TcxGridDBColumn;
    FColSinc: TcxGridDBColumn;
    FPnlVazio: TPanel;
    FPnlErro: TPanel;
    FLblErro: TLabel;
    FBtnTentar: TcxButton;
    procedure MontarFiltros;
    procedure CarregarClientesFiltro;
    procedure MontarMenu;
    procedure MontarGrade;
    procedure MontarVazio;
    procedure MontarErro;
    function AdicionarColuna(const ACampo, ATitulo: string;
      ALargura: Integer): TcxGridDBColumn;
    procedure Recarregar;
    procedure MostrarErro(const ATexto: string);
    procedure AtualizarEstado;
    function IdSelecionado: Integer;
    function StatusSelecionado: string;
    function StatusDoRegistro(ARecord: TcxCustomGridRecord): string;
    function ClienteIdFiltro: Integer;
    function StatusFiltro: string;
    procedure AbrirEdicao(AVendaId: Integer);
    procedure AoMudarFiltro(Sender: TObject);
    procedure AoTentarNovamente(Sender: TObject);
    procedure AoCancelarVenda(Sender: TObject);
    procedure AoConfirmarVenda(Sender: TObject);
    procedure SetQuitacaoService(AValor: TQuitacaoService);
    procedure AoMudarFoco(Sender: TcxCustomGridTableView;
      APrevFocusedRecord, AFocusedRecord: TcxCustomGridRecord;
      ANewItemRecordFocusingChanged: Boolean);
    procedure AoDuploClique(Sender: TcxCustomGridTableView;
      ACellViewInfo: TcxGridTableDataCellViewInfo; AButton: TMouseButton;
      AShift: TShiftState; var AHandled: Boolean);
    procedure AoTextoData(Sender: TcxCustomGridTableItem;
      ARecord: TcxCustomGridRecord; var AText: string);
    procedure AoTextoTotal(Sender: TcxCustomGridTableItem;
      ARecord: TcxCustomGridRecord; var AText: string);
    procedure AoDesenharCelula(Sender: TcxCustomGridTableView; ACanvas: TcxCanvas;
      AViewInfo: TcxGridTableDataCellViewInfo; var ADone: Boolean);
    procedure LiberarDados;
  protected
    procedure AoNovo; override;
    procedure AoEditar; override;
    procedure AoExcluir; override;
    procedure AoFechar; override;
  public
    constructor Create(AOwner: TComponent; AVendaService: TVendaService;
      AClienteService: TClienteService; AProdutoService: TProdutoService); reintroduce;
    destructor Destroy; override;
    /// <summary>Disparado quando o usuario pede Fechar/Esc estando embutida no shell;
    /// o dono decide liberar. Sem handler, fecha como form normal.</summary>
    property OnFechada: TNotifyEvent read FOnFechada write FOnFechada;
    /// <summary>Injetado pelo root (via FormMain). Sem ele, Confirmar fica
    /// desabilitado (T42). Servico e do chamador; a tela nao o libera.</summary>
    property QuitacaoService: TQuitacaoService read FQuitacaoService
      write SetQuitacaoService;
  end;

implementation

uses
  System.DateUtils,
  ERPV.Core.Erros, ERPV.Dominio.Enums, ERPV.UI.FormEdicaoVenda,
  ERPV.UI.ConfirmacaoVenda, ERPV.UI.FormCancelamentoVenda, ERPV.UI.Icones;

const
  MSG_ERRO_LISTA = 'Não foi possível carregar as vendas.';
  MSG_ERRO_GENERICO = 'Ocorreu um erro inesperado. Tente novamente.';
  MSG_VAZIO = 'Nenhum registro. Use Novo.';
  ST_PENDENTE = 'Pendente';
  ST_QUITADA = 'Quitada';
  ST_CANCELADA = 'Cancelada';

constructor TFormListaVendas.Create(AOwner: TComponent; AVendaService: TVendaService;
  AClienteService: TClienteService; AProdutoService: TProdutoService);
begin
  inherited Create(AOwner);
  FVendaService := AVendaService;
  FClienteService := AClienteService;
  FProdutoService := AProdutoService;
  Titulo := 'Vendas';
  MontarFiltros;
  MontarMenu;
  MontarGrade;
  MontarVazio;
  MontarErro;
  CarregarClientesFiltro;
  HabilitarAcoes(False, False);
  Recarregar;
end;

destructor TFormListaVendas.Destroy;
begin
  if FView <> nil then
    FView.DataController.DataSource := nil;
  LiberarDados;
  inherited Destroy;
end;

procedure TFormListaVendas.LiberarDados;
begin
  FreeAndNil(FDataSet);
end;

procedure TFormListaVendas.MontarFiltros;
begin
  FPnlFiltros := TPanel.Create(Self);
  FPnlFiltros.Parent := PnlConteudo;
  FPnlFiltros.Align := alTop;
  FPnlFiltros.BevelOuter := bvNone;
  FPnlFiltros.ParentBackground := False;
  FPnlFiltros.Color := clERPVSuperficie;
  FPnlFiltros.Height := ERPVAlturaControle + 2 * ERPVEspaco8;

  FLblStatus := TLabel.Create(Self);
  FLblStatus.Parent := FPnlFiltros;
  FLblStatus.SetBounds(0, ERPVEspaco8 + 5, 60, 16);
  FLblStatus.Caption := 'Situação';
  FLblStatus.FocusControl := nil;

  FCmbStatus := TComboBox.Create(Self);
  FCmbStatus.Parent := FPnlFiltros;
  FCmbStatus.Style := csDropDownList;
  FCmbStatus.SetBounds(64, ERPVEspaco8, 140, ERPVAlturaControle);
  FCmbStatus.Items.Add('Todas');
  FCmbStatus.Items.Add(ST_PENDENTE);
  FCmbStatus.Items.Add(ST_QUITADA);
  FCmbStatus.Items.Add(ST_CANCELADA);
  FCmbStatus.ItemIndex := 0;
  FCmbStatus.OnChange := AoMudarFiltro;
  FLblStatus.FocusControl := FCmbStatus;

  FLblCliente := TLabel.Create(Self);
  FLblCliente.Parent := FPnlFiltros;
  FLblCliente.SetBounds(FCmbStatus.Left + FCmbStatus.Width + ERPVEspaco16,
    ERPVEspaco8 + 5, 50, 16);
  FLblCliente.Caption := 'Cliente';

  FCmbCliente := TComboBox.Create(Self);
  FCmbCliente.Parent := FPnlFiltros;
  FCmbCliente.Style := csDropDownList;
  FCmbCliente.SetBounds(FLblCliente.Left + 54, ERPVEspaco8, 260, ERPVAlturaControle);
  FCmbCliente.OnChange := AoMudarFiltro;
  FLblCliente.FocusControl := FCmbCliente;

  FCmbStatus.TabOrder := 0;
  FCmbCliente.TabOrder := 1;

  // T42: Confirmar (quitacao) a direita do painel + rotulo de espera
  FBtnConfirmar := TcxButton.Create(Self);
  FBtnConfirmar.Parent := FPnlFiltros;
  FBtnConfirmar.Align := alRight;
  FBtnConfirmar.Width := EscalarPx(120);
  FBtnConfirmar.AlignWithMargins := True;
  FBtnConfirmar.Caption := '&Confirmar';
  FBtnConfirmar.Enabled := False;
  FBtnConfirmar.TabOrder := 2;
  FBtnConfirmar.OnClick := AoConfirmarVenda;
  EstilizarBotao(FBtnConfirmar, upbPrimario);
  AplicarIcone(FBtnConfirmar, ERPVIconeConfirmar);

  FLblEspera := TLabel.Create(Self);
  FLblEspera.Parent := FPnlFiltros;
  FLblEspera.Align := alRight;
  FLblEspera.AlignWithMargins := True;
  FLblEspera.Layout := tlCenter;
  FLblEspera.Font.Color := clERPVTextoSecundario;
  FLblEspera.Visible := False;
end;

procedure TFormListaVendas.SetQuitacaoService(AValor: TQuitacaoService);
begin
  FQuitacaoService := AValor;
  AtualizarEstado;
end;

procedure TFormListaVendas.AoConfirmarVenda(Sender: TObject);
var
  Espera: TControlesEspera;
  Total: Currency;
  Id, Idx: Integer;
  V: Variant;
begin
  Id := IdSelecionado;
  if (FQuitacaoService = nil) or (Id <= 0) or
    not SameText(StatusSelecionado, ST_PENDENTE) then
    Exit;
  Total := 0;
  Idx := FView.DataController.FocusedRecordIndex;
  V := FView.DataController.Values[Idx, FColTotal.Index];
  if not VarIsNull(V) then
    Total := VarAsType(V, varCurrency);
  Espera.Desabilitar := [FBtnConfirmar, BtnNovo, BtnEditar, BtnExcluir, BtnFechar,
    FCmbStatus, FCmbCliente, FGrade];
  Espera.Rotulo := FLblEspera;
  // Excecoes (ERegraNegocio/EInfra/inesperada) sobem ao handler global; a UI ja
  // foi restaurada no finally do helper.
  if ConfirmarVendaComFeedback(FQuitacaoService, Id, Total, Espera, PnlConteudo) then
    Recarregar
  else
    AtualizarEstado;
end;

procedure TFormListaVendas.CarregarClientesFiltro;
var
  DS: TDataSet;
  N: Integer;
begin
  FCmbCliente.Items.Clear;
  FCmbCliente.Items.Add('Todos');
  SetLength(FClienteIds, 1);
  FClienteIds[0] := 0;
  try
    DS := FClienteService.ListarDataSet('', True); // inclui inativos: vendas antigas
    try
      N := 1;
      while not DS.Eof do
      begin
        FCmbCliente.Items.Add(DS.FieldByName('NOME').AsString);
        SetLength(FClienteIds, N + 1);
        FClienteIds[N] := DS.FieldByName('ID').AsInteger;
        Inc(N);
        DS.Next;
      end;
    finally
      DS.Free;
    end;
  except
    on E: Exception do
    begin
      // filtro fica so com "Todos"; a lista em si segue funcionando
      if E is EErpVendas then
        Notificar(utnAviso, 'Filtro de clientes indisponível: ' + E.Message)
      else
        Notificar(utnAviso, 'Filtro de clientes indisponível.');
    end;
  end;
  FCmbCliente.ItemIndex := 0;
end;

procedure TFormListaVendas.MontarMenu;
begin
  FMenu := TPopupMenu.Create(Self);
  FItemCancelar := TMenuItem.Create(FMenu);
  FItemCancelar.Caption := 'Cancelar venda';
  // Habilitado so para Pendente com servico injetado (UX 4.2): ver AtualizarEstado.
  FItemCancelar.Enabled := False;
  FItemCancelar.OnClick := AoCancelarVenda;
  FMenu.Items.Add(FItemCancelar);
end;

function TFormListaVendas.AdicionarColuna(const ACampo, ATitulo: string;
  ALargura: Integer): TcxGridDBColumn;
begin
  Result := FView.CreateColumn;
  Result.DataBinding.FieldName := ACampo;
  Result.Caption := ATitulo;
  Result.Width := ALargura;
end;

procedure TFormListaVendas.MontarGrade;
begin
  FDataSource := TDataSource.Create(Self);

  FGrade := TcxGrid.Create(Self);
  FGrade.Parent := PnlConteudo;
  FGrade.Align := alClient;
  FGrade.BorderStyle := cxcbsNone;
  FGrade.TabOrder := 1;
  FGrade.PopupMenu := FMenu;

  FView := FGrade.CreateView(TcxGridDBTableView) as TcxGridDBTableView;
  FNivel := FGrade.Levels.Add;
  FNivel.GridView := FView;

  FColId := AdicionarColuna('ID', 'Nº', 70);
  FColData := AdicionarColuna('DATA_VENDA', 'Data', 130);
  FColData.PropertiesClass := TcxTextEditProperties;
  FColData.OnGetDisplayText := AoTextoData;
  AdicionarColuna('CLIENTE_NOME', 'Cliente', 280);
  FColTotal := AdicionarColuna('VALOR_TOTAL', 'Total', 120);
  FColTotal.PropertiesClass := TcxTextEditProperties;
  TcxTextEditProperties(FColTotal.Properties).Alignment.Horz := taRightJustify;
  FColTotal.HeaderAlignmentHorz := taRightJustify;
  FColTotal.OnGetDisplayText := AoTextoTotal;
  FColStatus := AdicionarColuna('STATUS', 'Situação', 100);
  // Coluna "Sinc" reservada (T53): sem campo; fica vazia.
  FColSinc := FView.CreateColumn;
  FColSinc.Caption := 'Sinc';
  FColSinc.Width := 60;
  FColSinc.Options.Editing := False;

  FView.DataController.KeyFieldNames := 'ID';
  FView.DataController.DataSource := FDataSource;
  ConfigurarGrade(FView);
  FView.OnCustomDrawCell := AoDesenharCelula;
  FView.OnFocusedRecordChanged := AoMudarFoco;
  FView.OnCellDblClick := AoDuploClique;
end;

procedure TFormListaVendas.MontarVazio;
begin
  FPnlVazio := TPanel.Create(Self);
  FPnlVazio.Parent := PnlConteudo;
  FPnlVazio.Align := alBottom;
  FPnlVazio.BevelOuter := bvNone;
  FPnlVazio.ParentBackground := False;
  FPnlVazio.Color := clERPVSuperficie;
  FPnlVazio.Height := 40;
  FPnlVazio.Caption := MSG_VAZIO;
  FPnlVazio.Font.Color := clERPVTextoSecundario;
  FPnlVazio.Visible := False;
end;

procedure TFormListaVendas.MontarErro;
begin
  FPnlErro := TPanel.Create(Self);
  FPnlErro.Parent := PnlConteudo;
  FPnlErro.Align := alBottom;
  FPnlErro.BevelOuter := bvNone;
  FPnlErro.ParentBackground := False;
  FPnlErro.Color := clERPVErroFundo;
  FPnlErro.Height := 40;
  FPnlErro.Visible := False;

  FBtnTentar := TcxButton.Create(Self);
  FBtnTentar.Parent := FPnlErro;
  FBtnTentar.Align := alRight;
  FBtnTentar.Width := 140;
  FBtnTentar.AlignWithMargins := True;
  FBtnTentar.Caption := 'Tentar novamente';
  FBtnTentar.OnClick := AoTentarNovamente;
  EstilizarBotao(FBtnTentar, upbSecundario);

  FLblErro := TLabel.Create(Self);
  FLblErro.Parent := FPnlErro;
  FLblErro.Align := alClient;
  FLblErro.AlignWithMargins := True;
  FLblErro.Layout := tlCenter;
  FLblErro.Font.Color := clERPVErroTexto;
  FLblErro.Transparent := True;
end;

procedure TFormListaVendas.MostrarErro(const ATexto: string);
begin
  FLblErro.Caption := ATexto;
  FPnlErro.Visible := True;
end;

function TFormListaVendas.StatusFiltro: string;
begin
  if FCmbStatus.ItemIndex <= 0 then
    Result := ''
  else
    Result := FCmbStatus.Items[FCmbStatus.ItemIndex];
end;

function TFormListaVendas.ClienteIdFiltro: Integer;
begin
  if (FCmbCliente.ItemIndex <= 0) or (FCmbCliente.ItemIndex > High(FClienteIds)) then
    Result := 0
  else
    Result := FClienteIds[FCmbCliente.ItemIndex];
end;

procedure TFormListaVendas.Recarregar;
var
  Novo, Antigo: TDataSet;
begin
  FPnlErro.Visible := False;
  try
    Novo := FVendaService.ListarDataSet(StatusFiltro, ClienteIdFiltro);
  except
    on E: Exception do
    begin
      if E is EErpVendas then
        MostrarErro(E.Message)
      else
        MostrarErro(MSG_ERRO_LISTA + ' ' + MSG_ERRO_GENERICO);
      AtualizarEstado;
      Exit;
    end;
  end;
  Antigo := FDataSet;
  FView.DataController.DataSource := nil;
  FDataSource.DataSet := Novo;
  FDataSet := Novo;
  FView.DataController.DataSource := FDataSource;
  Antigo.Free;
  AtualizarEstado;
end;

procedure TFormListaVendas.AtualizarEstado;
var
  Vazio, Sel, Pend: Boolean;
begin
  Vazio := (FDataSet = nil) or FDataSet.IsEmpty;
  FPnlVazio.Visible := Vazio and not FPnlErro.Visible;
  Subtitulo := Format('%d venda(s)', [FView.DataController.RecordCount]);
  Sel := IdSelecionado > 0;
  Pend := Sel and SameText(StatusSelecionado, ST_PENDENTE);
  // UX 4.2: Pendente = Editar/Excluir; Quitada/Cancelada = Visualizar, sem Excluir.
  if Sel and not Pend then
    BtnEditar.Caption := 'Visualizar'
  else
    BtnEditar.Caption := 'Editar';
  HabilitarAcoes(Sel, Pend);
  // UX 4.2: Confirmar so para Pendente (fila pendente = T53)
  FBtnConfirmar.Enabled := Pend and (FQuitacaoService <> nil);
  FItemCancelar.Enabled := Pend and (FQuitacaoService <> nil);
end;

function TFormListaVendas.IdSelecionado: Integer;
var
  Idx: Integer;
  V: Variant;
begin
  Result := 0;
  Idx := FView.DataController.FocusedRecordIndex;
  if Idx < 0 then
    Exit;
  V := FView.DataController.Values[Idx, FColId.Index];
  if not VarIsNull(V) then
    Result := V;
end;

function TFormListaVendas.StatusSelecionado: string;
var
  Idx: Integer;
  V: Variant;
begin
  Result := '';
  Idx := FView.DataController.FocusedRecordIndex;
  if Idx < 0 then
    Exit;
  V := FView.DataController.Values[Idx, FColStatus.Index];
  if not VarIsNull(V) then
    Result := VarToStr(V);
end;

function TFormListaVendas.StatusDoRegistro(ARecord: TcxCustomGridRecord): string;
var
  V: Variant;
begin
  V := ARecord.Values[FColStatus.Index];
  if VarIsNull(V) then
    Result := ''
  else
    Result := VarToStr(V);
end;

procedure TFormListaVendas.AoTextoData(Sender: TcxCustomGridTableItem;
  ARecord: TcxCustomGridRecord; var AText: string);
var
  V: Variant;
begin
  if ARecord = nil then
    Exit;
  V := ARecord.Values[FColData.Index];
  if VarIsNull(V) then
    Exit;
  AText := FormatDateTime('dd/mm/yyyy hh:nn', VarToDateTime(V));
end;

procedure TFormListaVendas.AoTextoTotal(Sender: TcxCustomGridTableItem;
  ARecord: TcxCustomGridRecord; var AText: string);
var
  V: Variant;
  FS: TFormatSettings;
begin
  if ARecord = nil then
    Exit;
  V := ARecord.Values[FColTotal.Index];
  if VarIsNull(V) then
    Exit;
  FS := TFormatSettings.Create('pt-BR');
  AText := FormatCurr('R$ #,##0.00', VarAsType(V, varCurrency), FS);
end;

procedure TFormListaVendas.AoDesenharCelula(Sender: TcxCustomGridTableView;
  ACanvas: TcxCanvas; AViewInfo: TcxGridTableDataCellViewInfo; var ADone: Boolean);
var
  S: string;
begin
  // Chip de situacao: texto sempre presente + cor (nunca so cor, UX 4).
  if AViewInfo.Item = FColStatus then
  begin
    S := StatusDoRegistro(AViewInfo.GridRecord);
    if SameText(S, ST_PENDENTE) then
      ACanvas.Font.Color := clERPVAvisoTexto
    else if SameText(S, ST_QUITADA) then
      ACanvas.Font.Color := clERPVSucessoTexto
    else
      ACanvas.Font.Color := clERPVInativoTexto;
    ACanvas.Font.Style := [fsBold];
  end;
  ADone := False;
end;

procedure TFormListaVendas.AoMudarFoco(Sender: TcxCustomGridTableView;
  APrevFocusedRecord, AFocusedRecord: TcxCustomGridRecord;
  ANewItemRecordFocusingChanged: Boolean);
begin
  AtualizarEstado;
end;

procedure TFormListaVendas.AoDuploClique(Sender: TcxCustomGridTableView;
  ACellViewInfo: TcxGridTableDataCellViewInfo; AButton: TMouseButton;
  AShift: TShiftState; var AHandled: Boolean);
begin
  if (AButton = mbLeft) and (IdSelecionado > 0) then
  begin
    AHandled := True;
    AoEditar; // Editar (Pendente) ou Visualizar (demais)
  end;
end;

procedure TFormListaVendas.AoMudarFiltro(Sender: TObject);
begin
  Recarregar;
end;

procedure TFormListaVendas.AoTentarNovamente(Sender: TObject);
begin
  Recarregar;
end;

procedure TFormListaVendas.AoCancelarVenda(Sender: TObject);
var
  Id: Integer;
  Cancelou: Boolean;
begin
  Id := IdSelecionado;
  if (FQuitacaoService = nil) or (Id <= 0) or
    not SameText(StatusSelecionado, ST_PENDENTE) then
    Exit;
  // Regra no TQuitacaoService (T43); a tela so exibe (dialogo T44).
  Cancelou := CancelarVendaComDialogo(Self, FQuitacaoService, Id);
  Recarregar; // o status pode ter mudado mesmo sem cancelar (ex.: nao permitida)
  if Cancelou then
    AvisarVendaCancelada(Id, PnlConteudo);
end;

procedure TFormListaVendas.AbrirEdicao(AVendaId: Integer);
var
  Tela: TFormEdicaoVenda;
  Cancelada: Boolean;
begin
  Cancelada := False;
  Tela := TFormEdicaoVenda.Create(Self, FVendaService, FClienteService,
    FProdutoService, AVendaId);
  try
    Tela.QuitacaoService := FQuitacaoService;
    if Tela.ShowModal = mrOk then
    begin
      Cancelada := Tela.VendaCancelada;
      Recarregar;
    end;
  finally
    Tela.Free;
  end;
  // T44: cancelada dentro da venda: a tela fechou; o banner Info fica aqui
  if Cancelada then
    AvisarVendaCancelada(AVendaId, PnlConteudo);
end;

procedure TFormListaVendas.AoNovo;
begin
  AbrirEdicao(0);
end;

procedure TFormListaVendas.AoEditar;
begin
  if IdSelecionado <= 0 then
    Exit;
  AbrirEdicao(IdSelecionado);
end;

procedure TFormListaVendas.AoExcluir;
var
  Id: Integer;
begin
  Id := IdSelecionado;
  if (Id <= 0) or not SameText(StatusSelecionado, ST_PENDENTE) then
    Exit;
  if not Notificar(utnPergunta, 'Excluir a venda Nº ' + IntToStr(Id) + '?') then
    Exit;
  try
    FVendaService.Excluir(Id);
  except
    on E: Exception do
    begin
      if E is EErpVendas then
        Notificar(utnErro, E.Message)
      else
        Notificar(utnErro, MSG_ERRO_GENERICO);
      Exit;
    end;
  end;
  Recarregar;
end;

procedure TFormListaVendas.AoFechar;
begin
  if Assigned(FOnFechada) then
    FOnFechada(Self)
  else
    inherited AoFechar;
end;

end.
