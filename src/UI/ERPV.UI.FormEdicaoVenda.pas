unit ERPV.UI.FormEdicaoVenda;

(*
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
  - RF7-01: Enter com o foco na grade (celula/editor inline) NAO aciona Salvar
    (EnterAcionaSalvar = False): a tecla segue para o cxGrid, que confirma a
    celula. Ordem de Tab: Cliente > Adicionar > Remover > grade > Salvar >
    Cancelar (> Cancelar venda, se habilitado) > Confirmar venda. Confirmar
    fica no cabecalho (1o painel), entao sai do percurso automatico
    (TabStop=False) e o Tab/Shift+Tab e tratado em CMDialogKey.
*)

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Variants,
  System.Generics.Collections,
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
    FBloqueadaFila: Boolean; // T53: Pendente com QUITACAO/CANCELAMENTO na fila (UX 4.2)
    FCarregando: Boolean;
    FCalculando: Boolean;
    FProximoTop: Integer;

    FDsClientes: TDataSource;
    FDsProdutos: TDataSource;
    FQryClientes: TDataSet;
    FQryProdutos: TDataSet;
    // RF7-02: cadastros inativos referenciados pela venda Pendente (rotulados
    // como inativo; a escolha nova de inativo segue recusada pelo service).
    FInativosProd: TList<Integer>;
    FClienteInativo: Boolean;

    FQuitacaoService: TQuitacaoService;
    FVendaCancelada: Boolean;
    FBtnConfirmar: TcxButton;
    FConfirmando: Boolean; // reentrancia (SG9-04): ignora cliques enfileirados
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
    function TotalDaGrade: Currency;
    procedure MostrarErroCliente(const AMsg: string);
    procedure LimparErroCliente;
    procedure MostrarErroItens(const AMsg: string);
    procedure LimparErroItens;
    function ValorInt(ALinha: Integer; ACol: TcxGridColumn): Integer;

    procedure Carregar(AVenda: TVenda);
    function VendaTemInativos(AVenda: TVenda): Boolean;
    procedure ProdutoGetDisplayText(Sender: TcxCustomGridTableItem;
      ARecord: TcxCustomGridRecord; var AText: string);
    procedure AplicarEstado;
    procedure AtualizarCancelar;
    function MontarVenda: TVenda;
  protected
    procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
    function EnterAcionaSalvar: Boolean; override;
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
    FBloqueadaFila := (FVendaId > 0) and (FStatus = svPendente) and
      FVendaService.TemPendenciaFila(FVendaId);
    FSomenteLeitura := (FStatus <> svPendente) or FBloqueadaFila;

    // Somente leitura: inclui inativos para exibir o historico corretamente.
    // RF7-02: Pendente com cliente/produto inativado depois: inclui inativos
    // nas listas (senao o lookup mostraria celula vazia). Escolher um inativo
    // continua sendo recusado por TVendaService.Salvar.
    FInativosProd := TList<Integer>.Create;
    FQryClientes := FClienteService.ListarDataSet('',
      FSomenteLeitura or VendaTemInativos(Venda));
    FQryProdutos := FProdutoService.ListarDataSet('',
      FSomenteLeitura or (FInativosProd.Count > 0));
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
  FInativosProd.Free;
  inherited Destroy;
end;

// RF7-02: preenche FInativosProd/FClienteInativo com o que a venda referencia.
function TFormEdicaoVenda.VendaTemInativos(AVenda: TVenda): Boolean;
var
  Item: TVendaItem;
  Cli: TCliente;
  Prod: TProduto;
begin
  FClienteInativo := False;
  if (AVenda <> nil) and (AVenda.Status = svPendente) then
  begin
    Cli := FClienteService.Obter(AVenda.ClienteId);
    try
      FClienteInativo := (Cli <> nil) and (not Cli.Ativo);
    finally
      Cli.Free;
    end;
    for Item in AVenda.Itens do
    begin
      Prod := FProdutoService.Obter(Item.ProdutoId);
      try
        if (Prod <> nil) and (not Prod.Ativo) and
          (FInativosProd.IndexOf(Item.ProdutoId) < 0) then
          FInativosProd.Add(Item.ProdutoId);
      finally
        Prod.Free;
      end;
    end;
  end;
  Result := FClienteInativo;
end;

procedure TFormEdicaoVenda.ProdutoGetDisplayText(Sender: TcxCustomGridTableItem;
  ARecord: TcxCustomGridRecord; var AText: string);
var
  V: Variant;
begin
  if (FInativosProd = nil) or (FInativosProd.Count = 0) or (ARecord = nil) then
    Exit;
  V := ARecord.Values[FColProduto.Index];
  if (not VarIsNull(V)) and (not VarIsEmpty(V)) and
    (FInativosProd.IndexOf(Integer(V)) >= 0) and (AText <> '') then
    AText := AText + ' (inativo)';
end;

function TFormEdicaoVenda.EnterAcionaSalvar: Boolean;
begin
  // Grade (ou editor inline, controle-filho) com foco: Enter e do cxGrid.
  Result := not ((FGrade <> nil) and (ActiveControl <> nil) and
    FGrade.ContainsControl(ActiveControl));
end;

procedure TFormEdicaoVenda.CMDialogKey(var Message: TCMDialogKey);
var
  Ultimo, Alvo: TWinControl;
  Volta: Boolean;
begin
  if (Message.CharCode = VK_TAB) and (GetKeyState(VK_CONTROL) >= 0) and
    (FBtnConfirmar <> nil) and FBtnConfirmar.Enabled and
    FBtnConfirmar.Visible and (ActiveControl <> nil) then
  begin
    Volta := GetKeyState(VK_SHIFT) < 0;
    if BtnExcluir.Visible and BtnExcluir.Enabled then
      Ultimo := BtnExcluir
    else
      Ultimo := BtnCancelar;
    Alvo := nil;
    if not Volta then
    begin
      if Ultimo.ContainsControl(ActiveControl) then
        Alvo := FBtnConfirmar
      else if FBtnConfirmar.ContainsControl(ActiveControl) then
        Alvo := FCmbCliente;
    end
    else
    begin
      if FCmbCliente.ContainsControl(ActiveControl) then
        Alvo := FBtnConfirmar
      else if FBtnConfirmar.ContainsControl(ActiveControl) then
        Alvo := Ultimo;
    end;
    if (Alvo <> nil) and Alvo.CanFocus then
    begin
      Alvo.SetFocus;
      Message.Result := 1;
      Exit;
    end;
  end;
  inherited;
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
    // RF7-04 (minimizacao de dado pessoal): a coluna CPF_CNPJ foi removida do
    // dropdown. Mascarar exigiria campo calculado no dataset ja aberto do
    // service; criar um campo persistente faz o TDataSet expor SOMENTE os
    // campos persistentes (perderia ID/NOME), e mudar a camada Dados esta fora
    // do escopo. Falha segura: nao exibir o documento.
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
  // RF7-01: FBtnConfirmar fora do percurso automatico (ver CMDialogKey); a
  // grade e a ultima do PnlCampos (cliente/barra de itens vem antes, criados antes).
  FBtnConfirmar.TabStop := False;
  FGrade.TabOrder := PnlCampos.ControlCount - 1;
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
  // RF7-01: Tab Adicionar > Remover (TabOrder nao altera o alinhamento)
  FBtnAdicionar.TabOrder := 0;
  FBtnRemover.TabOrder := 1;
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
  FColProduto.OnGetDisplayText := ProdutoGetDisplayText;

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
    if FBloqueadaFila then
      FLblBanner.Caption := '  Operação pendente de envio ao Financeiro: somente leitura. ' +
        'Use Pendências.'
    else if FStatus = svQuitada then
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
    (FStatus = svPendente) and not FBloqueadaFila;
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

function TFormEdicaoVenda.TotalDaGrade: Currency;
var
  I: Integer;
  V: Variant;
begin
  Result := 0;
  for I := 0 to FView.DataController.RecordCount - 1 do
  begin
    V := FView.DataController.Values[I, FColSubtotal.Index];
    if not (VarIsNull(V) or VarIsEmpty(V)) then
      Result := Result + VarAsType(V, varCurrency);
  end;
end;

procedure TFormEdicaoVenda.AtualizarTotal;
begin
  FLblTotal.Caption := 'Total  R$ ' + FormatCurr(cFormatoMoeda, TotalDaGrade);
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
      if FClienteInativo then
        FLblErroCliente.Caption := 'Cliente inativo (mantido nesta venda; não é possível escolher outro inativo)';
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
  if FConfirmando then
    Exit;
  FConfirmando := True;
  try
    Venda := FVendaService.Obter(FVendaId);
    try
      if Venda = nil then
        raise ERegraNegocio.Create('Venda não encontrada');
      Total := Venda.ValorTotal;
    finally
      Venda.Free;
    end;
    // A3/RF7-05: nao confirma com total desatualizado (grade != gravado)
    if TotalDaGrade <> Total then
    begin
      Notificar(utnAviso, 'Salve a venda antes de confirmar a quitação.');
      Exit;
    end;
    Espera.Desabilitar := [FBtnConfirmar, BtnSalvar, BtnCancelar, FBtnAdicionar,
      FBtnRemover, FCmbCliente, FGrade];
    Espera.Rotulo := FLblEspera;
    // Excecoes sobem ao handler global; UI restaurada no finally do helper.
    if ConfirmarVendaComFeedback(FQuitacaoService, FVendaId, Total, Espera) then
      ModalResult := mrOk; // quitada: fecha e a lista recarrega
  finally
    FConfirmando := False;
  end;
end;

procedure TFormEdicaoVenda.Gravar;
begin
  // gravacao ja feita em Validar (ver nota no cabecalho da unit)
end;

procedure TFormEdicaoVenda.AoExcluir;
begin
  if (FQuitacaoService = nil) or (FVendaId <= 0) or (FStatus <> svPendente) or
    FBloqueadaFila then
    Exit;
  // Regra no TQuitacaoService (T43); a tela so exibe (dialogo T44).
  if CancelarVendaComDialogo(Self, FQuitacaoService, FVendaId) then
  begin
    FVendaCancelada := True;
    ModalResult := mrOk; // a lista recarrega e exibe o banner Info
  end;
end;

end.
