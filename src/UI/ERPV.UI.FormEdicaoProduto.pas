unit ERPV.UI.FormEdicaoProduto;

(*
  T24 (Lote 5) - Edição de Produto (UX-SPEC 2.3, 5; ADR-011).
  Herda TFormBaseEdicao (T15). 100% em código (sem .dfm). Modelo: T20.

  CONTRATO (usado pela T23):
    TFormEdicaoProduto.Create(AOwner, AService, AProduto)
    AProduto = nil -> novo produto. ShowModal = mrOk se gravou, senão mrCancel.
    A tela trabalha numa COPIA da entidade; ao gravar com sucesso copia o
    resultado (Id, campos normalizados) de volta para AProduto (se informado).
    AProduto continua sendo do chamador (a tela nunca o libera).

  Decisões:
  - Regra de negócio só no serviço. A validação visual repete só as mesmas
    verificações simples e mensagens do TProdutoService.
  - TFormBaseEdicao.Confirmar faz Validar -> Gravar -> mrOk; por isso a chamada
    a Salvar acontece DENTRO de Validar; EValidacao vira erro no campo
    (E.Campo) e Validar devolve False; Gravar fica vazio.
  - Preço: TcxCurrencyEdit com DisplayFormat pt-BR (separadores do Windows) e
    2 casas; lido como Currency (VarAsType varCurrency, arredondado a 2 casas),
    nunca Double na entidade.
  - Borda: painel-moldura (1 px normal/erro, 2 px em foco), cores só de Tokens.
*)

interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  cxEdit, cxTextEdit, cxCurrencyEdit,
  ERPV.Core.Erros,
  ERPV.Dominio.Produto, ERPV.Negocio.ProdutoService,
  ERPV.UI.Tokens, ERPV.UI.Tema, ERPV.UI.FormBaseEdicao;

type
  TCampoProduto = (cpDescricao, cpUnidade, cpPreco, cpCategoria);

  TFormEdicaoProduto = class(TFormBaseEdicao)
  private
    FService: TProdutoService;
    FDestino: TProduto;   // do chamador (pode ser nil); não liberado aqui
    FProduto: TProduto;   // cópia de trabalho (própria)
    FCarregando: Boolean;
    FProximoTop: Integer;
    FEdtDescricao: TcxTextEdit;
    FEdtUnidade: TcxTextEdit;
    FEdtPreco: TcxCurrencyEdit;
    FEdtCategoria: TcxTextEdit;
    FChkAtivo: TCheckBox;
    FEdit: array[TCampoProduto] of TWinControl;
    FMoldura: array[TCampoProduto] of TPanel;
    FErro: array[TCampoProduto] of TLabel;

    function NovoBloco(AAltura: Integer): TPanel;
    procedure NovoRotulo(ABloco: TPanel; const ACaption: string);
    procedure NovaMoldura(ABloco: TPanel; ACampo: TCampoProduto);
    procedure NovoErro(ABloco: TPanel; ACampo: TCampoProduto);
    function NovoTexto(ABloco: TPanel; ACampo: TCampoProduto;
      const ARotulo: string): TcxTextEdit;
    procedure MontarCampos;

    procedure EditEnter(Sender: TObject);
    procedure EditExit(Sender: TObject);
    procedure EditChange(Sender: TObject);
    procedure AtivoClick(Sender: TObject);

    function CampoDe(ASender: TObject; out ACampo: TCampoProduto): Boolean;
    function CampoPorNome(const ANome: string; out ACampo: TCampoProduto): Boolean;
    procedure AtualizarMoldura(ACampo: TCampoProduto);
    procedure MostrarErro(ACampo: TCampoProduto; const AMensagem: string);
    procedure LimparErro(ACampo: TCampoProduto);
    function TemErro(ACampo: TCampoProduto): Boolean;
    function LerPreco(out APreco: Currency): Boolean;
    function MensagemCampo(ACampo: TCampoProduto): string;
    function ValidarCampo(ACampo: TCampoProduto): Boolean;
    procedure Carregar;
    procedure LerParaEntidade;
  protected
    function Validar: Boolean; override;
    procedure Gravar; override;
  public
    constructor Create(AOwner: TComponent; AService: TProdutoService;
      AProduto: TProduto); reintroduce;
    destructor Destroy; override;
  end;

implementation

const
  cAlturaControle = 28;
  cAlturaRotulo = 18;
  cAlturaMoldura = 32;
  cAlturaErro = 18;
  // Formato de exibição; separadores seguem a configuração regional (pt-BR).
  cFormatoPreco = ',0.00;-,0.00';

{ TFormEdicaoProduto }

constructor TFormEdicaoProduto.Create(AOwner: TComponent;
  AService: TProdutoService; AProduto: TProduto);
begin
  inherited Create(AOwner);
  if AService = nil then
    raise EArgumentException.Create('TFormEdicaoProduto: serviço não informado.');
  FService := AService;
  FDestino := AProduto;
  FProduto := TProduto.Create;
  if AProduto <> nil then
  begin
    FProduto.Id := AProduto.Id;
    FProduto.Descricao := AProduto.Descricao;
    FProduto.Unidade := AProduto.Unidade;
    FProduto.PrecoUnitario := AProduto.PrecoUnitario;
    FProduto.Categoria := AProduto.Categoria;
    FProduto.Ativo := AProduto.Ativo;
  end;

  Caption := 'Produto';
  MontarCampos;
  Carregar;
end;

destructor TFormEdicaoProduto.Destroy;
begin
  FProduto.Free;
  inherited Destroy;
end;

{ ---- construção da tela ---- }

function TFormEdicaoProduto.NovoBloco(AAltura: Integer): TPanel;
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

procedure TFormEdicaoProduto.NovoRotulo(ABloco: TPanel; const ACaption: string);
var
  L: TLabel;
begin
  L := TLabel.Create(Self);
  L.Parent := ABloco;
  L.AutoSize := False;
  L.Align := alTop;
  L.Height := EscalarPx(cAlturaRotulo);
  L.Layout := tlCenter;
  L.Caption := ACaption;
  L.Font.Name := ERPVFontePrincipal;
  L.Font.Size := ERPVTamRotuloCampo;
  L.Font.Style := [fsBold];
  L.Font.Color := clERPVTextoPrincipal;
  L.Top := 0;
end;

procedure TFormEdicaoProduto.NovaMoldura(ABloco: TPanel; ACampo: TCampoProduto);
var
  P: TPanel;
begin
  P := TPanel.Create(Self);
  P.Parent := ABloco;
  P.BevelOuter := bvNone;
  P.ParentBackground := False;
  P.Align := alTop;
  P.Height := EscalarPx(cAlturaMoldura);
  P.Top := EscalarPx(cAlturaRotulo);
  FMoldura[ACampo] := P;
end;

procedure TFormEdicaoProduto.NovoErro(ABloco: TPanel; ACampo: TCampoProduto);
var
  L: TLabel;
begin
  L := TLabel.Create(Self);
  L.Parent := ABloco;
  L.AutoSize := False;
  L.Align := alTop;
  L.Height := EscalarPx(cAlturaErro);
  L.Layout := tlCenter;
  L.Caption := '';
  L.Font.Name := ERPVFontePrincipal;
  L.Font.Size := ERPVTamCorpo;
  L.Font.Color := clERPVErroTexto;
  L.Top := EscalarPx(cAlturaRotulo + cAlturaMoldura);
  FErro[ACampo] := L;
end;

function TFormEdicaoProduto.NovoTexto(ABloco: TPanel; ACampo: TCampoProduto;
  const ARotulo: string): TcxTextEdit;
begin
  NovoRotulo(ABloco, ARotulo);
  NovaMoldura(ABloco, ACampo);
  NovoErro(ABloco, ACampo);
  Result := TcxTextEdit.Create(Self);
  Result.Parent := FMoldura[ACampo];
  Result.Align := alClient;
  Result.Style.BorderStyle := ebsNone;
  Result.Properties.OnChange := EditChange;
  Result.OnEnter := EditEnter;
  Result.OnExit := EditExit;
  FEdit[ACampo] := Result;
end;

procedure TFormEdicaoProduto.MontarCampos;
var
  Bloco: TPanel;
  Sub, Legenda: TLabel;
  C: TCampoProduto;
begin
  FProximoTop := 0;
  PnlCampos.AutoSize := False;

  Bloco := NovoBloco(EscalarPx(28));
  Sub := TLabel.Create(Self);
  Sub.Parent := Bloco;
  Sub.Align := alClient;
  Sub.Layout := tlCenter;
  Sub.Font.Name := ERPVFontePrincipal;
  Sub.Font.Size := ERPVTamSubtitulo;
  Sub.Font.Style := [fsBold];
  Sub.Font.Color := clERPVTextoPrincipal;
  if FDestino = nil then
    Sub.Caption := 'Novo produto'
  else
    Sub.Caption := 'Editar produto';

  Bloco := NovoBloco(EscalarPx(cAlturaRotulo + cAlturaMoldura + cAlturaErro));
  FEdtDescricao := NovoTexto(Bloco, cpDescricao, 'Descrição *');

  Bloco := NovoBloco(EscalarPx(cAlturaRotulo + cAlturaMoldura + cAlturaErro));
  FEdtUnidade := NovoTexto(Bloco, cpUnidade, 'Unidade *');

  Bloco := NovoBloco(EscalarPx(cAlturaRotulo + cAlturaMoldura + cAlturaErro));
  NovoRotulo(Bloco, 'Preço unitário (R$) *');
  NovaMoldura(Bloco, cpPreco);
  NovoErro(Bloco, cpPreco);
  FEdtPreco := TcxCurrencyEdit.Create(Self);
  FEdtPreco.Parent := FMoldura[cpPreco];
  FEdtPreco.Align := alClient;
  FEdtPreco.Style.BorderStyle := ebsNone;
  FEdtPreco.Properties.DisplayFormat := cFormatoPreco;
  FEdtPreco.Properties.DecimalPlaces := 2;
  FEdtPreco.Properties.OnChange := EditChange;
  FEdtPreco.OnEnter := EditEnter;
  FEdtPreco.OnExit := EditExit;
  FEdit[cpPreco] := FEdtPreco;

  Bloco := NovoBloco(EscalarPx(cAlturaRotulo + cAlturaMoldura + cAlturaErro));
  FEdtCategoria := NovoTexto(Bloco, cpCategoria, 'Categoria');

  Bloco := NovoBloco(EscalarPx(cAlturaControle));
  FChkAtivo := TCheckBox.Create(Self);
  FChkAtivo.Parent := Bloco;
  FChkAtivo.Caption := 'Ativo';
  FChkAtivo.SetBounds(0, 0, EscalarPx(120), EscalarPx(cAlturaControle));
  FChkAtivo.Checked := True;
  FChkAtivo.OnClick := AtivoClick;
  Legenda := TLabel.Create(Self);
  Legenda.Parent := Bloco;
  Legenda.Align := alRight;
  Legenda.AutoSize := True;
  Legenda.Layout := tlCenter;
  Legenda.Caption := '* obrigatório';
  Legenda.Font.Name := ERPVFontePrincipal;
  Legenda.Font.Size := ERPVTamCorpo;
  Legenda.Font.Color := clERPVTextoSecundario;

  for C := Low(TCampoProduto) to High(TCampoProduto) do
    AtualizarMoldura(C);

  FEdtDescricao.TabOrder := 0;
  FEdtUnidade.TabOrder := 1;
  FEdtPreco.TabOrder := 2;
  FEdtCategoria.TabOrder := 3;
  FChkAtivo.TabOrder := 4;
  ClientHeight := FProximoTop + 2 * ERPVMargemPagina + ERPVAlturaFaixaMarca
    + EscalarPx(8);
end;

{ ---- estado visual ---- }

function TFormEdicaoProduto.CampoDe(ASender: TObject;
  out ACampo: TCampoProduto): Boolean;
var
  C: TCampoProduto;
begin
  Result := False;
  for C := Low(TCampoProduto) to High(TCampoProduto) do
    if FEdit[C] = ASender then
    begin
      ACampo := C;
      Exit(True);
    end;
end;

function TFormEdicaoProduto.CampoPorNome(const ANome: string;
  out ACampo: TCampoProduto): Boolean;
begin
  Result := True;
  if SameText(ANome, 'Descricao') then
    ACampo := cpDescricao
  else if SameText(ANome, 'Unidade') then
    ACampo := cpUnidade
  else if SameText(ANome, 'Preco') then
    ACampo := cpPreco
  else if SameText(ANome, 'Categoria') then
    ACampo := cpCategoria
  else
    Result := False;
end;

function TFormEdicaoProduto.TemErro(ACampo: TCampoProduto): Boolean;
begin
  Result := FErro[ACampo].Caption <> '';
end;

procedure TFormEdicaoProduto.AtualizarMoldura(ACampo: TCampoProduto);
var
  Pad: Integer;
begin
  if FEdit[ACampo].Focused then
  begin
    FMoldura[ACampo].Color := clERPVDestaque;
    Pad := 2;
  end
  else if TemErro(ACampo) then
  begin
    FMoldura[ACampo].Color := clERPVErroTexto;
    Pad := 1;
  end
  else
  begin
    FMoldura[ACampo].Color := clERPVBordaCampo;
    Pad := 1;
  end;
  FMoldura[ACampo].Padding.SetBounds(Pad, Pad, Pad, Pad);
end;

procedure TFormEdicaoProduto.MostrarErro(ACampo: TCampoProduto;
  const AMensagem: string);
begin
  // ícone (U+2716) + texto: nunca só cor (UX 5)
  FErro[ACampo].Caption := Char($2716) + ' ' + AMensagem;
  AtualizarMoldura(ACampo);
end;

procedure TFormEdicaoProduto.LimparErro(ACampo: TCampoProduto);
begin
  FErro[ACampo].Caption := '';
  AtualizarMoldura(ACampo);
end;

procedure TFormEdicaoProduto.EditEnter(Sender: TObject);
var
  C: TCampoProduto;
begin
  if CampoDe(Sender, C) then
    AtualizarMoldura(C);
end;

procedure TFormEdicaoProduto.EditExit(Sender: TObject);
var
  C: TCampoProduto;
begin
  if not CampoDe(Sender, C) then
    Exit;
  ValidarCampo(C);
  // Focused ainda pode ser True aqui: força o estado "sem foco" na moldura
  FMoldura[C].Color := clERPVBordaCampo;
  FMoldura[C].Padding.SetBounds(1, 1, 1, 1);
  if TemErro(C) then
    FMoldura[C].Color := clERPVErroTexto;
end;

procedure TFormEdicaoProduto.EditChange(Sender: TObject);
begin
  if not FCarregando then
    MarcarModificado;
end;

procedure TFormEdicaoProduto.AtivoClick(Sender: TObject);
begin
  if not FCarregando then
    MarcarModificado;
end;

{ ---- validação visual (mesmas mensagens do serviço) ---- }

// Lê o preço como Currency (2 casas). False = campo vazio/ilegível.
function TFormEdicaoProduto.LerPreco(out APreco: Currency): Boolean;
var
  V: Variant;
begin
  APreco := 0;
  V := FEdtPreco.EditValue;
  Result := not (VarIsNull(V) or VarIsEmpty(V));
  if Result then
    APreco := Round(Currency(VarAsType(V, varCurrency)) * 100) / 100;
end;

function TFormEdicaoProduto.MensagemCampo(ACampo: TCampoProduto): string;
var
  Preco: Currency;
begin
  Result := '';
  case ACampo of
    cpDescricao:
      if Trim(FEdtDescricao.Text) = '' then
        Result := 'Informe a descrição';
    cpUnidade:
      if Trim(FEdtUnidade.Text) = '' then
        Result := 'Informe a unidade';
    cpPreco:
      if (not LerPreco(Preco)) or (Preco < 0) then
        Result := 'Preço inválido';
  end;
end;

function TFormEdicaoProduto.ValidarCampo(ACampo: TCampoProduto): Boolean;
var
  Msg: string;
begin
  Msg := MensagemCampo(ACampo);
  Result := Msg = '';
  if Result then
    LimparErro(ACampo)
  else
    MostrarErro(ACampo, Msg);
end;

{ ---- dados ---- }

procedure TFormEdicaoProduto.Carregar;
begin
  FCarregando := True;
  try
    FEdtDescricao.Text := FProduto.Descricao;
    FEdtUnidade.Text := FProduto.Unidade;
    FEdtPreco.EditValue := FProduto.PrecoUnitario;
    FEdtCategoria.Text := FProduto.Categoria;
    FChkAtivo.Checked := FProduto.Ativo;
  finally
    FCarregando := False;
  end;
end;

procedure TFormEdicaoProduto.LerParaEntidade;
var
  Preco: Currency;
begin
  FProduto.Descricao := Trim(FEdtDescricao.Text);
  FProduto.Unidade := Trim(FEdtUnidade.Text);
  if LerPreco(Preco) then
    FProduto.PrecoUnitario := Preco;
  FProduto.Categoria := Trim(FEdtCategoria.Text);
  FProduto.Ativo := FChkAtivo.Checked;
end;

// Validação visual + chamada ao serviço (ver nota no cabeçalho).
function TFormEdicaoProduto.Validar: Boolean;
var
  C, Primeiro: TCampoProduto;
  TemPrimeiro: Boolean;
  Campo: TCampoProduto;
begin
  TemPrimeiro := False;
  Primeiro := cpDescricao;
  for C := Low(TCampoProduto) to High(TCampoProduto) do
    if not ValidarCampo(C) and not TemPrimeiro then
    begin
      TemPrimeiro := True;
      Primeiro := C;
    end;
  if TemPrimeiro then
  begin
    FEdit[Primeiro].SetFocus;
    Exit(False);
  end;

  LerParaEntidade;
  try
    FService.Salvar(FProduto);
  except
    on E: EValidacao do
    begin
      if CampoPorNome(E.Campo, Campo) then
      begin
        MostrarErro(Campo, E.Message);
        FEdit[Campo].SetFocus;
      end
      else
        Notificar(utnErro, E.Message);
      Exit(False);
    end;
  end;

  if FDestino <> nil then
  begin
    FDestino.Id := FProduto.Id;
    FDestino.Descricao := FProduto.Descricao;
    FDestino.Unidade := FProduto.Unidade;
    FDestino.PrecoUnitario := FProduto.PrecoUnitario;
    FDestino.Categoria := FProduto.Categoria;
    FDestino.Ativo := FProduto.Ativo;
  end;
  Result := True;
end;

procedure TFormEdicaoProduto.Gravar;
begin
  // gravação já feita em Validar (ver nota no cabeçalho da unit)
end;

end.
