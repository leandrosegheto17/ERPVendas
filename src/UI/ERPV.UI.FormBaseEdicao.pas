unit ERPV.UI.FormBaseEdicao;

{
  T15 (Lote 3) - TFormBaseEdicao (UX-SPEC 2.3, 3.3, 5, 2.6; ADR-011).
  Modal, 100% em codigo (sem .dfm; construtor chama CreateNew).

  Estrutura: PnlCampos (alClient, o filho coloca os campos: coluna unica,
  rotulo acima, erro abaixo - UX 2.3) | PnlRodape (altura 48, rodape de
  botoes de UX 3.3): Excluir/perigoso opcional a ESQUERDA (oculto por
  padrao, ExibirExcluir), Cancelar (secundario) e Salvar (primario, o mais
  a DIREITA).

  Teclado: Enter aciona Salvar (OK), exceto em editor multilinha ou quando
  o foco esta num botao; Esc aciona Cancelar. KeyPreview = True.
  Salvar: chama Validar (virtual, False = nao fecha; o filho exibe o erro
  inline, UX 5), depois Gravar (virtual) e ModalResult := mrOk.
  Cancelar: se Modificado pede confirmacao via Notificar(utnPergunta)
  (UX 2.6), senao fecha com mrCancel.
  Modificado: o filho marca via MarcarModificado (ex.: OnChange dos editores).
  Icones (T69) nao plugados aqui; botoes mantem texto.
}

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.UITypes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  cxButtons, ERPV.UI.Tokens, ERPV.UI.Tema;

type
  TFormBaseEdicao = class(TForm)
  private
    FPnlCampos: TPanel;
    FPnlRodape: TPanel;
    FBtnSalvar: TcxButton;
    FBtnCancelar: TcxButton;
    FBtnExcluir: TcxButton;
    FModificado: Boolean;
    function CriarBotao(const ACaption: string; APapel: TUIPapelBotao;
      AClick: TNotifyEvent): TcxButton;
    procedure ClickSalvar(Sender: TObject);
    procedure ClickCancelar(Sender: TObject);
    procedure ClickExcluir(Sender: TObject);
    procedure LayoutRodape(Sender: TObject);
    function GetExibirExcluir: Boolean;
    procedure SetExibirExcluir(AValor: Boolean);
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    /// <summary>False = nao fecha (filho ja exibiu o erro inline).</summary>
    function Validar: Boolean; virtual;
    procedure Gravar; virtual;
    procedure AoExcluir; virtual;
    procedure Confirmar; // Validar + Gravar + mrOk (Enter/Salvar)
    procedure Descartar; // Cancelar com confirmacao se Modificado (Esc)
  public
    constructor Create(AOwner: TComponent); override;
    procedure MarcarModificado;
    property Modificado: Boolean read FModificado;
    property ExibirExcluir: Boolean read GetExibirExcluir write SetExibirExcluir;
    property PnlCampos: TPanel read FPnlCampos;
    property BtnSalvar: TcxButton read FBtnSalvar;
    property BtnCancelar: TcxButton read FBtnCancelar;
    property BtnExcluir: TcxButton read FBtnExcluir;
  end;

implementation

constructor TFormBaseEdicao.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Scaled := True;
  KeyPreview := True;
  BorderStyle := bsDialog;
  Position := poOwnerFormCenter;
  Color := clERPVSuperficie;
  Font.Name := ERPVFontePrincipal;
  Font.Size := ERPVTamCorpo;
  Font.Color := clERPVTextoPrincipal;
  ClientWidth := 520; // dialogo: largura fixa 480-560 (UX 3.3)
  ClientHeight := 360;

  FPnlRodape := TPanel.Create(Self);
  FPnlRodape.Parent := Self;
  FPnlRodape.Align := alBottom;
  FPnlRodape.BevelOuter := bvNone;
  FPnlRodape.ParentBackground := False;
  FPnlRodape.Color := clERPVFundoApp;
  FPnlRodape.Height := ERPVAlturaFaixaMarca;
  FPnlRodape.OnResize := LayoutRodape;

  FPnlCampos := TPanel.Create(Self);
  FPnlCampos.Parent := Self;
  FPnlCampos.Align := alClient;
  FPnlCampos.BevelOuter := bvNone;
  FPnlCampos.ParentBackground := False;
  FPnlCampos.Color := clERPVSuperficie;
  FPnlCampos.Padding.SetBounds(ERPVMargemPagina, ERPVMargemPagina,
    ERPVMargemPagina, ERPVMargemPagina);

  FBtnSalvar := CriarBotao('Salvar', upbPrimario, ClickSalvar);
  FBtnCancelar := CriarBotao('Cancelar', upbSecundario, ClickCancelar);
  FBtnExcluir := CriarBotao('Excluir', upbPerigoso, ClickExcluir);
  FBtnExcluir.Visible := False;
  // TabOrder: campos primeiro, depois rodape (Salvar, Cancelar, Excluir).
  FPnlCampos.TabOrder := 0;
  FPnlRodape.TabOrder := 1;
  FBtnSalvar.TabOrder := 0;
  FBtnCancelar.TabOrder := 1;
  FBtnExcluir.TabOrder := 2;
  LayoutRodape(nil);
end;

function TFormBaseEdicao.CriarBotao(const ACaption: string;
  APapel: TUIPapelBotao; AClick: TNotifyEvent): TcxButton;
begin
  Result := TcxButton.Create(Self);
  Result.Parent := FPnlRodape;
  Result.Caption := ACaption;
  Result.Width := 96;
  Result.OnClick := AClick;
  EstilizarBotao(Result, APapel);
end;

// UX 3.3: primario o mais a direita; secundario ao seu lado; perigoso
// separado, a esquerda.
procedure TFormBaseEdicao.LayoutRodape(Sender: TObject);
var
  Topo: Integer;
begin
  if FBtnExcluir = nil then
    Exit;
  Topo := (FPnlRodape.ClientHeight - ERPVAlturaControle) div 2;
  FBtnSalvar.SetBounds(FPnlRodape.ClientWidth - ERPVMargemPagina - FBtnSalvar.Width,
    Topo, FBtnSalvar.Width, ERPVAlturaControle);
  FBtnCancelar.SetBounds(FBtnSalvar.Left - ERPVEspaco8 - FBtnCancelar.Width,
    Topo, FBtnCancelar.Width, ERPVAlturaControle);
  FBtnExcluir.SetBounds(ERPVMargemPagina, Topo, FBtnExcluir.Width,
    ERPVAlturaControle);
end;

function TFormBaseEdicao.GetExibirExcluir: Boolean;
begin
  Result := FBtnExcluir.Visible;
end;

procedure TFormBaseEdicao.SetExibirExcluir(AValor: Boolean);
begin
  FBtnExcluir.Visible := AValor;
end;

procedure TFormBaseEdicao.MarcarModificado;
begin
  FModificado := True;
end;

function TFormBaseEdicao.Validar: Boolean;
begin
  Result := True;
end;

procedure TFormBaseEdicao.Gravar;
begin
  // filho sobrescreve
end;

procedure TFormBaseEdicao.AoExcluir;
begin
  // filho sobrescreve (confirmar via Notificar(utnPergunta, ...))
end;

procedure TFormBaseEdicao.Confirmar;
begin
  if not Validar then
    Exit;
  Gravar;
  ModalResult := mrOk;
end;

procedure TFormBaseEdicao.Descartar;
begin
  if FModificado and not Notificar(utnPergunta,
    'Descartar as alterações feitas?') then
    Exit;
  ModalResult := mrCancel;
end;

procedure TFormBaseEdicao.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Shift <> [] then
    Exit;
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    Descartar;
  end
  else if (Key = VK_RETURN) and not (ActiveControl is TCustomMemo)
    and not (ActiveControl is TcxButton) then
  begin
    Key := 0;
    Confirmar;
  end;
end;

procedure TFormBaseEdicao.ClickSalvar(Sender: TObject);
begin
  Confirmar;
end;

procedure TFormBaseEdicao.ClickCancelar(Sender: TObject);
begin
  Descartar;
end;

procedure TFormBaseEdicao.ClickExcluir(Sender: TObject);
begin
  AoExcluir;
end;

end.
