unit ERPV.UI.FormPendencias;

(*
  T52 - Pendencias de Integracao (UX-SPEC 2.7, RF-23). Herda TFormBaseLista
  (embutida no shell, mesmo padrao de FormListaClientes). Construida em codigo.

  - Grade cxGrid somente leitura ligada a IFilaRepository.Listar: Venda, Tipo,
    Criado em, Tent., Situacao, Ultimo erro (ID e TIPO cru ficam ocultos/lidos
    da linha para o Reenviar).
  - Barra: [Reenviar selecionado] [Atualizar] [x] Somente pendentes (marcado por
    padrao) ... [Fechar]. Novo/Editar/Excluir da base ficam ocultos (nao se
    aplicam aqui). "Reenviar todos" e P2 (T65), fora deste escopo.
  - Reenviar: TFilaService.Reenviar(ID, VENDA_ID, TIPO); resultado vira
    mensagem-resumo via Notificar (Info "Item concluido." / Aviso "Ainda nao foi
    possivel: <erro>"); depois recarrega (item concluido some do filtro).
  - Vazio: "Nenhuma pendencia."; erro ao listar: banner + "Tentar novamente".
  - Sem log e sem exibir dado pessoal alem do que a fila ja guarda (erro ja
    mascarado no repositorio, RF9-05).
  - O TDataSet de Listar e de posse desta tela (liberado ao recarregar/fechar).
*)

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.UITypes, System.Variants, Data.DB,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  cxControls, cxTextEdit, cxGraphics, cxClasses, cxCustomData, cxData, cxDBData,
  cxGridCustomView, cxGridCustomTableView, cxGridTableView, cxGridDBTableView,
  cxGridLevel, cxGrid, cxButtons,
  ERPV.UI.Tokens, ERPV.UI.Tema, ERPV.UI.FormBaseLista,
  ERPV.Dominio.Contratos.IFilaRepository, ERPV.Negocio.FilaService;

type
  TFormPendencias = class(TFormBaseLista)
  private
    FFila: IFilaRepository;
    FService: TFilaService;
    FDataSet: TDataSet;
    FDataSource: TDataSource;
    FOnFechada: TNotifyEvent;
    FOnFilaAlterada: TNotifyEvent;
    FPnlFiltros: TPanel;
    FBtnReenviar: TcxButton;
    FBtnAtualizar: TcxButton;
    FChkSomentePendentes: TCheckBox;
    FGrade: TcxGrid;
    FNivel: TcxGridLevel;
    FView: TcxGridDBTableView;
    FColId: TcxGridDBColumn;
    FColVenda: TcxGridDBColumn;
    FColTipo: TcxGridDBColumn;
    FColCriado: TcxGridDBColumn;
    FColSituacao: TcxGridDBColumn;
    FColUltimoErro: TcxGridDBColumn;
    FPnlVazio: TPanel;
    FPnlErro: TPanel;
    FLblErro: TLabel;
    FBtnTentar: TcxButton;
    FOcupado: Boolean;
    FLblEspera: TLabel;
    procedure DefinirOcupado(AValor: Boolean);
    procedure MontarBarra;
    procedure MontarGrade;
    procedure MontarVazio;
    procedure MontarErro;
    function AdicionarColuna(const ACampo, ATitulo: string;
      ALargura: Integer): TcxGridDBColumn;
    procedure Recarregar;
    procedure MostrarErro(const ATexto: string);
    procedure AtualizarEstado;
    function ValorLinha(AColuna: TcxGridDBColumn): Variant;
    function TemSelecao: Boolean;
    procedure AoReenviar(Sender: TObject);
    procedure AoAtualizar(Sender: TObject);
    procedure AoMudarFiltro(Sender: TObject);
    procedure AoTentarNovamente(Sender: TObject);
    procedure AoMudarFoco(Sender: TcxCustomGridTableView;
      APrevFocusedRecord, AFocusedRecord: TcxCustomGridRecord;
      ANewItemRecordFocusingChanged: Boolean);
    procedure AoTextoTipo(Sender: TcxCustomGridTableItem;
      ARecord: TcxCustomGridRecord; var AText: string);
    procedure AoTextoUltimoErro(Sender: TcxCustomGridTableItem;
      ARecord: TcxCustomGridRecord; var AText: string);
    procedure AoTextoSituacao(Sender: TcxCustomGridTableItem;
      ARecord: TcxCustomGridRecord; var AText: string);
    procedure AoTextoCriado(Sender: TcxCustomGridTableItem;
      ARecord: TcxCustomGridRecord; var AText: string);
    procedure LiberarDados;
  protected
    procedure AoFechar; override;
  public
    constructor Create(AOwner: TComponent; const AFila: IFilaRepository;
      AService: TFilaService); reintroduce;
    destructor Destroy; override;
    /// <summary>Disparado em Fechar/Esc quando embutida no shell; o dono libera.</summary>
    property OnFechada: TNotifyEvent read FOnFechada write FOnFechada;
    /// <summary>T53: disparado apos cada Reenviar (a fila mudou) para o shell
    /// atualizar o contador "Pendencias: N".</summary>
    property OnFilaAlterada: TNotifyEvent read FOnFilaAlterada write FOnFilaAlterada;
  end;

implementation

uses
  ERPV.Core.Erros, ERPV.Dominio.Enums, ERPV.UI.PendenciasApresentacao;

const
  MSG_ERRO_LISTA = 'Não foi possível carregar as pendências.';
  MSG_REENVIANDO = 'Reenviando...';
  MSG_ERRO_GENERICO = 'Ocorreu um erro inesperado. Tente novamente.';
  MSG_ERRO_REENVIO = 'Ainda não foi possível reenviar este item. Tente novamente.';

constructor TFormPendencias.Create(AOwner: TComponent; const AFila: IFilaRepository;
  AService: TFilaService);
begin
  inherited Create(AOwner);
  FFila := AFila;
  FService := AService;
  Titulo := 'Pendências de Integração';
  BtnNovo.Visible := False;
  BtnEditar.Visible := False;
  BtnExcluir.Visible := False;
  HabilitarAcoes(False, False); // Enter da base nao aciona nada aqui
  MontarBarra;
  MontarGrade;
  MontarVazio;
  MontarErro;
  Recarregar;
end;

destructor TFormPendencias.Destroy;
begin
  if FView <> nil then
    FView.DataController.DataSource := nil;
  LiberarDados;
  inherited Destroy;
end;

procedure TFormPendencias.LiberarDados;
begin
  FreeAndNil(FDataSet);
end;

procedure TFormPendencias.MontarBarra;
var
  Pai: TWinControl;
  Topo: Integer;
begin
  Pai := BtnFechar.Parent; // barra de acoes da base
  Topo := (Pai.ClientHeight - ERPVAlturaControle) div 2;

  FBtnReenviar := TcxButton.Create(Self);
  FBtnReenviar.Parent := Pai;
  FBtnReenviar.Caption := 'Reenviar selecionado';
  FBtnReenviar.SetBounds(ERPVMargemPagina, Topo, 160, ERPVAlturaControle);
  FBtnReenviar.OnClick := AoReenviar;
  EstilizarBotao(FBtnReenviar, upbPrimario);

  FBtnAtualizar := TcxButton.Create(Self);
  FBtnAtualizar.Parent := Pai;
  FBtnAtualizar.Caption := 'Atualizar';
  FBtnAtualizar.SetBounds(FBtnReenviar.Left + FBtnReenviar.Width + ERPVEspaco8,
    Topo, 88, ERPVAlturaControle);
  FBtnAtualizar.OnClick := AoAtualizar;
  EstilizarBotao(FBtnAtualizar, upbSecundario);

  FChkSomentePendentes := TCheckBox.Create(Self);
  FChkSomentePendentes.Parent := Pai;
  FChkSomentePendentes.Caption := 'Somente pendentes';
  FChkSomentePendentes.SetBounds(FBtnAtualizar.Left + FBtnAtualizar.Width + ERPVEspaco16,
    Topo + 4, 160, 20);
  FChkSomentePendentes.Checked := True;
  FChkSomentePendentes.OnClick := AoMudarFiltro;

  // Ordem de tabulacao: Reenviar, Atualizar, Somente pendentes, Fechar.
  FLblEspera := TLabel.Create(Self);
  FLblEspera.Parent := Pai;
  FLblEspera.AutoSize := True;
  FLblEspera.Transparent := True;
  FLblEspera.Font.Name := ERPVFontePrincipal;
  FLblEspera.Font.Color := clERPVTextoSecundario;
  FLblEspera.Caption := MSG_REENVIANDO;
  FLblEspera.Left := FChkSomentePendentes.Left + FChkSomentePendentes.Width +
    ERPVEspaco16;
  FLblEspera.Top := Topo + 6;
  FLblEspera.Visible := False; // so durante o reenvio sincrono

  FBtnReenviar.TabOrder := 0;
  FBtnAtualizar.TabOrder := 1;
  FChkSomentePendentes.TabOrder := 2;
  BtnFechar.TabOrder := 3;
  FBtnReenviar.Enabled := False;
end;

function TFormPendencias.AdicionarColuna(const ACampo, ATitulo: string;
  ALargura: Integer): TcxGridDBColumn;
begin
  Result := FView.CreateColumn;
  Result.DataBinding.FieldName := ACampo;
  Result.Caption := ATitulo;
  Result.Width := ALargura;
  Result.Options.Editing := False; // somente leitura
end;

procedure TFormPendencias.MontarGrade;
begin
  FDataSource := TDataSource.Create(Self);

  FGrade := TcxGrid.Create(Self);
  FGrade.Parent := PnlConteudo;
  FGrade.Align := alClient;
  FGrade.BorderStyle := cxcbsNone;
  FGrade.TabOrder := 0;

  FView := FGrade.CreateView(TcxGridDBTableView) as TcxGridDBTableView;
  FNivel := FGrade.Levels.Add;
  FNivel.GridView := FView;

  FColId := AdicionarColuna('ID', 'Código', 60);
  FColId.Visible := False;
  FColVenda := AdicionarColuna('VENDA_ID', 'Venda', 70);
  FColTipo := AdicionarColuna('TIPO', 'Tipo', 110);
  FColTipo.PropertiesClass := TcxTextEditProperties;
  FColTipo.OnGetDisplayText := AoTextoTipo;
  FColCriado := AdicionarColuna('CRIADO_EM', 'Criado em', 120);
  FColCriado.PropertiesClass := TcxTextEditProperties;
  FColCriado.OnGetDisplayText := AoTextoCriado;
  AdicionarColuna('TENTATIVAS', 'Tent.', 60);
  FColSituacao := AdicionarColuna('STATUS', 'Situação', 90);
  FColSituacao.PropertiesClass := TcxTextEditProperties;
  FColSituacao.OnGetDisplayText := AoTextoSituacao;
  FColUltimoErro := AdicionarColuna('ULTIMO_ERRO', 'Último erro', 320);
  FColUltimoErro.PropertiesClass := TcxTextEditProperties;
  FColUltimoErro.OnGetDisplayText := AoTextoUltimoErro;

  FView.DataController.KeyFieldNames := 'ID';
  FView.DataController.DataSource := FDataSource;
  FView.OptionsData.Editing := False;
  FView.OptionsData.Deleting := False;
  FView.OptionsData.Inserting := False;
  ConfigurarGrade(FView);
  FView.OnFocusedRecordChanged := AoMudarFoco;
end;

procedure TFormPendencias.MontarVazio;
begin
  FPnlVazio := TPanel.Create(Self);
  FPnlVazio.Parent := PnlConteudo;
  FPnlVazio.Align := alBottom;
  FPnlVazio.BevelOuter := bvNone;
  FPnlVazio.ParentBackground := False;
  FPnlVazio.Color := clERPVSuperficie;
  FPnlVazio.Height := 40;
  FPnlVazio.Caption := MSG_PENDENCIAS_VAZIO; // texto sempre presente (UX 5)
  FPnlVazio.Font.Color := clERPVSucessoTexto;
  FPnlVazio.Visible := False;
end;

procedure TFormPendencias.MontarErro;
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

procedure TFormPendencias.MostrarErro(const ATexto: string);
begin
  FLblErro.Caption := ATexto;
  FPnlErro.Visible := True;
end;

procedure TFormPendencias.Recarregar;
var
  Novo, Antigo: TDataSet;
begin
  FPnlErro.Visible := False;
  try
    Novo := FFila.Listar(FChkSomentePendentes.Checked);
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

procedure TFormPendencias.AtualizarEstado;
var
  Vazio: Boolean;
begin
  Vazio := (FDataSet = nil) or FDataSet.IsEmpty;
  FPnlVazio.Visible := Vazio and not FPnlErro.Visible;
  Subtitulo := SubtituloPendencias(FView.DataController.RecordCount,
    FChkSomentePendentes.Checked);
  FBtnReenviar.Enabled := (not FOcupado) and TemSelecao and
    PodeReenviarItem(VarToStr(ValorLinha(FColSituacao)));
end;

function TFormPendencias.ValorLinha(AColuna: TcxGridDBColumn): Variant;
var
  Idx: Integer;
begin
  Result := Null;
  Idx := FView.DataController.FocusedRecordIndex;
  if Idx >= 0 then
    Result := FView.DataController.Values[Idx, AColuna.Index];
end;

function TFormPendencias.TemSelecao: Boolean;
begin
  Result := (FView.DataController.FocusedRecordIndex >= 0) and
    (not VarIsNull(ValorLinha(FColId)));
end;

procedure TFormPendencias.DefinirOcupado(AValor: Boolean);
begin
  FOcupado := AValor;
  FBtnReenviar.Enabled := (not AValor) and TemSelecao and
    PodeReenviarItem(VarToStr(ValorLinha(FColSituacao)));
  FBtnAtualizar.Enabled := not AValor;
  FChkSomentePendentes.Enabled := not AValor;
  BtnFechar.Enabled := not AValor;
  FGrade.Enabled := not AValor; // bloqueia duplo clique/Enter/teclas na grade
  FBtnTentar.Enabled := not AValor;
  FLblEspera.Visible := AValor;
  if AValor then
    FLblEspera.Update; // repinta antes da chamada sincrona
end;

procedure TFormPendencias.AoReenviar(Sender: TObject);
var
  FilaId, VendaId: Integer;
  Tipo: TTipoFila;
  Resultado: TResultadoReenvio;
  Msg: TMensagemReenvio;
begin
  if FOcupado or not TemSelecao or
    not PodeReenviarItem(VarToStr(ValorLinha(FColSituacao))) then
    Exit;
  FilaId := ValorLinha(FColId);
  VendaId := ValorLinha(FColVenda);
  try
    Tipo := StrToTipoFila(VarToStr(ValorLinha(FColTipo)));
  except
    Notificar(utnErro, MSG_ERRO_REENVIO);
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  DefinirOcupado(True);
  try
    try
      Resultado := FService.Reenviar(FilaId, VendaId, Tipo);
      Msg := MensagemDeReenvio(Resultado);
    except
      on E: Exception do
      begin
        Msg.Sucesso := False;
        if E is EErpVendas then
          Msg.Texto := 'Ainda não foi possível: ' + E.Message
        else
          Msg.Texto := MSG_ERRO_REENVIO;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
    DefinirOcupado(False);
  end;

  // Recarrega antes da mensagem modal: item concluido some do filtro.
  Recarregar;
  if Assigned(FOnFilaAlterada) then
    FOnFilaAlterada(Self);
  if Msg.Sucesso and not Msg.Aviso then
    Notificar(utnInfo, Msg.Texto, PnlConteudo)
  else
    Notificar(utnAviso, Msg.Texto);
end;

procedure TFormPendencias.AoAtualizar(Sender: TObject);
begin
  Recarregar;
end;

procedure TFormPendencias.AoMudarFiltro(Sender: TObject);
begin
  Recarregar;
end;

procedure TFormPendencias.AoTentarNovamente(Sender: TObject);
begin
  Recarregar;
end;

procedure TFormPendencias.AoMudarFoco(Sender: TcxCustomGridTableView;
  APrevFocusedRecord, AFocusedRecord: TcxCustomGridRecord;
  ANewItemRecordFocusingChanged: Boolean);
begin
  FBtnReenviar.Enabled := (not FOcupado) and TemSelecao and
    PodeReenviarItem(VarToStr(ValorLinha(FColSituacao)));
end;

procedure TFormPendencias.AoTextoTipo(Sender: TcxCustomGridTableItem;
  ARecord: TcxCustomGridRecord; var AText: string);
begin
  if ARecord <> nil then
    AText := TextoTipoFila(VarToStr(ARecord.Values[FColTipo.Index]));
end;

procedure TFormPendencias.AoTextoUltimoErro(Sender: TcxCustomGridTableItem;
  ARecord: TcxCustomGridRecord; var AText: string);
begin
  // RF14-03: 401 de configuracao da chave aparece distinto de recusa de negocio.
  if ARecord <> nil then
    AText := TextoUltimoErro(VarToStr(ARecord.Values[FColUltimoErro.Index]));
end;

procedure TFormPendencias.AoTextoSituacao(Sender: TcxCustomGridTableItem;
  ARecord: TcxCustomGridRecord; var AText: string);
begin
  if ARecord <> nil then
    AText := TextoSituacaoFila(VarToStr(ARecord.Values[FColSituacao.Index]));
end;

procedure TFormPendencias.AoTextoCriado(Sender: TcxCustomGridTableItem;
  ARecord: TcxCustomGridRecord; var AText: string);
var
  V: Variant;
begin
  if ARecord = nil then
    Exit;
  V := ARecord.Values[FColCriado.Index];
  if (not VarIsNull(V)) and (not VarIsEmpty(V)) then
    AText := FormatDateTime('dd/mm hh:nn', VarToDateTime(V));
end;

procedure TFormPendencias.AoFechar;
begin
  if Assigned(FOnFechada) then
    FOnFechada(Self)
  else
    inherited AoFechar;
end;

end.
