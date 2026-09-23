unit ERPV.UI.FormBaseLista;

{
  T15 (Lote 3) - TFormBaseLista (UX-SPEC 2.2, 3.3, 4.1; ADR-011).
  Construido 100% em codigo (sem .dfm), mesmo padrao de FormTesteTema:
  o construtor chama CreateNew, entao o form filho pode ser criado por
  Application.CreateForm/Create sem depender de stream de componentes.

  Estrutura (topo -> base): PnlCabecalho (titulo + subtitulo/contagem, sem
  barra de titulo customizada) | PnlAcoes (altura 40: Novo, Editar, Excluir,
  espaco, Fechar) | PnlConteudo (alClient - o filho coloca a grade aqui).

  Papeis (EstilizarBotao): Novo = Primario (primeiro a esquerda, UX 3.3);
  Editar/Fechar = Secundario; Excluir = Perigoso (direita da barra, separado;
  a CONFIRMACAO e do filho via Notificar(utnPergunta) dentro de AoExcluir).
  Botoes indisponiveis ficam desabilitados, nao escondidos (HabilitarAcoes).

  Teclado: Esc fecha (AoFechar). Enter aciona Editar (acao padrao de lista),
  exceto quando o foco esta em editor multilinha ou num botao. KeyPreview.
  Ganchos virtuais para o filho: AoNovo, AoEditar, AoExcluir, AoFechar.
  Icones (T69) NAO sao plugados aqui (arquivos de outra tarefa); botoes
  mantem texto, entao nada quebra quando os icones chegarem.
}

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.UITypes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  cxButtons, ERPV.UI.Tokens, ERPV.UI.Tema;

type
  TFormBaseLista = class(TForm)
  private
    FPnlCabecalho: TPanel;
    FLblTitulo: TLabel;
    FLblSubtitulo: TLabel;
    FPnlAcoes: TPanel;
    FPnlConteudo: TPanel;
    FBtnNovo: TcxButton;
    FBtnEditar: TcxButton;
    FBtnExcluir: TcxButton;
    FBtnFechar: TcxButton;
    function CriarBotao(const ACaption: string; APapel: TUIPapelBotao;
      AClick: TNotifyEvent): TcxButton;
    procedure ClickNovo(Sender: TObject);
    procedure ClickEditar(Sender: TObject);
    procedure ClickExcluir(Sender: TObject);
    procedure ClickFechar(Sender: TObject);
    procedure LayoutAcoes(Sender: TObject);
    function GetTitulo: string;
    procedure SetTitulo(const AValor: string);
    function GetSubtitulo: string;
    procedure SetSubtitulo(const AValor: string);
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure AoNovo; virtual;
    procedure AoEditar; virtual;
    procedure AoExcluir; virtual;
    procedure AoFechar; virtual;
    /// <summary>Habilita/desabilita (nunca esconde) Editar e Excluir.</summary>
    procedure HabilitarAcoes(AEditar, AExcluir: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    property Titulo: string read GetTitulo write SetTitulo;
    property Subtitulo: string read GetSubtitulo write SetSubtitulo;
    property PnlConteudo: TPanel read FPnlConteudo;
    property BtnNovo: TcxButton read FBtnNovo;
    property BtnEditar: TcxButton read FBtnEditar;
    property BtnExcluir: TcxButton read FBtnExcluir;
    property BtnFechar: TcxButton read FBtnFechar;
  end;

implementation

constructor TFormBaseLista.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Scaled := True;
  KeyPreview := True;
  Color := clERPVFundoApp;
  Font.Name := ERPVFontePrincipal;
  Font.Size := ERPVTamCorpo;
  Font.Color := clERPVTextoPrincipal;
  ClientWidth := 800;
  ClientHeight := 520;

  // Ordem de criacao = ordem de alinhamento (alTop empilha na ordem).
  FPnlCabecalho := TPanel.Create(Self);
  FPnlCabecalho.Parent := Self;
  FPnlCabecalho.Align := alTop;
  FPnlCabecalho.BevelOuter := bvNone;
  FPnlCabecalho.ParentBackground := False;
  FPnlCabecalho.Color := clERPVFundoApp;
  FPnlCabecalho.Height := 56;

  FLblTitulo := TLabel.Create(FPnlCabecalho);
  FLblTitulo.Parent := FPnlCabecalho;
  FLblTitulo.SetBounds(ERPVMargemPagina, ERPVEspaco8, 400, 24);
  FLblTitulo.Font.Size := ERPVTamTituloPagina;
  FLblTitulo.Font.Style := [fsBold];
  FLblTitulo.Font.Color := clERPVTextoPrincipal;

  FLblSubtitulo := TLabel.Create(FPnlCabecalho);
  FLblSubtitulo.Parent := FPnlCabecalho;
  FLblSubtitulo.SetBounds(ERPVMargemPagina, 34, 400, 16);
  FLblSubtitulo.Font.Size := ERPVTamSubtitulo;
  FLblSubtitulo.Font.Color := clERPVTextoSecundario;

  FPnlAcoes := TPanel.Create(Self);
  FPnlAcoes.Parent := Self;
  FPnlAcoes.Align := alTop;
  FPnlAcoes.BevelOuter := bvNone;
  FPnlAcoes.ParentBackground := False;
  FPnlAcoes.Color := clERPVFundoApp;
  FPnlAcoes.Height := ERPVAlturaBarraAcoes;
  FPnlAcoes.OnResize := LayoutAcoes;

  FPnlConteudo := TPanel.Create(Self);
  FPnlConteudo.Parent := Self;
  FPnlConteudo.Align := alClient;
  FPnlConteudo.BevelOuter := bvNone;
  FPnlConteudo.ParentBackground := False;
  FPnlConteudo.Color := clERPVSuperficie;
  FPnlConteudo.Padding.SetBounds(ERPVMargemPagina, 0, ERPVMargemPagina, ERPVMargemPagina);

  FBtnNovo := CriarBotao('Novo', upbPrimario, ClickNovo);
  FBtnEditar := CriarBotao('Editar', upbSecundario, ClickEditar);
  FBtnExcluir := CriarBotao('Excluir', upbPerigoso, ClickExcluir);
  FBtnFechar := CriarBotao('Fechar', upbSecundario, ClickFechar);
  // TabOrder explicito: Novo, Editar, Excluir, Fechar; depois o conteudo.
  FBtnNovo.TabOrder := 0;
  FBtnEditar.TabOrder := 1;
  FBtnExcluir.TabOrder := 2;
  FBtnFechar.TabOrder := 3;
  FPnlAcoes.TabOrder := 0;
  FPnlConteudo.TabOrder := 1;
  LayoutAcoes(nil);
end;

function TFormBaseLista.CriarBotao(const ACaption: string;
  APapel: TUIPapelBotao; AClick: TNotifyEvent): TcxButton;
begin
  Result := TcxButton.Create(Self);
  Result.Parent := FPnlAcoes;
  Result.Caption := ACaption;
  Result.Width := 88;
  Result.OnClick := AClick;
  EstilizarBotao(Result, APapel);
end;

// UX 3.3: Novo primeiro a esquerda; Fechar a direita; Excluir (perigoso)
// separado espacialmente, a direita antes de Fechar, com espaco entre grupos.
procedure TFormBaseLista.LayoutAcoes(Sender: TObject);
var
  Topo: Integer;
begin
  if FBtnFechar = nil then
    Exit;
  Topo := (FPnlAcoes.ClientHeight - ERPVAlturaControle) div 2;
  FBtnNovo.SetBounds(ERPVMargemPagina, Topo, FBtnNovo.Width, ERPVAlturaControle);
  FBtnEditar.SetBounds(FBtnNovo.Left + FBtnNovo.Width + ERPVEspaco8, Topo,
    FBtnEditar.Width, ERPVAlturaControle);
  FBtnFechar.SetBounds(FPnlAcoes.ClientWidth - ERPVMargemPagina - FBtnFechar.Width,
    Topo, FBtnFechar.Width, ERPVAlturaControle);
  FBtnExcluir.SetBounds(FBtnFechar.Left - ERPVEspaco24 - FBtnExcluir.Width,
    Topo, FBtnExcluir.Width, ERPVAlturaControle);
end;

function TFormBaseLista.GetTitulo: string;
begin
  Result := FLblTitulo.Caption;
end;

procedure TFormBaseLista.SetTitulo(const AValor: string);
begin
  FLblTitulo.Caption := AValor;
  Caption := AValor;
end;

function TFormBaseLista.GetSubtitulo: string;
begin
  Result := FLblSubtitulo.Caption;
end;

procedure TFormBaseLista.SetSubtitulo(const AValor: string);
begin
  FLblSubtitulo.Caption := AValor;
end;

procedure TFormBaseLista.HabilitarAcoes(AEditar, AExcluir: Boolean);
begin
  FBtnEditar.Enabled := AEditar;
  FBtnExcluir.Enabled := AExcluir;
end;

procedure TFormBaseLista.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Shift <> [] then
    Exit;
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    AoFechar;
  end
  else if (Key = VK_RETURN) and FBtnEditar.Enabled
    and not (ActiveControl is TCustomMemo)
    and not (ActiveControl is TcxButton) then
  begin
    // Enter num botao aciona o proprio botao (comportamento nativo).
    Key := 0;
    AoEditar;
  end;
end;

procedure TFormBaseLista.ClickNovo(Sender: TObject);
begin
  AoNovo;
end;

procedure TFormBaseLista.ClickEditar(Sender: TObject);
begin
  AoEditar;
end;

procedure TFormBaseLista.ClickExcluir(Sender: TObject);
begin
  AoExcluir;
end;

procedure TFormBaseLista.ClickFechar(Sender: TObject);
begin
  AoFechar;
end;

procedure TFormBaseLista.AoNovo;
begin
  // filho sobrescreve
end;

procedure TFormBaseLista.AoEditar;
begin
  // filho sobrescreve
end;

procedure TFormBaseLista.AoExcluir;
begin
  // filho sobrescreve (deve confirmar via Notificar(utnPergunta, ...))
end;

procedure TFormBaseLista.AoFechar;
begin
  Close;
end;

end.
