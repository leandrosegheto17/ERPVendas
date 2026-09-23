unit ERPV.UI.FormListaClientes;

{
  T19 (Lote 4) - Lista de Clientes (UX-SPEC 2.2, 3.3, 4.1). Herda TFormBaseLista.
  Sem SQL/regra: tudo via TClienteService. Construida 100% em codigo.

  - Grade cxGrid (TcxGridDBTableView) com colunas explicitas ligadas ao TDataSet
    do servico (ID oculto, Nome, Tipo, CPF/CNPJ, E-mail, Telefone, Situacao).
  - Situacao: TEXTO ("Ativo"/"Inativo") + cor (nao so cor), via OnGetDisplayText
    e OnCustomDrawCell.
  - Busca (filtra ao digitar, com debounce) e "Mostrar inativos".
  - Vazio: "Nenhum registro. Use Novo."; erro: banner + "Tentar novamente".
  - O TDataSet devolvido pelo servico e de posse desta tela (liberado ao trocar/fechar).
}

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.UITypes, System.Variants, Data.DB,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  cxControls, cxTextEdit, cxGraphics, cxClasses, cxCustomData, cxData, cxDBData, cxGridCustomView,
  cxGridCustomTableView, cxGridTableView, cxGridDBTableView, cxGridLevel, cxGrid,
  cxButtons,
  ERPV.UI.Tokens, ERPV.UI.Tema, ERPV.UI.FormBaseLista,
  ERPV.Negocio.ClienteService;

type
  TFormListaClientes = class(TFormBaseLista)
  private
    FService: TClienteService;
    FDataSet: TDataSet;
    FDataSource: TDataSource;
    FOnFechada: TNotifyEvent;
    FPnlFiltros: TPanel;
    FEdtBusca: TEdit;
    FChkInativos: TCheckBox;
    FTimerBusca: TTimer;
    FGrade: TcxGrid;
    FNivel: TcxGridLevel;
    FView: TcxGridDBTableView;
    FColId: TcxGridDBColumn;
    FColNome: TcxGridDBColumn;
    FColSituacao: TcxGridDBColumn;
    FPnlVazio: TPanel;
    FPnlErro: TPanel;
    FLblErro: TLabel;
    FBtnTentar: TcxButton;
    procedure MontarFiltros;
    procedure MontarGrade;
    procedure MontarVazio;
    procedure MontarErro;
    function AdicionarColuna(const ACampo, ATitulo: string;
      ALargura: Integer): TcxGridDBColumn;
    procedure Recarregar;
    procedure MostrarErro(const ATexto: string);
    procedure AtualizarEstado;
    function IdSelecionado: Integer;
    function NomeSelecionado: string;
    function ValorAtivo(ARecord: TcxCustomGridRecord): Boolean;
    procedure AoMudarBusca(Sender: TObject);
    procedure AoTempoBusca(Sender: TObject);
    procedure AoMudarInativos(Sender: TObject);
    procedure AoTentarNovamente(Sender: TObject);
    procedure AoMudarFoco(Sender: TcxCustomGridTableView;
      APrevFocusedRecord, AFocusedRecord: TcxCustomGridRecord;
      ANewItemRecordFocusingChanged: Boolean);
    // OnDblClick do TcxGrid e protected (E2362); o duplo clique em celula vem
    // do evento da view (achado real de compilacao, 2026-09-23).
    procedure AoDuploClique(Sender: TcxCustomGridTableView;
      ACellViewInfo: TcxGridTableDataCellViewInfo; AButton: TMouseButton;
      AShift: TShiftState; var AHandled: Boolean);
    procedure AoTextoSituacao(Sender: TcxCustomGridTableItem;
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
    constructor Create(AOwner: TComponent; AService: TClienteService); reintroduce;
    destructor Destroy; override;
    /// <summary>Disparado quando o usuario pede Fechar/Esc estando embutida no shell;
    /// o dono decide liberar. Sem handler, fecha como form normal.</summary>
    property OnFechada: TNotifyEvent read FOnFechada write FOnFechada;
  end;

implementation

uses
  ERPV.Core.Erros, ERPV.Dominio.Cliente, ERPV.UI.FormEdicaoCliente;

const
  MSG_ERRO_LISTA = 'Não foi possível carregar os clientes.';
  MSG_ERRO_GENERICO = 'Ocorreu um erro inesperado. Tente novamente.';
  MSG_VAZIO = 'Nenhum registro. Use Novo.';
  DEBOUNCE_MS = 300;

constructor TFormListaClientes.Create(AOwner: TComponent; AService: TClienteService);
begin
  inherited Create(AOwner);
  FService := AService;
  Titulo := 'Clientes';
  MontarFiltros;
  MontarGrade;
  MontarVazio;
  MontarErro;
  HabilitarAcoes(False, False);
  Recarregar;
end;

destructor TFormListaClientes.Destroy;
begin
  if FTimerBusca <> nil then
    FTimerBusca.Enabled := False;
  // solta a ligacao da grade antes de liberar o dataset
  if FView <> nil then
    FView.DataController.DataSource := nil;
  LiberarDados;
  inherited Destroy;
end;

procedure TFormListaClientes.LiberarDados;
begin
  FreeAndNil(FDataSet);
end;

procedure TFormListaClientes.MontarFiltros;
begin
  FPnlFiltros := TPanel.Create(Self);
  FPnlFiltros.Parent := PnlConteudo;
  FPnlFiltros.Align := alTop;
  FPnlFiltros.BevelOuter := bvNone;
  FPnlFiltros.ParentBackground := False;
  FPnlFiltros.Color := clERPVSuperficie;
  FPnlFiltros.Height := ERPVAlturaControle + 2 * ERPVEspaco8;

  FEdtBusca := TEdit.Create(Self);
  FEdtBusca.Parent := FPnlFiltros;
  FEdtBusca.SetBounds(0, ERPVEspaco8, 300, ERPVAlturaControle);
  FEdtBusca.TextHint := 'Buscar por nome, CPF/CNPJ ou e-mail';
  FEdtBusca.OnChange := AoMudarBusca;

  FChkInativos := TCheckBox.Create(Self);
  FChkInativos.Parent := FPnlFiltros;
  FChkInativos.SetBounds(FEdtBusca.Width + ERPVEspaco16, ERPVEspaco8 + 4, 160, 20);
  FChkInativos.Caption := 'Mostrar inativos';
  FChkInativos.OnClick := AoMudarInativos;

  FTimerBusca := TTimer.Create(Self);
  FTimerBusca.Enabled := False;
  FTimerBusca.Interval := DEBOUNCE_MS;
  FTimerBusca.OnTimer := AoTempoBusca;

  FEdtBusca.TabOrder := 0;
  FChkInativos.TabOrder := 1;
end;

function TFormListaClientes.AdicionarColuna(const ACampo, ATitulo: string;
  ALargura: Integer): TcxGridDBColumn;
begin
  Result := FView.CreateColumn;
  Result.DataBinding.FieldName := ACampo;
  Result.Caption := ATitulo;
  Result.Width := ALargura;
end;

procedure TFormListaClientes.MontarGrade;
begin
  FDataSource := TDataSource.Create(Self);

  FGrade := TcxGrid.Create(Self);
  FGrade.Parent := PnlConteudo;
  FGrade.Align := alClient;
  FGrade.BorderStyle := cxcbsNone;
  FGrade.TabOrder := 1;

  FView := FGrade.CreateView(TcxGridDBTableView) as TcxGridDBTableView;
  FNivel := FGrade.Levels.Add;
  FNivel.GridView := FView;

  // Colunas explicitas (divida (b) de T68: grade vazia): nao dependem de
  // CreateAllItems (o DataSet so tem campos depois de aberto).
  FColId := AdicionarColuna('ID', 'Código', 60);
  FColId.Visible := False;
  FColNome := AdicionarColuna('NOME', 'Nome', 240);
  AdicionarColuna('TIPO_PESSOA', 'Tipo', 60);
  AdicionarColuna('CPF_CNPJ', 'CPF/CNPJ', 130);
  AdicionarColuna('EMAIL', 'E-mail', 200);
  AdicionarColuna('TELEFONE', 'Telefone', 110);
  FColSituacao := AdicionarColuna('ATIVO', 'Situação', 80);
  // Campo booleano vira caixa de selecao por padrao no cxGrid; UX §4 pede
  // texto+cor ("Ativo"/"Inativo"), entao forca editor de texto (achado real
  // no teste de T19, 2026-09-23).
  FColSituacao.PropertiesClass := TcxTextEditProperties;
  FColSituacao.OnGetDisplayText := AoTextoSituacao;

  FView.DataController.KeyFieldNames := 'ID';
  FView.DataController.DataSource := FDataSource;
  ConfigurarGrade(FView);
  FView.OnCustomDrawCell := AoDesenharCelula;
  FView.OnFocusedRecordChanged := AoMudarFoco;
  FView.OnCellDblClick := AoDuploClique;
end;

procedure TFormListaClientes.MontarVazio;
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

procedure TFormListaClientes.MontarErro;
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

procedure TFormListaClientes.MostrarErro(const ATexto: string);
begin
  FLblErro.Caption := ATexto;
  FPnlErro.Visible := True;
end;

procedure TFormListaClientes.Recarregar;
var
  Novo, Antigo: TDataSet;
begin
  FPnlErro.Visible := False;
  try
    Novo := FService.ListarDataSet(FEdtBusca.Text, FChkInativos.Checked);
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

procedure TFormListaClientes.AtualizarEstado;
var
  Vazio: Boolean;
begin
  Vazio := (FDataSet = nil) or FDataSet.IsEmpty;
  FPnlVazio.Visible := Vazio and not FPnlErro.Visible;
  Subtitulo := Format('%d cliente(s)', [FView.DataController.RecordCount]);
  HabilitarAcoes(IdSelecionado > 0, IdSelecionado > 0);
end;

function TFormListaClientes.IdSelecionado: Integer;
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

function TFormListaClientes.NomeSelecionado: string;
var
  Idx: Integer;
  V: Variant;
begin
  Result := '';
  Idx := FView.DataController.FocusedRecordIndex;
  if Idx < 0 then
    Exit;
  V := FView.DataController.Values[Idx, FColNome.Index];
  if not VarIsNull(V) then
    Result := V;
end;

function TFormListaClientes.ValorAtivo(ARecord: TcxCustomGridRecord): Boolean;
var
  V: Variant;
begin
  V := ARecord.Values[FColSituacao.Index];
  Result := (not VarIsNull(V)) and Boolean(V);
end;

procedure TFormListaClientes.AoTextoSituacao(Sender: TcxCustomGridTableItem;
  ARecord: TcxCustomGridRecord; var AText: string);
begin
  if ARecord = nil then
    Exit;
  if ValorAtivo(ARecord) then
    AText := 'Ativo'
  else
    AText := 'Inativo';
end;

procedure TFormListaClientes.AoDesenharCelula(Sender: TcxCustomGridTableView;
  ACanvas: TcxCanvas; AViewInfo: TcxGridTableDataCellViewInfo; var ADone: Boolean);
begin
  if AViewInfo.Item = FColSituacao then
  begin
    if ValorAtivo(AViewInfo.GridRecord) then
      ACanvas.Font.Color := clERPVSucessoTexto
    else
      ACanvas.Font.Color := clERPVInativoTexto;
    ACanvas.Font.Style := [fsBold];
  end;
  ADone := False;
end;

procedure TFormListaClientes.AoMudarFoco(Sender: TcxCustomGridTableView;
  APrevFocusedRecord, AFocusedRecord: TcxCustomGridRecord;
  ANewItemRecordFocusingChanged: Boolean);
begin
  HabilitarAcoes(IdSelecionado > 0, IdSelecionado > 0);
end;

procedure TFormListaClientes.AoDuploClique(Sender: TcxCustomGridTableView;
  ACellViewInfo: TcxGridTableDataCellViewInfo; AButton: TMouseButton;
  AShift: TShiftState; var AHandled: Boolean);
begin
  if (AButton = mbLeft) and (IdSelecionado > 0) then
  begin
    AHandled := True;
    AoEditar;
  end;
end;

procedure TFormListaClientes.AoMudarBusca(Sender: TObject);
begin
  FTimerBusca.Enabled := False;
  FTimerBusca.Enabled := True;
end;

procedure TFormListaClientes.AoTempoBusca(Sender: TObject);
begin
  FTimerBusca.Enabled := False;
  Recarregar;
end;

procedure TFormListaClientes.AoMudarInativos(Sender: TObject);
begin
  Recarregar;
end;

procedure TFormListaClientes.AoTentarNovamente(Sender: TObject);
begin
  Recarregar;
end;

procedure TFormListaClientes.AoNovo;
var
  Tela: TFormEdicaoCliente;
begin
  Tela := TFormEdicaoCliente.Create(Self, FService, nil);
  try
    if Tela.ShowModal = mrOk then
      Recarregar;
  finally
    Tela.Free;
  end;
end;

procedure TFormListaClientes.AoEditar;
var
  Tela: TFormEdicaoCliente;
  Cliente: TCliente;
begin
  if IdSelecionado <= 0 then
    Exit;
  try
    Cliente := FService.Obter(IdSelecionado);
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
  if Cliente = nil then
  begin
    Notificar(utnAviso, 'Cliente não encontrado. A lista será atualizada.');
    Recarregar;
    Exit;
  end;
  try
    Tela := TFormEdicaoCliente.Create(Self, FService, Cliente);
    try
      if Tela.ShowModal = mrOk then
        Recarregar;
    finally
      Tela.Free;
    end;
  finally
    Cliente.Free; // a entidade e do chamador (contrato de Obter)
  end;
end;

procedure TFormListaClientes.AoExcluir;
var
  Id: Integer;
begin
  Id := IdSelecionado;
  if Id <= 0 then
    Exit;
  if not Notificar(utnPergunta, 'Excluir o cliente "' + NomeSelecionado + '"?') then
    Exit;
  try
    FService.Excluir(Id);
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

procedure TFormListaClientes.AoFechar;
begin
  if Assigned(FOnFechada) then
    FOnFechada(Self)
  else
    inherited AoFechar;
end;

end.
