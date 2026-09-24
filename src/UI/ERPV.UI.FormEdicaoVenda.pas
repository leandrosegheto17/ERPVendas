unit ERPV.UI.FormEdicaoVenda;

{
  T32 (Lote 7) - Venda mestre/detalhe (UX-SPEC 2.5, 4.1, 4.2, 5; ADR-011).
  Herda TFormBaseEdicao (T15). 100% em codigo (sem .dfm). Modelo: T20/T24.

  CONTRATO (usado pela T31):
    TFormEdicaoVenda.Create(AOwner, AVendaService, AClienteService,
      AProdutoService, AVendaId)
    AVendaId = 0 -> nova venda. ShowModal = mrOk se gravou, senao mrCancel.
    Os servicos sao do chamador (a tela nunca os libera).
    T44: apos ShowModal, VendaCancelada = True se a venda foi cancelada pelo
    botao "Cancelar venda" (a tela fecha com mrOk; o chamador exibe o banner).

  Decisoes:
  - Sem SQL/regra na tela. Validacao, total e snapshot de preco vem do
    TVendaService (T27-T29). A tela envia SO cliente, produto e quantidade;
    preco e total nunca sao enviados como fonte de verdade. Preco/subtotal/
    total exibidos sao previa calculada a partir do preco do produto (item novo)
    ou do snapshot lido (item ja gravado); apos Salvar a venda e relida por
    Obter.
  - TFormBaseEdicao.Confirmar faz Validar -> Gravar -> mrOk; a chamada a Salvar
    acontece DENTRO de Validar (mesmo padrao de T20/T24); Gravar fica vazio.
  - Venda nao Pendente (Quitada/Cancelada): todos os controles desabilitados,
    Salvar oculto, Cancelar vira "Fechar", banner info (UX 2.5/4.2).
  - "Cancelar venda" (T44): botao perigoso (reaproveita o Excluir da base)
    abre o dialogo ERPV.UI.FormCancelamentoVenda; habilitado so em venda
    Pendente ja gravada e com QuitacaoService injetado (UX 4.2). Quitada/
    Cancelada/nova: desabilitado. Alteracoes nao salvas na tela sao descartadas
    ao cancelar (vale a venda gravada). Bloqueio por fila pendente e da T53.
  - "Confirmar venda" (quitacao, T42): botao no cabecalho, habilitado so para
    venda Pendente ja gravada e com QuitacaoService injetado (propriedade,
    setada pela lista; contrato do construtor inalterado). Fluxo/mensagens em
    ERPV.UI.ConfirmacaoVenda. Banner de fila pendente: T53.
  - Listas de lookup: clientes/produtos ATIVOS quando Pendente; todos quando
    somente leitura (para exibir itens/cliente historicos inativos).
}

interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Data.DB,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  cxEdit, cxGraphics, cxControls, cxStyles, cxCustomData, cxDataStorage,
  cxCurrencyEdit, cxSpinEdit, cxDropDownEdit, cxDBLookupComboBox, cxButtons,
  cxGridCustomTableView, cxGridTableView, cxGridLevel, cxGrid,
  ERPV.Core.Erros,
  ERPV.Dominio.Enums, ERPV.Dominio.Cliente, ERPV.Dominio.Produto,
  ERPV.Dominio.Venda, ERPV.Dominio.VendaItem,
  ERPV.Negocio.VendaService, ERPV.Negocio.ClienteService,
  ERPV.Negocio.ProdutoService, ERPV.Negocio.QuitacaoService,
  ERPV.UI.Tokens, ERPV.UI.Tema, ERPV.UI.Icones, ERPV.UI.ConfirmacaoVenda,
  ERPV.UI.FormBaseEdicao, ERPV.UI.FormCancelamentoVenda;

type
  TFormEdicaoVenda = class(TFormBaseEdicao)
  private
    FVendaService: TVendaService;
    FClienteService: TClienteService;
    FProdutoService: TProdutoService;
    FVendaId: Integer;
    FStatus: TStatusVenda;
    FSomenteLeitura: Boolean;
    FCarregando: Boolean;
    FCalculando: Boolean;
    FProximoTop: Integer;

    FDsClientes: TDataSource;
    FDsProdutos: TDataSource;
    FQryClientes: TDataSet;
    FQryProdutos: TDataSet;

    FQuitacaoService: TQuitacaoService;
    FVendaCancelada: Boolean;
    FBtnConfirmar: TcxButton;
    FLblEspera: TLabel;
    FLblTitulo: TLabel;
    FPnlChip: TPanel;
    FPnlBanner: TPanel;
    FLblBanner: TLabel;
    FLblDatas: TLabel;
    FMoldCliente: TPanel;
    FCmbCliente: TcxLookupComboBox;
    FLblErroCliente: TLabel;
    FBtnAdicionar: TcxButton;
    FBtnRemover: TcxButton;
    FGrade: TcxGrid;
    FNivel: TcxGridLevel;
    FView: TcxGridTableView;
    FColProduto: TcxGridColumn;
    FColQtd: TcxGridColumn;
    FColPreco: TcxGridColumn;
    FColSubtotal: TcxGridColumn;
    FColProdutoAnt: TcxGridColumn; // oculta: detecta troca de produto na linha
    FLblErroItens: TLabel;
    FLblTotal: TLabel;

    procedure MontarTela;
    procedure MontarGrade;
    function NovoPainelTopo(AAltura: Integer): TPanel;
    procedure MontarBotoes;
    procedure ConfigurarColunaMoeda(ACol: TcxGridColumn);

    procedure ClienteChange(Sender: TObject);
    procedure AdicionarClick(Sender: TObject);
    procedure RemoverClick(Sender: TObject);
    procedure ConfirmarVendaClick(Sender: TObject);
    procedure SetQuitacaoService(AValor: TQuitacaoService);
    procedure DadosMudaram(ASender: TObject);

    function PrecoDoProduto(AProdutoId: Integer): Currency;
    procedure RecalcularLinhas;
    procedure AtualizarTotal;
    procedure MostrarErroCliente(const AMsg: string);
    procedure LimparErroCliente;
    procedure MostrarErroItens(const AMsg: string);
    procedure LimparErroItens;
    function ValorInt(ALinha: Integer; ACol: TcxGridColumn): Integer;

    procedure Carregar(AVenda: TVenda);
    procedure AplicarEstado;
    procedure AtualizarCancelar;
    function MontarVenda: TVenda;
  protected
    function Validar: Boolean; override;
    procedure Gravar; override;
    procedure AoExcluir; override; // = "Cancelar venda" (T44)
  public
    /// <summary>Injetado pela lista (T42). Sem ele, Confirmar fica desabilitado.</summary>
    property QuitacaoService: TQuitacaoService read FQuitacaoService
      write SetQuitacaoService;
    constructor Create(AOwner: TComponent; AVendaService: TVendaService;
      AClienteService: TClienteService; AProdutoService: TProdutoService;
      AVendaId: Integer); reintroduce;
    destructor Destroy; override;
    /// <summary>True se a venda foi cancelada por esta tela (T44).</summary>
    property VendaCancelada: Boolean read FVendaCancelada;
  end;

implementation

const
  cAlturaCabecalho = 32;
  cAlturaLinhaMeta = 24;
  cAlturaCliente = 18 + 32 + 18;   // rotulo + moldura + erro
  cAlturaBarraItens = 36;
  cAlturaBanner = 32;
  cAlturaTotal = 44;
  cAlturaErro = 18;
  cFormatoMoeda = ',0.00;-,0.00';

{ TFormEdicaoVenda }

constructor TFormEdicaoVenda.Create(AOwner: TComponent;
  AVendaService: TVendaService; AClienteService: TClienteService;
  AProdutoService: TProdutoService; AVendaId: Integer);
var
  Venda: TVenda;
begin
  inherited Create(AOwner);
  if (AVendaService = nil) or (AClienteService = nil) or (AProdutoService = nil) then
    raise EArgumentException.Create('TFormEdicaoVenda: serviço não informado.');
  FVendaService := AVendaService;
  FClienteService := AClienteService;
  FProdutoService := AProdutoService;
  FVendaId := AVendaId;
  FStatus := svPendente;

  Venda := nil;
  try
    if FVendaId > 0 then
    begin
      Venda := FVendaService.Obter(FVendaId);
      if Venda = nil then
        raise ERegraNegocio.Create('Venda não encontrada');
      FStatus := Venda.Status;
    end;
    FSomenteLeitura := FStatus <> svPendente;

    // Somente leitura: inclui inativos para exibir o historico corretamente.
    FQryClientes := FClienteService.ListarDataSet('', FSomenteLeitura);
    FQryProdutos := FProdutoService.ListarDataSet('', FSomenteLeitura);
    FDsClientes := TDataSource.Create(Self);
    FDsClientes.DataSet := FQryClientes;
    FDsProdutos := TDataSource.Create(Self);
    FDsProdutos.DataSet := FQryProdutos;

    Caption := 'Venda';
    MontarTela;
    Carregar(Venda);
    AplicarEstado;
  finally
    Venda.Free;
  end;
end;

destructor TFormEdicaoVenda.Destroy;
begin
  // Os componentes ligados aos DataSets sao liberados pelo inherited; os
  // TDataSource soltam o DataSet ao serem destruidos/desligados.
  if FDsClientes <> nil then
    FDsClientes.DataSet := nil;
  if FDsProdutos <> nil then
    FDsProdutos.DataSet := nil;
  FQryClientes.Free;
  FQryProdutos.Free;
  inherited Destroy;
end;

{ ---- construcao da tela ---- }

function TFormEdicaoVenda.NovoPainelTopo(AAltura: Integer): TPanel;
begin
  Result := TPanel.Create(Self);
  Result.Parent := PnlCampos;
  Result.BevelOuter := bvNone;
  Result.ParentBackground := False;
  Result.Color := clERPVSuperficie;
  Result.Align := alTop;
  Result.Height := AAltura;
  Result.Top := FProximoTop;
  Inc(FProximoTop, AAltura);
end;

procedure TFormEdicaoVenda.ConfigurarColunaMoeda(ACol: TcxGridColumn);
begin
  ACol.PropertiesClass := TcxCurrencyEditProperties;
  with TcxCurrencyEditProperties(ACol.Properties) do
  begin
    DisplayFormat := cFormatoMoeda;
    DecimalPlaces := 2;
    Alignment.Horz := taRightJustify;
  end;
  ACol.HeaderAlignmentHorz := taRightJustify;
  ACol.DataBinding.ValueTypeClass := TcxCurrencyValueType;
  ACol.Options.Editing := False;   // preço/subtotal somente leitura (RN-04)
  ACol.Options.Focusing := False;
end;

procedure TFormEdicaoVenda.MontarTela;
var
  Pnl: TPanel;
  L: TLabel;
begin
  FProximoTop := 0;
  PnlCampos.AutoSize := False;
  ClientWidth := EscalarPx(760);
  ClientHeight := EscalarPx(600);

  // Cabecalho: titulo + chip de status (texto + cor, nunca so cor)
  Pnl := NovoPainelTopo(EscalarPx(cAlturaCabecalho));
  FPnlChip := TPanel.Create(Self);
  FPnlChip.Parent := Pnl;
  FPnlChip.Align := alRight;
  FPnlChip.Width := EscalarPx(120);
  FPnlChip.BevelOuter := bvNone;
  FPnlChip.ParentBackground := False;
  FPnlChip.Font.Name := ERPVFontePrincipal;
  FPnlChip.Font.Size := ERPVTamRotuloCampo;
  FPnlChip.Font.Style := [fsBold];
  // T42: Confirmar venda (quitacao) + rotulo de espera no cabecalho
  FBtnConfirmar := TcxButton.Create(Self);
  FBtnConfirmar.Parent := Pnl;
  FBtnConfirmar.Align := alRight;
  FBtnConfirmar.Width := EscalarPx(140);
  FBtnConfirmar.Caption := '&Confirmar venda';
  FBtnConfirmar.Enabled := False;
  FBtnConfirmar.OnClick := ConfirmarVendaClick;
  EstilizarBotao(FBtnConfirmar, upbPrimario);
  AplicarIcone(FBtnConfirmar, ERPVIconeConfirmar);
  FLblEspera := TLabel.Create(Self);
  FLblEspera.Parent := Pnl;
  FLblEspera.Align := alRight;
  FLblEspera.AlignWithMargins := True;
  FLblEspera.Layout := tlCenter;
  FLblEspera.Font.Name := ERPVFontePrincipal;
  FLblEspera.Font.Size := ERPVTamCorpo;
  FLblEspera.Font.Color := clERPVTextoSecundario;
  FLblEspera.Visible := False;
  FLblTitulo := TLabel.Create(Self);
  FLblTitulo.Parent := Pnl;
  FLblTitulo.Align := alClient;
  FLblTitulo.Layout := tlCenter;
  FLblTitulo.Font.Name := ERPVFontePrincipal;
  FLblTitulo.Font.Size := ERPVTamSubtitulo;
  FLblTitulo.Font.Style := [fsBold];
  FLblTitulo.Font.Color := clERPVTextoPrincipal;

  // Banner (linha unica, icone + texto) - so quando nao Pendente
  FPnlBanner := NovoPainelTopo(EscalarPx(cAlturaBanner));
  FPnlBanner.Color := clERPVInfoFundo;
  FLblBanner := TLabel.Create(Self);
  FLblBanner.Parent := FPnlBanner;
  FLblBanner.Align := alClient;
  FLblBanner.Layout := tlCenter;
  FLblBanner.Font.Name := ERPVFontePrincipal;
  FLblBanner.Font.Size := ERPVTamCorpo;
  FLblBanner.Font.Color := clERPVInfoTexto;
  FPnlBanner.Visible := False;

  // Datas (somente leitura)
  Pnl := NovoPainelTopo(EscalarPx(cAlturaLinhaMeta));
  FLblDatas := TLabel.Create(Self);
  FLblDatas.Parent := Pnl;
  FLblDatas.Align := alClient;
  FLblDatas.Layout := tlCenter;
  FLblDatas.Font.Name := ERPVFontePrincipal;
  FLblDatas.Font.Size := ERPVTamCorpo;
  FLblDatas.Font.Color := clERPVTextoSecundario;

  // Cliente (lookup de clientes ativos) - rotulo, moldura, erro
  Pnl := NovoPainelTopo(EscalarPx(cAlturaCliente));
  L := TLabel.Create(Self);
  L.Parent := Pnl;
  L.AutoSize := False;
  L.Align := alTop;
  L.Height := EscalarPx(18);
  L.Layout := tlCenter;
  L.Caption := 'Cliente *';
  L.Font.Name := ERPVFontePrincipal;
  L.Font.Size := ERPVTamRotuloCampo;
  L.Font.Style := [fsBold];
  L.Font.Color := clERPVTextoPrincipal;
  FMoldCliente := TPanel.Create(Self);
  FMoldCliente.Parent := Pnl;
  FMoldCliente.BevelOuter := bvNone;
  FMoldCliente.ParentBackground := False;
  FMoldCliente.Color := clERPVBordaCampo;
  FMoldCliente.Padding.SetBounds(1, 1, 1, 1);
  FMoldCliente.Align := alTop;
  FMoldCliente.Height := EscalarPx(32);
  FMoldCliente.Top := EscalarPx(18);
  FLblErroCliente := TLabel.Create(Self);
  FLblErroCliente.Parent := Pnl;
  FLblErroCliente.AutoSize := False;
  FLblErroCliente.Align := alTop;
  FLblErroCliente.Height := EscalarPx(cAlturaErro);
  FLblErroCliente.Layout := tlCenter;
  FLblErroCliente.Font.Name := ERPVFontePrincipal;
  FLblErroCliente.Font.Size := ERPVTamCorpo;
  FLblErroCliente.Font.Color := clERPVErroTexto;
  FLblErroCliente.Top := EscalarPx(50);

  FCmbCliente := TcxLookupComboBox.Create(Self);
  FCmbCliente.Parent := FMoldCliente;
  FCmbCliente.Align := alClient;
  FCmbCliente.Style.BorderStyle := ebsNone;
  with FCmbCliente.Properties do
  begin
    ListSource := FDsClientes;
    KeyFieldNames := 'ID';
    DropDownListStyle := lsFixedList;
    ListColumns.Clear;
    ListColumns.Add.FieldName := 'NOME';
    ListColumns.Add.FieldName := 'CPF_CNPJ';
    OnChange := ClienteChange;
  end;

  // Barra de itens: rotulo + Adicionar/Remover
  MontarBotoes;

  // Total (fixo embaixo), erro dos itens acima dele; grade ocupa o resto
  Pnl := TPanel.Create(Self);
  Pnl.Parent := PnlCampos;
  Pnl.Align := alBottom;
  Pnl.BevelOuter := bvNone;
  Pnl.ParentBackground := False;
  Pnl.Color := clERPVSuperficie;
  Pnl.Height := EscalarPx(cAlturaTotal);
  FLblTotal := TLabel.Create(Self);
  FLblTotal.Parent := Pnl;
  FLblTotal.Align := alClient;
  FLblTotal.Alignment := taRightJustify;
  FLblTotal.Layout := tlCenter;
  FLblTotal.Font.Name := ERPVFontePrincipal;
  FLblTotal.Font.Size := ERPVTamTotalVenda;
  FLblTotal.Font.Style := [fsBold];
  FLblTotal.Font.Color := clERPVTextoPrincipal;

  FLblErroItens := TLabel.Create(Self);
  FLblErroItens.Parent := PnlCampos;
  FLblErroItens.AutoSize := False;
  FLblErroItens.Align := alBottom;
  FLblErroItens.Height := EscalarPx(cAlturaErro);
  FLblErroItens.Layout := tlCenter;
  FLblErroItens.Font.Name := ERPVFontePrincipal;
  FLblErroItens.Font.Size := ERPVTamCorpo;
  FLblErroItens.Font.Color := clERPVErroTexto;

  MontarGrade;
  ExibirExcluir := True; // reaproveitado como "Cancelar venda" (perigoso)
  BtnExcluir.Caption := 'Cancelar venda';
  // Habilitacao por status (UX 4.2) em AtualizarCancelar.
  BtnExcluir.Enabled := False;
end;

procedure TFormEdicaoVenda.MontarBotoes;
var
  Pnl: TPanel;
  L: TLabel;
begin
  Pnl := NovoPainelTopo(EscalarPx(cAlturaBarraItens));
  L := TLabel.Create(Self);
  L.Parent := Pnl;
  L.Align := alClient;
  L.Layout := tlBottom;
  L.Caption := 'Itens';
  L.Font.Name := ERPVFontePrincipal;
  L.Font.Size := ERPVTamSubtitulo;
  L.Font.Style := [fsBold];
  L.Font.Color := clERPVTextoPrincipal;

  FBtnRemover := TcxButton.Create(Self);
  FBtnRemover.Parent := Pnl;
  FBtnRemover.Align := alRight;
  FBtnRemover.Width := EscalarPx(100);
  FBtnRemover.Caption := 'Remover';
  FBtnRemover.OnClick := RemoverClick;
  EstilizarBotao(FBtnRemover, upbSecundario);

  FBtnAdicionar := TcxButton.Create(Self);
  FBtnAdicionar.Parent := Pnl;
  FBtnAdicionar.Align := alRight;
  FBtnAdicionar.Width := EscalarPx(120);
  FBtnAdicionar.Caption := '+ Adicionar';
  FBtnAdicionar.OnClick := AdicionarClick;
  EstilizarBotao(FBtnAdicionar, upbSecundario);
  FBtnAdicionar.Left := 0; // alRight empilha da direita: Remover fica mais a direita
end;

procedure TFormEdicaoVenda.MontarGrade;
begin
  FGrade := TcxGrid.Create(Self);
  FGrade.Parent := PnlCampos;
  FGrade.Align := alClient;
  FNivel := FGrade.Levels.Add;
  FView := FGrade.CreateView(TcxGridTableView) as TcxGridTableView;
  FNivel.GridView := FView;
  ConfigurarGrade(FView);
  FView.OptionsData.Editing := True;
  // ConfigurarGrade deixa CellSelect=False (lista de linha inteira); aqui a
  // grade e editavel por celula, senao o editor de Produto/Qtd nunca abre.
  FView.OptionsSelection.CellSelect := True;
  FView.OptionsData.Appending := False;
  FView.OptionsData.Deleting := False;
  FView.OptionsData.Inserting := False;
  FView.OptionsView.NoDataToDisplayInfoText := 'Nenhum item. Use + Adicionar.';

  FColProduto := FView.CreateColumn;
  FColProduto.Caption := 'Produto';
  FColProduto.Width := EscalarPx(320);
  FColProduto.DataBinding.ValueTypeClass := TcxIntegerValueType;
  FColProduto.PropertiesClass := TcxLookupComboBoxProperties;
  with TcxLookupComboBoxProperties(FColProduto.Properties) do
  begin
    ListSource := FDsProdutos;
    KeyFieldNames := 'ID';
    DropDownListStyle := lsFixedList;
    ImmediatePost := True;
    ListColumns.Clear;
    ListColumns.Add.FieldName := 'DESCRICAO';
    ListColumns.Add.FieldName := 'UNIDADE';
  end;

  FColQtd := FView.CreateColumn;
  FColQtd.Caption := 'Qtd';
  FColQtd.Width := EscalarPx(70);
  FColQtd.DataBinding.ValueTypeClass := TcxIntegerValueType;
  FColQtd.PropertiesClass := TcxSpinEditProperties;
  with TcxSpinEditProperties(FColQtd.Properties) do
  begin
    ValueType := vtInt;   // quantidade inteira
    MinValue := 1;
    MaxValue := 999999;
    ImmediatePost := True;
    Alignment.Horz := taRightJustify;
  end;
  FColQtd.HeaderAlignmentHorz := taRightJustify;

  FColPreco := FView.CreateColumn;
  FColPreco.Caption := 'Preço unit.';
  FColPreco.Width := EscalarPx(110);
  ConfigurarColunaMoeda(FColPreco);

  FColSubtotal := FView.CreateColumn;
  FColSubtotal.Caption := 'Subtotal';
  FColSubtotal.Width := EscalarPx(110);
  ConfigurarColunaMoeda(FColSubtotal);

  FColProdutoAnt := FView.CreateColumn;
  FColProdutoAnt.Visible := False;
  FColProdutoAnt.DataBinding.ValueTypeClass := TcxIntegerValueType;

  FView.DataController.OnDataChanged := DadosMudaram;
end;

{ ---- estado visual ---- }

procedure TFormEdicaoVenda.MostrarErroCliente(const AMsg: string);
begin
  // icone (U+2716) + texto: nunca so cor (UX 5)
  FLblErroCliente.Caption := Char($2716) + ' ' + AMsg;
  FMoldCliente.Color := clERPVErroTexto;
end;

procedure TFormEdicaoVenda.LimparErroCliente;
begin
  FLblErroCliente.Caption := '';
  FMoldCliente.Color := clERPVBordaCampo;
end;

procedure TFormEdicaoVenda.MostrarErroItens(const AMsg: string);
begin
  FLblErroItens.Caption := Char($2716) + ' ' + AMsg;
end;

procedure TFormEdicaoVenda.LimparErroItens;
begin
  FLblErroItens.Caption := '';
end;

procedure TFormEdicaoVenda.AplicarEstado;
begin
  if FVendaId > 0 then
    FLblTitulo.Caption := Format('Venda nº %d', [FVendaId])
  else
    FLblTitulo.Caption := 'Nova venda';

  // chip: texto + cor (nunca so cor)
  FPnlChip.Caption := UpperCase(StatusVendaToStr(FStatus));
  case FStatus of
    svPendente:
      begin
        FPnlChip.Color := clERPVAvisoFundo;
        FPnlChip.Font.Color := clERPVAvisoTexto;
      end;
    svQuitada:
      begin
        FPnlChip.Color := clERPVSucessoFundo;
        FPnlChip.Font.Color := clERPVSucessoTexto;
      end;
  else
    FPnlChip.Color := clERPVInativoFundo;
    FPnlChip.Font.Color := clERPVInativoTexto;
  end;

  if FSomenteLeitura then
  begin
    if FStatus = svQuitada then
      FLblBanner.Caption := '  Venda Quitada: somente leitura'
    else
      FLblBanner.Caption := '  Venda Cancelada: somente leitura';
    FPnlBanner.Visible := True;
    FCmbCliente.Enabled := False;
    FCmbCliente.Properties.ReadOnly := True;
    FView.OptionsData.Editing := False;
    FBtnAdicionar.Enabled := False;
    FBtnRemover.Enabled := False;
    BtnSalvar.Visible := False;
    BtnCancelar.Caption := 'Fechar';
  end;
  AtualizarCancelar;
end;

procedure TFormEdicaoVenda.AtualizarCancelar;
begin
  // Cancelar venda: so Pendente ja gravada e com servico injetado (UX 4.2).
  BtnExcluir.Enabled := (FQuitacaoService <> nil) and (FVendaId > 0) and
    (FStatus = svPendente);
  if not BtnExcluir.Enabled then
  begin
    BtnExcluir.Hint := 'Somente venda Pendente já gravada pode ser cancelada.';
    BtnExcluir.ShowHint := True;
  end
  else
    BtnExcluir.ShowHint := False;
end;

{ ---- eventos ---- }

procedure TFormEdicaoVenda.ClienteChange(Sender: TObject);
begin
  if FCarregando then
    Exit;
  LimparErroCliente;
  MarcarModificado;
end;

procedure TFormEdicaoVenda.AdicionarClick(Sender: TObject);
var
  N: Integer;
begin
  if FSomenteLeitura then
    Exit;
  LimparErroItens;
  FCalculando := True;
  try
    N := FView.DataController.RecordCount;
    FView.DataController.RecordCount := N + 1;
    FView.DataController.Values[N, FColQtd.Index] := 1;
    FView.DataController.Values[N, FColPreco.Index] := Currency(0);
    FView.DataController.Values[N, FColSubtotal.Index] := Currency(0);
    FView.DataController.Values[N, FColProdutoAnt.Index] := 0;
  finally
    FCalculando := False;
  end;
  FView.DataController.FocusedRecordIndex := N;
  FView.Controller.FocusedItem := FColProduto;
  FGrade.SetFocus;
  MarcarModificado;
  AtualizarTotal;
end;

procedure TFormEdicaoVenda.RemoverClick(Sender: TObject);
begin
  if FSomenteLeitura then
    Exit;
  if FView.DataController.FocusedRecordIndex < 0 then
    Exit;
  FView.DataController.DeleteFocused;
  MarcarModificado;
  AtualizarTotal;
end;

procedure TFormEdicaoVenda.DadosMudaram(ASender: TObject);
begin
  if FCarregando or FCalculando then
    Exit;
  LimparErroItens;
  RecalcularLinhas;
  MarcarModificado;
end;

{ ---- calculo (somente previa de exibicao; a fonte de verdade e o servico) ---- }

function TFormEdicaoVenda.ValorInt(ALinha: Integer; ACol: TcxGridColumn): Integer;
var
  V: Variant;
begin
  V := FView.DataController.Values[ALinha, ACol.Index];
  if VarIsNull(V) or VarIsEmpty(V) then
    Result := 0
  else
    Result := VarAsType(V, varInteger);
end;

function TFormEdicaoVenda.PrecoDoProduto(AProdutoId: Integer): Currency;
begin
  Result := 0;
  if (AProdutoId > 0) and FQryProdutos.Locate('ID', AProdutoId, []) then
    Result := FQryProdutos.FieldByName('PRECO_UNITARIO').AsCurrency;
end;

procedure TFormEdicaoVenda.RecalcularLinhas;
var
  I, ProdId, Qtd: Integer;
  Preco: Currency;
  V: Variant;
begin
  FCalculando := True;
  try
    for I := 0 to FView.DataController.RecordCount - 1 do
    begin
      ProdId := ValorInt(I, FColProduto);
      if ProdId <> ValorInt(I, FColProdutoAnt) then
      begin
        // produto trocado/escolhido: preco copiado do produto (snapshot no Salvar)
        FView.DataController.Values[I, FColPreco.Index] := PrecoDoProduto(ProdId);
        FView.DataController.Values[I, FColProdutoAnt.Index] := ProdId;
      end;
      Qtd := ValorInt(I, FColQtd);
      V := FView.DataController.Values[I, FColPreco.Index];
      if VarIsNull(V) or VarIsEmpty(V) then
        Preco := 0
      else
        Preco := VarAsType(V, varCurrency);
      FView.DataController.Values[I, FColSubtotal.Index] := Qtd * Preco;
    end;
  finally
    FCalculando := False;
  end;
  AtualizarTotal;
end;

procedure TFormEdicaoVenda.AtualizarTotal;
var
  I: Integer;
  Total: Currency;
  V: Variant;
begin
  Total := 0;
  for I := 0 to FView.DataController.RecordCount - 1 do
  begin
    V := FView.DataController.Values[I, FColSubtotal.Index];
    if not (VarIsNull(V) or VarIsEmpty(V)) then
      Total := Total + VarAsType(V, varCurrency);
  end;
  FLblTotal.Caption := 'Total  R$ ' + FormatCurr(cFormatoMoeda, Total);
end;

{ ---- dados ---- }

procedure TFormEdicaoVenda.Carregar(AVenda: TVenda);
var
  Item: TVendaItem;
  N: Integer;
begin
  FCarregando := True;
  try
    FView.DataController.RecordCount := 0;
    if AVenda = nil then
    begin
      FCmbCliente.EditValue := Null;
      FLblDatas.Caption := 'Data: ' + FormatDateTime('dd/mm/yyyy', Date);
    end
    else
    begin
      FCmbCliente.EditValue := AVenda.ClienteId;
      FLblDatas.Caption := 'Data: ' + FormatDateTime('dd/mm/yyyy', AVenda.DataVenda);
      if AVenda.TemDataQuitacao then
        FLblDatas.Caption := FLblDatas.Caption + '     Quitada em: ' +
          FormatDateTime('dd/mm/yyyy', AVenda.DataQuitacao)
      else
        FLblDatas.Caption := FLblDatas.Caption + '     Quitada em: --/--/----';
      for Item in AVenda.Itens do
      begin
        N := FView.DataController.RecordCount;
        FView.DataController.RecordCount := N + 1;
        FView.DataController.Values[N, FColProduto.Index] := Item.ProdutoId;
        FView.DataController.Values[N, FColProdutoAnt.Index] := Item.ProdutoId;
        FView.DataController.Values[N, FColQtd.Index] := Item.Quantidade;
        FView.DataController.Values[N, FColPreco.Index] := Item.PrecoUnitario; // snapshot
        FView.DataController.Values[N, FColSubtotal.Index] := Item.Subtotal;
      end;
    end;
  finally
    FCarregando := False;
  end;
  if AVenda <> nil then
    FLblTotal.Caption := 'Total  R$ ' + FormatCurr(cFormatoMoeda, AVenda.ValorTotal)
  else
    AtualizarTotal;
end;

// Envia SO cliente, produto e quantidade (preco/total = calculo do servico).
function TFormEdicaoVenda.MontarVenda: TVenda;
var
  I: Integer;
  Item: TVendaItem;
begin
  Result := TVenda.Create;
  try
    Result.Id := FVendaId;
    if VarIsNull(FCmbCliente.EditValue) or VarIsEmpty(FCmbCliente.EditValue) then
      Result.ClienteId := 0
    else
      Result.ClienteId := VarAsType(FCmbCliente.EditValue, varInteger);
    for I := 0 to FView.DataController.RecordCount - 1 do
    begin
      Item := TVendaItem.Create;
      Item.ProdutoId := ValorInt(I, FColProduto);
      Item.Quantidade := ValorInt(I, FColQtd);
      Result.Itens.Add(Item);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TFormEdicaoVenda.Validar: Boolean;
var
  Venda, Relida: TVenda;
  I: Integer;
begin
  Result := False;
  if FSomenteLeitura then
    Exit;
  LimparErroCliente;
  LimparErroItens;

  // verificacoes visuais simples (mesmas mensagens do servico)
  if VarIsNull(FCmbCliente.EditValue) or VarIsEmpty(FCmbCliente.EditValue) then
  begin
    MostrarErroCliente('Informe o cliente');
    FCmbCliente.SetFocus;
    Exit;
  end;
  if FView.DataController.RecordCount < 1 then
  begin
    MostrarErroItens('A venda deve ter ao menos um item');
    Exit;
  end;
  for I := 0 to FView.DataController.RecordCount - 1 do
    if ValorInt(I, FColProduto) <= 0 then
    begin
      MostrarErroItens('Informe o produto de todos os itens');
      Exit;
    end
    else if ValorInt(I, FColQtd) <= 0 then
    begin
      MostrarErroItens('A quantidade deve ser maior que zero');
      Exit;
    end;

  Venda := MontarVenda;
  try
    try
      FVendaId := FVendaService.Salvar(Venda);
    except
      on E: EValidacao do
      begin
        if SameText(E.Campo, 'Cliente') then
        begin
          MostrarErroCliente(E.Message);
          FCmbCliente.SetFocus;
        end
        else if SameText(E.Campo, 'Itens') or SameText(E.Campo, 'Produto')
          or SameText(E.Campo, 'Quantidade') then
          MostrarErroItens(E.Message)
        else
          Notificar(utnErro, E.Message);
        Exit;
      end;
      on E: ERegraNegocio do
      begin
        Notificar(utnErro, E.Message);
        Exit;
      end;
    end;
  finally
    Venda.Free;
  end;

  // reler o que foi gravado (total/precos recalculados pelo servico)
  Relida := FVendaService.Obter(FVendaId);
  try
    if Relida <> nil then
      Carregar(Relida);
  finally
    Relida.Free;
  end;
  Result := True;
end;

procedure TFormEdicaoVenda.SetQuitacaoService(AValor: TQuitacaoService);
begin
  FQuitacaoService := AValor;
  // UX 4.2: so venda Pendente ja gravada (fila pendente = T53)
  FBtnConfirmar.Enabled := (FQuitacaoService <> nil) and (FVendaId > 0) and
    not FSomenteLeitura;
  AtualizarCancelar;
end;

procedure TFormEdicaoVenda.ConfirmarVendaClick(Sender: TObject);
var
  Espera: TControlesEspera;
  Venda: TVenda;
  Total: Currency;
begin
  if (FQuitacaoService = nil) or (FVendaId <= 0) or FSomenteLeitura then
    Exit;
  Venda := FVendaService.Obter(FVendaId);
  try
    if Venda = nil then
      raise ERegraNegocio.Create('Venda não encontrada');
    Total := Venda.ValorTotal;
  finally
    Venda.Free;
  end;
  Espera.Desabilitar := [FBtnConfirmar, BtnSalvar, BtnCancelar, FBtnAdicionar,
    FBtnRemover, FCmbCliente, FGrade];
  Espera.Rotulo := FLblEspera;
  // Excecoes sobem ao handler global; UI restaurada no finally do helper.
  if ConfirmarVendaComFeedback(FQuitacaoService, FVendaId, Total, Espera) then
    ModalResult := mrOk; // quitada: fecha e a lista recarrega
end;

procedure TFormEdicaoVenda.Gravar;
begin
  // gravacao ja feita em Validar (ver nota no cabecalho da unit)
end;

procedure TFormEdicaoVenda.AoExcluir;
begin
  if (FQuitacaoService = nil) or (FVendaId <= 0) or (FStatus <> svPendente) then
    Exit;
  // Regra no TQuitacaoService (T43); a tela so exibe (dialogo T44).
  if CancelarVendaComDialogo(Self, FQuitacaoService, FVendaId) then
  begin
    FVendaCancelada := True;
    ModalResult := mrOk; // a lista recarrega e exibe o banner Info
  end;
end;

end.
