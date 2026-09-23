unit ERPV.UI.FormTesteTema;

{
  T68 (Lote 3) - Form de teste manual do tema/tokens (criterio de aceite:
  "form de teste com grade zebra, 3 papeis de botao e Notificar nos 4
  tipos"). NAO faz parte do fluxo real do app (nao e criado por
  ERPVendas.dpr) - existe so para o usuario abrir na IDE e conferir
  visualmente os itens do criterio de aceite de T68. Ver roteiro de
  verificacao manual na nota de T68 em TASK.md.

  Construido inteiramente em codigo (sem .dfm) para nao depender de stream
  binario/texto de componentes DevExpress que este agente nao pode gerar
  com seguranca sem compilar - minimiza risco de "property does not exist"
  ao carregar um .dfm com propriedades desatualizadas para a versao
  instalada (DevExpress VCL 26.1.4).

  ==========================================================================
  COMO RODAR (roteiro resumido; roteiro completo na nota de T68 do TASK.md)
  ==========================================================================
  Este form nao esta em nenhum uses do .dpr (de proposito, para nao alterar
  o fluxo real do app). Para testar na IDE:
  1. Abrir ERPVendas.dpr.
  2. Adicionar temporariamente ao uses:
       ERPV.UI.FormTesteTema in 'src\UI\ERPV.UI.FormTesteTema.pas' {FormTesteTema},
  3. Trocar temporariamente a linha
       Application.CreateForm(TFormMain, FormMain);
     por
       Application.CreateForm(TFormTesteTema, FormTesteTema);
  4. Compilar (F9) e conferir cada item do criterio de aceite de T68.
  5. Desfazer as duas mudancas no .dpr antes de commitar (nao commitar como
     fluxo real - FormMain continua sendo o form principal, T14 o completa).

  Formulas de conversao de cor e demais decisoes: ver cabecalhos de
  ERPV.UI.Tokens.pas e ERPV.UI.Tema.pas.
}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Datasnap.DBClient, Data.DB,
  cxGrid, cxGridCustomTableView, cxGridDBTableView, cxGridCustomView,
  cxButtons,
  ERPV.UI.Tokens, ERPV.UI.Tema;

type
  TFormTesteTema = class(TForm)
  private
    FDadosTeste: TClientDataSet;
    FFonteDados: TDataSource;
    FGrid: TcxGrid;
    FGridView: TcxGridDBTableView;
    FRotuloResultado: TLabel;
    procedure MontarDadosDeTeste;
    procedure MontarGradeDeTeste;
    procedure MontarBotoesDePapel(const ATopo: Integer);
    procedure MontarBotoesDeNotificar(const ATopo: Integer);
    procedure AoClicarInfo(Sender: TObject);
    procedure AoClicarAviso(Sender: TObject);
    procedure AoClicarErro(Sender: TObject);
    procedure AoClicarPergunta(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  FormTesteTema: TFormTesteTema;

implementation

{ TFormTesteTema }

constructor TFormTesteTema.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner); // sem .dfm - construido 100% em codigo

  // AplicarTema normalmente e chamado uma unica vez pelo composition root
  // (T13/T14); aqui e chamado tambem porque este form roda isolado (fora
  // do fluxo real do app) - AplicarTema e idempotente, entao nao ha risco
  // de dupla aplicacao mesmo se o usuario tambem chamar via FormMain.
  ERPV.UI.Tema.AplicarTema;

  Caption := 'T68 - Teste de Tema/Tokens (ERPV.UI.Tema)';
  Width := 720;
  Height := 560;
  Position := poScreenCenter;
  Font.Name := ERPVFontePrincipal;
  Font.Size := ERPVTamCorpo;
  Color := clERPVFundoApp;

  MontarDadosDeTeste;
  MontarGradeDeTeste;
  MontarBotoesDePapel(340);
  MontarBotoesDeNotificar(380);

  FRotuloResultado := TLabel.Create(Self);
  FRotuloResultado.Parent := Self;
  FRotuloResultado.SetBounds(ERPVMargemPagina, 420, 680, 40);
  FRotuloResultado.WordWrap := True;
  FRotuloResultado.Caption := 'Resultado do ultimo teste aparece aqui.';
  FRotuloResultado.Font.Color := clERPVTextoSecundario;
end;

procedure TFormTesteTema.MontarDadosDeTeste;
var
  I: Integer;
begin
  // Dataset em memoria (Datasnap.DBClient, sem dependencia de banco real)
  // so para a grade de teste ter linhas suficientes para ver a zebra.
  FDadosTeste := TClientDataSet.Create(Self);
  FDadosTeste.FieldDefs.Add('Codigo', ftInteger);
  FDadosTeste.FieldDefs.Add('Nome', ftString, 40);
  FDadosTeste.FieldDefs.Add('Situacao', ftString, 10);
  FDadosTeste.CreateDataSet;

  FDadosTeste.InsertRecord([1, 'Ana Silva', 'Ativo']);
  FDadosTeste.InsertRecord([2, 'Acme Ltda', 'Inativo']);
  FDadosTeste.InsertRecord([3, 'Bruno Costa', 'Ativo']);
  FDadosTeste.InsertRecord([4, 'Carla Souza', 'Ativo']);
  FDadosTeste.InsertRecord([5, 'D. Distribuidora', 'Inativo']);
  FDadosTeste.InsertRecord([6, 'Erica Lima', 'Ativo']);
  for I := 7 to 10 do
    FDadosTeste.InsertRecord([I, Format('Cliente teste %d', [I]), 'Ativo']);
  FDadosTeste.First;

  FFonteDados := TDataSource.Create(Self);
  FFonteDados.DataSet := FDadosTeste;
end;

procedure TFormTesteTema.MontarGradeDeTeste;
begin
  FGrid := TcxGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.SetBounds(ERPVMargemPagina, ERPVMargemPagina, 680, 280);
  FGrid.Anchors := [akLeft, akTop, akRight];

  // Criacao de view em tempo de execucao (API TcxGrid.CreateView) - assuncao
  // documentada em ERPV.UI.Tema.pas (cabecalho, secao ConfigurarGrade). O
  // TcxGrid sempre nasce com 1 nivel padrao (Levels[0]); associa-se a view
  // recem-criada a esse nivel.
  FGridView := FGrid.CreateView(TcxGridDBTableView) as TcxGridDBTableView;
  FGrid.Levels[0].GridView := FGridView;
  FGridView.DataController.DataSource := FFonteDados;
  // Gera as colunas automaticamente a partir dos campos do dataset.
  FGridView.DataController.CreateAllItems;

  // Unica chamada de estilo desta grade - tudo o resto (zebra, cabecalho,
  // linhas, indicador, agrupamento, selecao) vem daqui.
  ConfigurarGrade(FGridView);
end;

procedure TFormTesteTema.MontarBotoesDePapel(const ATopo: Integer);
var
  BtnPrimario, BtnSecundario, BtnPerigoso: TcxButton;
begin
  BtnPrimario := TcxButton.Create(Self);
  BtnPrimario.Parent := Self;
  BtnPrimario.SetBounds(ERPVMargemPagina, ATopo, 140, ERPVAlturaControle);
  BtnPrimario.Caption := 'Salvar (Primario)';
  EstilizarBotao(BtnPrimario, upbPrimario);

  BtnSecundario := TcxButton.Create(Self);
  BtnSecundario.Parent := Self;
  BtnSecundario.SetBounds(ERPVMargemPagina + 150, ATopo, 140, ERPVAlturaControle);
  BtnSecundario.Caption := 'Cancelar (Secundario)';
  EstilizarBotao(BtnSecundario, upbSecundario);

  BtnPerigoso := TcxButton.Create(Self);
  BtnPerigoso.Parent := Self;
  BtnPerigoso.SetBounds(ERPVMargemPagina + 300, ATopo, 140, ERPVAlturaControle);
  BtnPerigoso.Caption := 'Excluir (Perigoso)';
  EstilizarBotao(BtnPerigoso, upbPerigoso);
end;

procedure TFormTesteTema.MontarBotoesDeNotificar(const ATopo: Integer);
var
  BtnInfo, BtnAviso, BtnErro, BtnPergunta: TcxButton;
begin
  BtnInfo := TcxButton.Create(Self);
  BtnInfo.Parent := Self;
  BtnInfo.SetBounds(ERPVMargemPagina, ATopo, 160, ERPVAlturaControle);
  BtnInfo.Caption := 'Notificar: Info (banner)';
  BtnInfo.OnClick := AoClicarInfo;

  BtnAviso := TcxButton.Create(Self);
  BtnAviso.Parent := Self;
  BtnAviso.SetBounds(ERPVMargemPagina + 170, ATopo, 160, ERPVAlturaControle);
  BtnAviso.Caption := 'Notificar: Aviso (modal)';
  BtnAviso.OnClick := AoClicarAviso;

  BtnErro := TcxButton.Create(Self);
  BtnErro.Parent := Self;
  BtnErro.SetBounds(ERPVMargemPagina + 340, ATopo, 160, ERPVAlturaControle);
  BtnErro.Caption := 'Notificar: Erro (modal)';
  BtnErro.OnClick := AoClicarErro;

  BtnPergunta := TcxButton.Create(Self);
  BtnPergunta.Parent := Self;
  BtnPergunta.SetBounds(ERPVMargemPagina + 510, ATopo, 160, ERPVAlturaControle);
  BtnPergunta.Caption := 'Notificar: Pergunta (modal)';
  BtnPergunta.OnClick := AoClicarPergunta;
end;

procedure TFormTesteTema.AoClicarInfo(Sender: TObject);
begin
  // Texto literal de UX-SPEC 4.3 ("Quitada + e-mail enviado").
  Notificar(utnInfo, 'Venda 10 quitada. Relatório enviado para ana@x.com.', Self);
  FRotuloResultado.Caption := 'Ultimo teste: Info (banner deve ter aparecido no topo do form, some em ~6s ou ao clicar).';
end;

procedure TFormTesteTema.AoClicarAviso(Sender: TObject);
begin
  // Texto literal de UX-SPEC 4.3 ("Financeiro indisponível/timeout").
  Notificar(utnAviso, 'Financeiro indisponível. A venda 10 continua Pendente e foi colocada na fila. Tente novamente em Pendências.');
  FRotuloResultado.Caption := 'Ultimo teste: Aviso (dialogo modal, botao OK).';
end;

procedure TFormTesteTema.AoClicarErro(Sender: TObject);
begin
  // Texto literal de UX-SPEC 4.3 ("Erro inesperado").
  Notificar(utnErro, 'Ocorreu um erro inesperado. Os detalhes foram gravados no log.');
  FRotuloResultado.Caption := 'Ultimo teste: Erro (dialogo modal, botao OK).';
end;

procedure TFormTesteTema.AoClicarPergunta(Sender: TObject);
var
  Confirmado: Boolean;
begin
  // Texto literal de UX-SPEC 4.3 ("Confirmação antes de quitar").
  Confirmado := Notificar(utnPergunta, 'Confirmar a venda 10 (R$ 350,00)? Esta ação envia a quitação ao Financeiro.');
  if Confirmado then
    FRotuloResultado.Caption := 'Ultimo teste: Pergunta -> usuario respondeu "Sim".'
  else
    FRotuloResultado.Caption := 'Ultimo teste: Pergunta -> usuario respondeu "Não".';
end;

end.
