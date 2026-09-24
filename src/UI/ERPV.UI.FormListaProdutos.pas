unit ERPV.UI.FormListaProdutos;

{
  T23 (Lote 5) - Lista de Produtos (UX-SPEC 2.2, 4.1). Herda TFormBaseLista.
  Mesmo desenho de TFormListaClientes (T19). Sem SQL/regra: tudo via TProdutoService.

  - Grade cxGrid com colunas explicitas: ID (oculto), Descricao, Unidade,
    Preco (pt-BR, alinhado a direita), Categoria, Situacao ("Ativo"/"Inativo" + cor).
  - Busca com debounce e "Mostrar inativos".
  - Vazio: "Nenhum registro. Use Novo."; erro: banner + "Tentar novamente".
  - Edicao: TFormEdicaoProduto (T24), Create(Owner, Service, Produto|nil), mrOk se gravou.
  - O TDataSet devolvido pelo servico e de posse desta tela.
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
  ERPV.Negocio.ProdutoService;

type
  TFormListaProdutos = class(TFormBaseLista)
  private
    FService: TProdutoService;
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
    FColDescricao: TcxGridDBColumn;
    FColPreco: TcxGridDBColumn;
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
    function DescricaoSelecionada: string;
    function ValorAtivo(ARecord: TcxCustomGridRecord): Boolean;
    procedure AoMudarBusca(Sender: TObject);
    procedure AoTempoBusca(Sender: TObject);
    procedure AoMudarInativos(Sender: TObject);
    procedure AoTentarNovamente(Sender: TObject);
    procedure AoMudarFoco(Sender: TcxCustomGridTableView;
      APrevFocusedRecord, AFocusedRecord: TcxCustomGridRecord;
      ANewItemRecordFocusingChanged: Boolean);
    // OnDblClick do TcxGrid e protected; duplo clique em celula vem da view.
    procedure AoDuploClique(Sender: TcxCustomGridTableView;
      ACellViewInfo: TcxGridTableDataCellViewInfo; AButton: TMouseButton;
      AShift: TShiftState; var AHandled: Boolean);
    procedure AoTextoPreco(Sender: TcxCustomGridTableItem;
      ARecord: TcxCustomGridRecord; var AText: string);
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
    constructor Create(AOwner: TComponent; AService: TProdutoService); reintroduce;
    destructor Destroy; override;
    /// <summary>Disparado quando o usuario pede Fechar/Esc estando embutida no shell;
    /// o dono decide liberar. Sem handler, fecha como form normal.</summary>
    property OnFechada: TNotifyEvent read FOnFechada write FOnFechada;
  end;

implementation

uses
  ERPV.Core.Erros, ERPV.Dominio.Enums, ERPV.Dominio.Produto, ERPV.UI.FormEdicaoProduto;

const
  MSG_ERRO_LISTA = 'Não foi possível carregar os produtos.';
  MSG_ERRO_GENERICO = 'Ocorreu um erro inesperado. Tente novamente.';
  MSG_VAZIO = 'Nenhum registro. Use Novo.';
  DEBOUNCE_MS = 300;

constructor TFormListaProdutos.Create(AOwner: TComponent; AService: TProdutoService);
begin
  inherited Create(AOwner);
  FService := AService;
  Titulo := 'Produtos';
  MontarFiltros;
  MontarGrade;
  MontarVazio;
  MontarErro;
  HabilitarAcoes(False, False);
  Recarregar;
end;

destructor TFormListaProdutos.Destroy;
begin
  if FTimerBusca <> nil then
    FTimerBusca.Enabled := False;
  // solta a ligacao da grade antes de liberar o dataset
  if FView <> nil then
    FView.DataController.DataSource := nil;
  LiberarDados;
  inherited Destroy;
end;

procedure TFormListaProdutos.LiberarDados;
begin
  FreeAndNil(FDataSet);
end;

procedure TFormListaProdutos.MontarFiltros;
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
  FEdtBusca.TextHint := 'Buscar por descrição ou categoria';
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

function TFormListaProdutos.AdicionarColuna(const ACampo, ATitulo: string;
  ALargura: Integer): TcxGridDBColumn;
begin
  Result := FView.CreateColumn;
  Result.DataBinding.FieldName := ACampo;
  Result.Caption := ATitulo;
  Result.Width := ALargura;
end;

procedure TFormListaProdutos.MontarGrade;
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

  // Colunas explicitas (nao dependem de CreateAllItems).
  FColId := AdicionarColuna('ID', 'Código', 60);
  FColId.Visible := False;
  FColDescricao := AdicionarColuna('DESCRICAO', 'Descrição', 280);
  AdicionarColuna('UNIDADE', 'Unidade', 70);
  FColPreco := AdicionarColuna('PRECO_UNITARIO', 'Preço', 110);
  // Texto pt-BR alinhado a direita (o valor segue Currency no dataset).
  FColPreco.PropertiesClass := TcxTextEditProperties;
  TcxTextEditProperties(FColPreco.Properties).Alignment.Horz := taRightJustify;
  FColPreco.HeaderAlignmentHorz := taRightJustify;
  FColPreco.OnGetDisplayText := AoTextoPreco;
  AdicionarColuna('CATEGORIA', 'Categoria', 160);
  FColSituacao := AdicionarColuna('ATIVO', 'Situação', 80);
  // Campo booleano vira caixa de selecao por padrao; UX §4 pede texto+cor.
  FColSituacao.PropertiesClass := TcxTextEditProperties;
  FColSituacao.OnGetDisplayText := AoTextoSituacao;

  FView.DataController.KeyFieldNames := 'ID';
  FView.DataController.DataSource := FDataSource;
  ConfigurarGrade(FView);
  FView.OnCustomDrawCell := AoDesenharCelula;
  FView.OnFocusedRecordChanged := AoMudarFoco;
  FView.OnCellDblClick := AoDuploClique;
end;

procedure TFormListaProdutos.MontarVazio;
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

procedure TFormListaProdutos.MontarErro;
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

procedure TFormListaProdutos.MostrarErro(const ATexto: string);
begin
  FLblErro.Caption := ATexto;
  FPnlErro.Visible := True;
end;

procedure TFormListaProdutos.Recarregar;
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

procedure TFormListaProdutos.AtualizarEstado;
var
  Vazio: Boolean;
begin
  Vazio := (FDataSet = nil) or FDataSet.IsEmpty;
  FPnlVazio.Visible := Vazio and not FPnlErro.Visible;
  Subtitulo := Format('%d produto(s)', [FView.DataController.RecordCount]);
  HabilitarAcoes(IdSelecionado > 0, IdSelecionado > 0);
end;

function TFormListaProdutos.IdSelecionado: Integer;
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

function TFormListaProdutos.DescricaoSelecionada: string;
var
  Idx: Integer;
  V: Variant;
begin
  Result := '';
  Idx := FView.DataController.FocusedRecordIndex;
  if Idx < 0 then
    Exit;
  V := FView.DataController.Values[Idx, FColDescricao.Index];
  if not VarIsNull(V) then
    Result := V;
end;

function TFormListaProdutos.ValorAtivo(ARecord: TcxCustomGridRecord): Boolean;
var
  V: Variant;
begin
  V := ARecord.Values[FColSituacao.Index];
  Result := (not VarIsNull(V)) and Boolean(V);
end;

procedure TFormListaProdutos.AoTextoPreco(Sender: TcxCustomGridTableItem;
  ARecord: TcxCustomGridRecord; var AText: string);
var
  V: Variant;
  FS: TFormatSettings;
begin
  if ARecord = nil then
    Exit;
  V := ARecord.Values[FColPreco.Index];
  if VarIsNull(V) then
    Exit;
  FS := TFormatSettings.Create('pt-BR');
  AText := FormatCurr('R$ #,##0.00', VarAsType(V, varCurrency), FS);
end;

procedure TFormListaProdutos.AoTextoSituacao(Sender: TcxCustomGridTableItem;
  ARecord: TcxCustomGridRecord; var AText: string);
begin
  if ARecord = nil then
    Exit;
  if ValorAtivo(ARecord) then
    AText := 'Ativo'
  else
    AText := 'Inativo';
end;

procedure TFormListaProdutos.AoDesenharCelula(Sender: TcxCustomGridTableView;
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

procedure TFormListaProdutos.AoMudarFoco(Sender: TcxCustomGridTableView;
  APrevFocusedRecord, AFocusedRecord: TcxCustomGridRecord;
  ANewItemRecordFocusingChanged: Boolean);
begin
  HabilitarAcoes(IdSelecionado > 0, IdSelecionado > 0);
end;

procedure TFormListaProdutos.AoDuploClique(Sender: TcxCustomGridTableView;
  ACellViewInfo: TcxGridTableDataCellViewInfo; AButton: TMouseButton;
  AShift: TShiftState; var AHandled: Boolean);
begin
  if (AButton = mbLeft) and (IdSelecionado > 0) then
  begin
    AHandled := True;
    AoEditar;
  end;
end;

procedure TFormListaProdutos.AoMudarBusca(Sender: TObject);
begin
  FTimerBusca.Enabled := False;
  FTimerBusca.Enabled := True;
end;

procedure TFormListaProdutos.AoTempoBusca(Sender: TObject);
begin
  FTimerBusca.Enabled := False;
  Recarregar;
end;

procedure TFormListaProdutos.AoMudarInativos(Sender: TObject);
begin
  Recarregar;
end;

procedure TFormListaProdutos.AoTentarNovamente(Sender: TObject);
begin
  Recarregar;
end;

procedure TFormListaProdutos.AoNovo;
var
  Tela: TFormEdicaoProduto;
begin
  Tela := TFormEdicaoProduto.Create(Self, FService, nil);
  try
    if Tela.ShowModal = mrOk then
      Recarregar;
  finally
    Tela.Free;
  end;
end;

procedure TFormListaProdutos.AoEditar;
var
  Tela: TFormEdicaoProduto;
  Produto: TProduto;
begin
  if IdSelecionado <= 0 then
    Exit;
  try
    Produto := FService.Obter(IdSelecionado);
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
  if Produto = nil then
  begin
    Notificar(utnAviso, 'Produto não encontrado. A lista será atualizada.');
    Recarregar;
    Exit;
  end;
  try
    Tela := TFormEdicaoProduto.Create(Self, FService, Produto);
    try
      if Tela.ShowModal = mrOk then
        Recarregar;
    finally
      Tela.Free;
    end;
  finally
    Produto.Free; // a entidade e do chamador (contrato de Obter)
  end;
end;

procedure TFormListaProdutos.AoExcluir;
var
  Id: Integer;
  Resultado: TResultadoExclusao;
begin
  Id := IdSelecionado;
  if Id <= 0 then
    Exit;
  if not Notificar(utnPergunta, 'Excluir o produto "' + DescricaoSelecionada + '"?') then
    Exit;
  try
    Resultado := FService.Excluir(Id);
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
  if Resultado = reInativado then
    Notificar(utnInfo, 'Produto com vendas foi inativado (não excluído).');
  Recarregar;
end;

procedure TFormListaProdutos.AoFechar;
begin
  if Assigned(FOnFechada) then
    FOnFechada(Self)
  else
    inherited AoFechar;
end;

end.
