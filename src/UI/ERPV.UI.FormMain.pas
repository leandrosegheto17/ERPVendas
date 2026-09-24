unit ERPV.UI.FormMain;

{
  T14 (Lote 3) - Shell do form principal (UX-SPEC.md Secao 1 e 2.1).

  Form fino: nenhum SQL, HTTP ou regra de negocio. Toda a interface e
  montada em codigo (sem controles no .dfm) para que cor, fonte e tamanho
  venham SO de ERPV.UI.Tokens (regra critica de UI, TASK.md Secao 1) e para
  nao depender de propriedades DevExpress em .dfm sem compilar.

  Estrutura (UX-SPEC 2.1):
    - Faixa de marca (topo, ERPVAlturaFaixaMarca, cor de destaque, texto branco).
    - Navegacao lateral (ERPVLarguraNavLateral) com grupos Cadastros/Vendas/
      Integracao/Ajuda. Item ativo: barra de destaque de 3 px + negrito.
    - Area de conteudo (fundo clERPVFundoApp, margem ERPVMargemPagina) com
      "Bem-vindo" enquanto nenhuma tela foi aberta. As telas reais (T19, T23,
      T31, T52...) entram depois via AbrirDestino/AreaConteudo.
    - Status bar em 3 areas: "Financeiro: <BaseUrl do INI>" | estado |
      "Pendencias: 0" (valor fixo ate T53).
    - Sobre (modal, montado em codigo).

  FALLBACK PARA MENU DE BARRA (UX-SPEC 2.1, RP-9): a navegacao lateral e
  SHOULD. Para cair no menu de barra basta comentar a diretiva
  ERPV_NAV_LATERAL logo abaixo - mesmas opcoes e mesmos atalhos Alt+letra
  (TMainMenu), sem tocar em mais nada.

  ATALHOS: Alt+letra via '&' nos rotulos (Clientes=C, Produtos=P, Vendas=V,
  Pendencias=E, Sobre=S, Sair=R). Nenhuma letra repetida.

  DEPENDENCIA DE CONFIG: o form NAO le o INI (ADR-001: so o composition
  root conhece TConfiguracao). O .dpr chama Configurar(BaseUrl) logo apos
  criar o form, com Root.Configuracao.Financeiro.BaseUrl.

  Compilacao/execucao real pendente de confirmacao do usuario na IDE (o
  ambiente de automacao nao compila Delphi).
}

{$DEFINE ERPV_NAV_LATERAL}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Menus, cxButtons,
  ERPV.UI.Tokens, ERPV.UI.Tema, ERPV.UI.Icones,
  ERPV.Negocio.ClienteService, ERPV.UI.FormListaClientes,
  ERPV.Negocio.ProdutoService, ERPV.UI.FormListaProdutos;

const
  WM_ERPV_FECHAR_LISTA = WM_USER + 101;

type
  /// <summary>Destinos navegaveis do shell (mesmas opcoes na nav lateral e no menu).</summary>
  TDestinoShell = (dsClientes, dsProdutos, dsVendas, dsPendencias);

  TFormMain = class(TForm)
  private
    FBaseUrlFinanceiro: string;
    FClienteService: TClienteService;
    FListaClientes: TFormListaClientes;
    FProdutoService: TProdutoService;
    FListaProdutos: TFormListaProdutos;
    FPainelMarca: TPanel;
    FRotuloMarca: TLabel;
    FPainelNav: TPanel;
    FAreaConteudo: TPanel;
    FRotuloBemVindo: TLabel;
    FRotuloBemVindoSub: TLabel;
    FPainelStatus: TPanel;
    FStatusFinanceiro: TPanel;
    FStatusEstado: TPanel;
    FStatusPendencias: TPanel;
    FDestinoAtivo: Integer;
    FBarrasAtivas: array[TDestinoShell] of TPanel;
    FBotoesNav: array[TDestinoShell] of TcxButton;
    FMenu: TMainMenu;
    procedure FecharListaClientes;
    procedure FecharListaProdutos;
    procedure AoFecharListaClientes(Sender: TObject);
    procedure AoFecharListaProdutos(Sender: TObject);
    procedure MsgFecharLista(var Msg: TMessage); message WM_ERPV_FECHAR_LISTA;
    procedure MontarFaixaMarca;
    procedure MontarAreaConteudo;
    procedure MontarStatusBar;
    procedure MontarNavegacao;
    procedure MontarNavegacaoLateral;
    procedure MontarMenuDeBarra;
    function CriarAreaStatus(const AAlinhamento: TAlign; const ALargura: Integer;
      const ATextoAlinhamento: TAlignment): TPanel;
    procedure AdicionarGrupoNav(const ATitulo: string; var ATopo: Integer);
    procedure AdicionarItemNav(const ADestino: TDestinoShell; const ACaption: string;
      const AIcone: string; var ATopo: Integer);
    procedure AdicionarBotaoNav(const ACaption: string; const ATag: Integer;
      const AIcone: string; var ATopo: Integer; const AAcao: TNotifyEvent);
    procedure AtualizarItemAtivo(const ADestino: TDestinoShell);
    procedure DefinirTextoStatus(APainel: TPanel; const ATexto: string);
    procedure AoClicarDestino(Sender: TObject);
    procedure AoClicarSobre(Sender: TObject);
    procedure AoClicarSair(Sender: TObject);
    procedure AoClicarPendencias(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;

    /// <summary>
    ///   Injeta o dado de ambiente exibido na status bar (BaseUrl vinda do
    ///   INI, lida pelo composition root). Chamar uma vez apos criar o form.
    /// </summary>
    procedure Configurar(const ABaseUrlFinanceiro: string;
      AClienteService: TClienteService; AProdutoService: TProdutoService);

    /// <summary>
    ///   Ponto de entrada de navegacao. T14 ainda nao tem as telas (T19/T23/
    ///   T31/T52): marca o item ativo e informa que a tela ainda nao esta
    ///   disponivel. As tarefas seguintes trocam o corpo por abrir o form
    ///   filho dentro de AreaConteudo.
    /// </summary>
    procedure AbrirDestino(const ADestino: TDestinoShell);

    /// <summary>Estado exibido no centro da status bar ("Pronto", "Aguardando Financeiro...").</summary>
    procedure DefinirEstado(const ATexto: string);

    /// <summary>Container onde as telas de lista serao embutidas (Parent, Align=alClient).</summary>
    property AreaConteudo: TPanel read FAreaConteudo;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

const
  TAG_SEM_DESTINO = -1;
  ESTADO_PRONTO = 'Pronto';
  PENDENCIAS_FIXO = 'Pendências: 0'; // valor fixo ate T53 (contador real)
  LARGURA_STATUS_LATERAL = 280;
  LARGURA_STATUS_PENDENCIAS = 200;
  LARGURA_BARRA_ATIVA = 3;
  LARGURA_SOBRE = 360;
  ALTURA_SOBRE = 200;

{ TFormMain }

constructor TFormMain.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDestinoAtivo := TAG_SEM_DESTINO;
  Font.Name := ERPVFontePrincipal;
  Font.Size := ERPVTamCorpo;
  Font.Color := clERPVTextoPrincipal;
  Color := clERPVFundoApp;
  ClientWidth := EscalarPx(1024);
  ClientHeight := EscalarPx(640);

  // Ordem de criacao importa para o empilhamento dos alinhamentos: bordas
  // (topo/base) antes da nav lateral, e o conteudo (alClient) por ultimo.
  MontarFaixaMarca;
  MontarStatusBar;
  MontarNavegacao;
  MontarAreaConteudo;

  DefinirEstado(ESTADO_PRONTO);
  DefinirTextoStatus(FStatusPendencias, PENDENCIAS_FIXO);
end;

procedure TFormMain.Configurar(const ABaseUrlFinanceiro: string;
  AClienteService: TClienteService; AProdutoService: TProdutoService);
begin
  FBaseUrlFinanceiro := ABaseUrlFinanceiro;
  FClienteService := AClienteService;
  FProdutoService := AProdutoService;
  DefinirTextoStatus(FStatusFinanceiro, 'Financeiro: ' + FBaseUrlFinanceiro);
end;

procedure TFormMain.DefinirEstado(const ATexto: string);
begin
  DefinirTextoStatus(FStatusEstado, ATexto);
end;

procedure TFormMain.DefinirTextoStatus(APainel: TPanel; const ATexto: string);
begin
  APainel.Caption := ATexto;
end;

{ --- Faixa de marca ------------------------------------------------------ }

procedure TFormMain.MontarFaixaMarca;
begin
  FPainelMarca := TPanel.Create(Self);
  FPainelMarca.Parent := Self;
  FPainelMarca.Align := alTop;
  FPainelMarca.BevelOuter := bvNone;
  FPainelMarca.ParentBackground := False;
  FPainelMarca.Color := clERPVDestaque;
  FPainelMarca.Height := EscalarPx(ERPVAlturaFaixaMarca);

  // Logo real (imagem) e responsabilidade de T69; aqui so o nome do sistema.
  FRotuloMarca := TLabel.Create(FPainelMarca);
  FRotuloMarca.Parent := FPainelMarca;
  FRotuloMarca.Align := alClient;
  FRotuloMarca.AlignWithMargins := True;
  FRotuloMarca.Margins.Left := EscalarPx(ERPVMargemPagina);
  FRotuloMarca.Layout := tlCenter;
  FRotuloMarca.Font.Name := ERPVFontePrincipal;
  FRotuloMarca.Font.Size := ERPVTamFaixaMarca;
  FRotuloMarca.Font.Style := [fsBold];
  FRotuloMarca.Font.Color := clWhite;
  FRotuloMarca.Caption := 'ERP Vendas';
end;

{ --- Status bar (3 areas) ------------------------------------------------ }

function TFormMain.CriarAreaStatus(const AAlinhamento: TAlign; const ALargura: Integer;
  const ATextoAlinhamento: TAlignment): TPanel;
begin
  Result := TPanel.Create(FPainelStatus);
  Result.Parent := FPainelStatus;
  Result.Align := AAlinhamento;
  if AAlinhamento <> alClient then
    Result.Width := EscalarPx(ALargura);
  Result.BevelOuter := bvNone;
  Result.ParentBackground := False;
  Result.Color := clERPVSuperficie;
  Result.Alignment := ATextoAlinhamento;
  Result.Font.Name := ERPVFontePrincipal;
  Result.Font.Size := ERPVTamCorpo;
  Result.Font.Color := clERPVTextoSecundario;
  Result.AlignWithMargins := True;
  Result.Margins.Left := EscalarPx(ERPVEspaco8);
  Result.Margins.Right := EscalarPx(ERPVEspaco8);
  Result.Margins.Top := 0;
  Result.Margins.Bottom := 0;
end;

procedure TFormMain.MontarStatusBar;
var
  IconePend: TImage;
begin
  FPainelStatus := TPanel.Create(Self);
  FPainelStatus.Parent := Self;
  FPainelStatus.Align := alBottom;
  FPainelStatus.BevelOuter := bvNone;
  FPainelStatus.ParentBackground := False;
  FPainelStatus.Color := clERPVSuperficie;
  FPainelStatus.Height := EscalarPx(ERPVAlturaStatusBar);

  // Ordem: direita primeiro para o alClient ocupar o miolo.
  FStatusPendencias := CriarAreaStatus(alRight, LARGURA_STATUS_PENDENCIAS, taRightJustify);
  FStatusPendencias.Cursor := crHandPoint;
  FStatusPendencias.Hint := 'Abrir Pendências de Integração';
  FStatusPendencias.ShowHint := True;
  FStatusPendencias.OnClick := AoClicarPendencias;
  // T69: icone 'sinc' ao lado do texto (o texto "Pendencias: N" permanece)
  IconePend := TImage.Create(FStatusPendencias);
  IconePend.Parent := FStatusPendencias;
  IconePend.Align := alLeft;
  IconePend.Width := TamanhoIconeAtual + EscalarPx(ERPVEspaco8);
  IconePend.OnClick := AoClicarPendencias;
  if not AplicarIconeImagem(IconePend, ERPVIconeSinc) then
    IconePend.Visible := False;

  FStatusFinanceiro := CriarAreaStatus(alLeft, LARGURA_STATUS_LATERAL, taLeftJustify);
  FStatusEstado := CriarAreaStatus(alClient, 0, taCenter);
end;

procedure TFormMain.AoClicarPendencias(Sender: TObject);
begin
  AbrirDestino(dsPendencias);
end;

{ --- Area de conteudo ---------------------------------------------------- }

procedure TFormMain.MontarAreaConteudo;
begin
  FAreaConteudo := TPanel.Create(Self);
  FAreaConteudo.Parent := Self;
  FAreaConteudo.Align := alClient;
  FAreaConteudo.BevelOuter := bvNone;
  FAreaConteudo.ParentBackground := False;
  FAreaConteudo.Color := clERPVFundoApp;
  FAreaConteudo.AlignWithMargins := True;
  FAreaConteudo.Margins.SetBounds(EscalarPx(ERPVMargemPagina), EscalarPx(ERPVMargemPagina),
    EscalarPx(ERPVMargemPagina), EscalarPx(ERPVMargemPagina));

  FRotuloBemVindo := TLabel.Create(FAreaConteudo);
  FRotuloBemVindo.Parent := FAreaConteudo;
  FRotuloBemVindo.Left := 0;
  FRotuloBemVindo.Top := 0;
  FRotuloBemVindo.Font.Name := ERPVFontePrincipal;
  FRotuloBemVindo.Font.Size := ERPVTamTituloPagina;
  FRotuloBemVindo.Font.Style := [fsBold];
  FRotuloBemVindo.Font.Color := clERPVTextoPrincipal;
  FRotuloBemVindo.Caption := 'Bem-vindo';

  FRotuloBemVindoSub := TLabel.Create(FAreaConteudo);
  FRotuloBemVindoSub.Parent := FAreaConteudo;
  FRotuloBemVindoSub.Left := 0;
  FRotuloBemVindoSub.Top := FRotuloBemVindo.Top + FRotuloBemVindo.Height
    + EscalarPx(ERPVEspaco4);
  FRotuloBemVindoSub.Font.Name := ERPVFontePrincipal;
  FRotuloBemVindoSub.Font.Size := ERPVTamSubtitulo;
  FRotuloBemVindoSub.Font.Color := clERPVTextoSecundario;
  FRotuloBemVindoSub.Caption := 'Escolha uma opção na navegação para começar.';
end;

{ --- Navegacao ----------------------------------------------------------- }

procedure TFormMain.MontarNavegacao;
begin
  {$IFDEF ERPV_NAV_LATERAL}
  MontarNavegacaoLateral;
  {$ELSE}
  MontarMenuDeBarra;
  {$ENDIF}
end;

procedure TFormMain.AdicionarGrupoNav(const ATitulo: string; var ATopo: Integer);
var
  Rotulo: TLabel;
begin
  Rotulo := TLabel.Create(FPainelNav);
  Rotulo.Parent := FPainelNav;
  Rotulo.Left := EscalarPx(ERPVEspaco16);
  Rotulo.Top := ATopo + EscalarPx(ERPVEspaco8);
  Rotulo.Font.Name := ERPVFontePrincipal;
  Rotulo.Font.Size := ERPVTamCabecalhoCol;
  Rotulo.Font.Style := [fsBold];
  Rotulo.Font.Color := clERPVTextoSecundario;
  Rotulo.Caption := ATitulo;
  ATopo := Rotulo.Top + Rotulo.Height + EscalarPx(ERPVEspaco4);
end;

procedure TFormMain.AdicionarBotaoNav(const ACaption: string; const ATag: Integer;
  const AIcone: string; var ATopo: Integer; const AAcao: TNotifyEvent);
var
  Linha: TPanel;
  Barra: TPanel;
  Botao: TcxButton;
begin
  Linha := TPanel.Create(FPainelNav);
  Linha.Parent := FPainelNav;
  Linha.BevelOuter := bvNone;
  Linha.ParentBackground := False;
  Linha.Color := clERPVSuperficie;
  Linha.SetBounds(0, ATopo, FPainelNav.ClientWidth, EscalarPx(ERPVAlturaItemNav));
  Linha.Anchors := [akLeft, akTop, akRight];

  Barra := TPanel.Create(Linha);
  Barra.Parent := Linha;
  Barra.Align := alLeft;
  Barra.Width := EscalarPx(LARGURA_BARRA_ATIVA);
  Barra.BevelOuter := bvNone;
  Barra.ParentBackground := False;
  Barra.Color := clERPVDestaque;
  Barra.Visible := False;

  Botao := TcxButton.Create(Linha);
  Botao.Parent := Linha;
  Botao.Align := alClient;
  Botao.Caption := ACaption;
  Botao.Tag := ATag;
  Botao.OnClick := AAcao;
  EstilizarBotao(Botao, upbSecundario);
  AplicarIcone(Botao, AIcone); // T69: degrada para so texto; Caption permanece

  if (ATag >= Ord(Low(TDestinoShell))) and (ATag <= Ord(High(TDestinoShell))) then
  begin
    FBarrasAtivas[TDestinoShell(ATag)] := Barra;
    FBotoesNav[TDestinoShell(ATag)] := Botao;
  end;
  ATopo := ATopo + Linha.Height;
end;

procedure TFormMain.AdicionarItemNav(const ADestino: TDestinoShell; const ACaption: string;
  const AIcone: string; var ATopo: Integer);
begin
  AdicionarBotaoNav(ACaption, Ord(ADestino), AIcone, ATopo, AoClicarDestino);
end;

procedure TFormMain.MontarNavegacaoLateral;
var
  Topo: Integer;
begin
  FPainelNav := TPanel.Create(Self);
  FPainelNav.Parent := Self;
  FPainelNav.Align := alLeft;
  FPainelNav.Width := EscalarPx(ERPVLarguraNavLateral);
  FPainelNav.BevelOuter := bvNone;
  FPainelNav.ParentBackground := False;
  FPainelNav.Color := clERPVSuperficie;

  Topo := EscalarPx(ERPVEspaco8);
  AdicionarGrupoNav('Cadastros', Topo);
  AdicionarItemNav(dsClientes, '&Clientes', ERPVIconeBuscar, Topo);
  AdicionarItemNav(dsProdutos, '&Produtos', ERPVIconePastaVazia, Topo);
  AdicionarGrupoNav('Vendas', Topo);
  AdicionarItemNav(dsVendas, '&Vendas', ERPVIconeConfirmar, Topo);
  AdicionarGrupoNav('Integração', Topo);
  AdicionarItemNav(dsPendencias, 'P&endências', ERPVIconeSinc, Topo);
  AdicionarGrupoNav('Ajuda', Topo);
  AdicionarBotaoNav('&Sobre', TAG_SEM_DESTINO, ERPVIconeInfo, Topo, AoClicarSobre);
  AdicionarBotaoNav('Sai&r', TAG_SEM_DESTINO, ERPVIconeFechar, Topo, AoClicarSair);
end;

procedure TFormMain.MontarMenuDeBarra;
  function NovoItem(APai: TMenuItem; const ACaption: string; ATag: Integer;
    AAcao: TNotifyEvent): TMenuItem;
  begin
    Result := TMenuItem.Create(FMenu);
    Result.Caption := ACaption;
    Result.Tag := ATag;
    Result.OnClick := AAcao;
    APai.Add(Result);
  end;
var
  Cadastros, Vendas, Integracao, Ajuda: TMenuItem;
begin
  // Fallback (UX-SPEC 2.1): mesmas opcoes e mesmos atalhos da nav lateral.
  FMenu := TMainMenu.Create(Self);
  Cadastros := TMenuItem.Create(FMenu);
  Cadastros.Caption := 'C&adastros';
  FMenu.Items.Add(Cadastros);
  NovoItem(Cadastros, '&Clientes', Ord(dsClientes), AoClicarDestino);
  NovoItem(Cadastros, '&Produtos', Ord(dsProdutos), AoClicarDestino);

  Vendas := TMenuItem.Create(FMenu);
  Vendas.Caption := '&Vendas';
  FMenu.Items.Add(Vendas);
  NovoItem(Vendas, '&Vendas', Ord(dsVendas), AoClicarDestino);

  Integracao := TMenuItem.Create(FMenu);
  Integracao.Caption := '&Integração';
  FMenu.Items.Add(Integracao);
  NovoItem(Integracao, 'P&endências', Ord(dsPendencias), AoClicarDestino);

  Ajuda := TMenuItem.Create(FMenu);
  Ajuda.Caption := 'Aj&uda';
  FMenu.Items.Add(Ajuda);
  NovoItem(Ajuda, '&Sobre', TAG_SEM_DESTINO, AoClicarSobre);
  NovoItem(Ajuda, 'Sai&r', TAG_SEM_DESTINO, AoClicarSair);
end;

procedure TFormMain.AtualizarItemAtivo(const ADestino: TDestinoShell);
var
  D: TDestinoShell;
begin
  FDestinoAtivo := Ord(ADestino);
  for D := Low(TDestinoShell) to High(TDestinoShell) do
  begin
    if Assigned(FBarrasAtivas[D]) then
      FBarrasAtivas[D].Visible := D = ADestino;
    if Assigned(FBotoesNav[D]) then
      // Ativo = negrito (nao so cor, UX-SPEC 2.1)
      if D = ADestino then
        FBotoesNav[D].Font.Style := [fsBold]
      else
        FBotoesNav[D].Font.Style := [];
  end;
end;

procedure TFormMain.AbrirDestino(const ADestino: TDestinoShell);
begin
  AtualizarItemAtivo(ADestino);
  // T19 (Clientes) embutida; T23 (Produtos), T31 (Vendas) e T52 (Pendencias)
  // chegam depois; ate la o shell so informa, sem bloquear.
  if (ADestino = dsProdutos) and (FProdutoService <> nil) then
  begin
    FecharListaClientes;
    FecharListaProdutos;
    FRotuloBemVindo.Visible := False;
    FRotuloBemVindoSub.Visible := False;
    FListaProdutos := TFormListaProdutos.Create(Self, FProdutoService);
    FListaProdutos.BorderStyle := bsNone;
    FListaProdutos.Parent := FAreaConteudo;
    FListaProdutos.Align := alClient;
    FListaProdutos.OnFechada := AoFecharListaProdutos;
    FListaProdutos.Show;
  end
  else if (ADestino = dsClientes) and (FClienteService <> nil) then
  begin
    FecharListaProdutos;
    FecharListaClientes;
    FRotuloBemVindo.Visible := False;
    FRotuloBemVindoSub.Visible := False;
    FListaClientes := TFormListaClientes.Create(Self, FClienteService);
    FListaClientes.BorderStyle := bsNone;
    FListaClientes.Parent := FAreaConteudo;
    FListaClientes.Align := alClient;
    FListaClientes.OnFechada := AoFecharListaClientes;
    FListaClientes.Show;
  end
  else
    Notificar(utnInfo, 'Esta tela ainda não está disponível.', FAreaConteudo);
end;

procedure TFormMain.FecharListaClientes;
begin
  FreeAndNil(FListaClientes);
  FRotuloBemVindo.Visible := True;
  FRotuloBemVindoSub.Visible := True;
end;

procedure TFormMain.FecharListaProdutos;
begin
  FreeAndNil(FListaProdutos);
  FRotuloBemVindo.Visible := True;
  FRotuloBemVindoSub.Visible := True;
end;

procedure TFormMain.AoFecharListaProdutos(Sender: TObject);
begin
  // mesma mecânica da lista de clientes: libera fora do handler do botão/tecla
  PostMessage(Handle, WM_ERPV_FECHAR_LISTA, 0, 0);
end;

procedure TFormMain.AoFecharListaClientes(Sender: TObject);
begin
  // Fechar/Esc na lista embutida: volta ao "Bem-vindo". O Free acontece fora
  // do handler do proprio botao/tecla para nao destruir o form em uso.
  PostMessage(Handle, WM_ERPV_FECHAR_LISTA, 0, 0);
end;

procedure TFormMain.MsgFecharLista(var Msg: TMessage);
begin
  FecharListaClientes;
  FecharListaProdutos;
end;

procedure TFormMain.AoClicarDestino(Sender: TObject);
var
  Tag: Integer;
begin
  if Sender is TComponent then
  begin
    Tag := TComponent(Sender).Tag;
    if (Tag >= Ord(Low(TDestinoShell))) and (Tag <= Ord(High(TDestinoShell))) then
      AbrirDestino(TDestinoShell(Tag));
  end;
end;

procedure TFormMain.AoClicarSair(Sender: TObject);
begin
  Close;
end;

{ --- Sobre --------------------------------------------------------------- }

procedure TFormMain.AoClicarSobre(Sender: TObject);
var
  Dlg: TForm;
  Titulo, Texto: TLabel;
  Ok: TcxButton;
begin
  Dlg := TForm.Create(Self);
  try
    Dlg.BorderStyle := bsDialog;
    Dlg.Position := poOwnerFormCenter;
    Dlg.Caption := 'Sobre';
    Dlg.Color := clERPVSuperficie;
    Dlg.Font.Name := ERPVFontePrincipal;
    Dlg.Font.Size := ERPVTamCorpo;
    Dlg.ClientWidth := EscalarPx(LARGURA_SOBRE);
    Dlg.ClientHeight := EscalarPx(ALTURA_SOBRE);
    Dlg.KeyPreview := True;

    Titulo := TLabel.Create(Dlg);
    Titulo.Parent := Dlg;
    Titulo.SetBounds(EscalarPx(ERPVMargemPagina), EscalarPx(ERPVMargemPagina), 0, 0);
    Titulo.Font.Size := ERPVTamTituloPagina;
    Titulo.Font.Style := [fsBold];
    Titulo.Font.Color := clERPVTextoPrincipal;
    Titulo.Caption := 'ERP Vendas';

    Texto := TLabel.Create(Dlg);
    Texto.Parent := Dlg;
    Texto.SetBounds(EscalarPx(ERPVMargemPagina),
      Titulo.Top + Titulo.Height + EscalarPx(ERPVEspaco8),
      Dlg.ClientWidth - 2 * EscalarPx(ERPVMargemPagina), 0);
    Texto.AutoSize := False;
    Texto.WordWrap := True;
    Texto.Height := EscalarPx(72);
    Texto.Font.Color := clERPVTextoSecundario;
    Texto.Caption := 'Cadastro de clientes e produtos, vendas e integração com o ' +
      'sistema Financeiro.' + sLineBreak + 'Versão de desenvolvimento.';

    Ok := TcxButton.Create(Dlg);
    Ok.Parent := Dlg;
    Ok.Caption := 'OK';
    Ok.Default := True;
    Ok.Cancel := True;
    Ok.ModalResult := mrOk;
    Ok.Width := EscalarPx(96);
    Ok.SetBounds(Dlg.ClientWidth - Ok.Width - EscalarPx(ERPVMargemPagina),
      Dlg.ClientHeight - EscalarPx(ERPVAlturaControle) - EscalarPx(ERPVMargemPagina),
      Ok.Width, EscalarPx(ERPVAlturaControle));
    EstilizarBotao(Ok, upbPrimario);

    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

end.
