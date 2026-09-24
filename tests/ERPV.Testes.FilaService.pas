unit ERPV.Testes.FilaService;

(*
  T50 - testes DUnitX de TFilaService.Reenviar com fakes das interfaces do
  Dominio (sem banco, sem HTTP). Nao compilado (sem CLI); rodar na IDE num
  projeto de testes DUnitX que inclua src\Dominio, src\Core e src\Negocio.
  Cenario do aceite: mock erro500 depois ok.
*)

interface

uses
  System.SysUtils, Data.DB, DUnitX.TestFramework, ERPV.Core.Erros,
  ERPV.Dominio.Enums, ERPV.Dominio.Venda, ERPV.Dominio.Resultados,
  ERPV.Dominio.Contratos.IVendaRepository,
  ERPV.Dominio.Contratos.IFinanceiroGateway,
  ERPV.Dominio.Contratos.IFilaRepository,
  ERPV.Negocio.FilaService;

type
  TVendaFake = class(TInterfacedObject, IVendaRepository)
  public
    Status: TStatusVenda;
    Existe: Boolean;
    UltimoStatus: TStatusVenda;
    UltimoMotivo: string;
    Atualizacoes: Integer;
    FalharAtualizar: Boolean;
    constructor Create;
    function Incluir(const AVenda: TVenda): Integer;
    procedure Alterar(const AVenda: TVenda);
    procedure Excluir(AId: Integer);
    function Obter(AId: Integer): TVenda;
    procedure AtualizarStatus(AId: Integer; AStatus: TStatusVenda; ADataQuitacao: TDateTime;
      const AMotivoCancelamento: string);
    function ListarDataSet(const AStatusFiltro: string; AClienteIdFiltro: Integer): TDataSet;
    function RelatorioDataSet(AVendaId: Integer): TDataSet;
    function ExisteVendaPorCliente(AClienteId: Integer): Boolean;
    function ExisteVendaPorProduto(AProdutoId: Integer): Boolean;
  end;

  TGatewayFake = class(TInterfacedObject, IFinanceiroGateway)
  public
    RespPost, RespStatus: TResultadoFinanceiro;
    Posts, Gets: Integer;
    MotivoRecebido: string;
    function ConfirmarQuitacao(const AVenda: TVenda): TResultadoFinanceiro;
    function ConfirmarCancelamento(AVendaId: Integer; const AMotivo: string): TResultadoFinanceiro;
    function ConsultarStatus(AVendaId: Integer): TResultadoFinanceiro;
  end;

  TFilaFake = class(TInterfacedObject, IFilaRepository)
  public
    Concluidos, Falhas: Integer;
    UltimoErro: string;
    FalharRegistrar: Boolean;
    procedure Enfileirar(AVendaId: Integer; ATipo: TTipoFila; const AErro: string = '');
    function Listar(ASomentePendentes: Boolean): TDataSet;
    procedure MarcarConcluido(AId: Integer);
    procedure RegistrarFalha(AId: Integer; const AErro: string);
    function ContarPendencias: Integer;
    function ExistePendenciaPorVenda(AVendaId: Integer; ATipo: TTipoFila): Boolean;
  end;

  [TestFixture]
  TTestesFilaService = class
  private
    FVenda: TVendaFake;
    FGw: TGatewayFake;
    FFila: TFilaFake;
    FVendaI: IVendaRepository;
    FGwI: IFinanceiroGateway;
    FFilaI: IFilaRepository;
    FSvc: TFilaService;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure Quitacao_Erro500DepoisOk_ConcluiEQuita;
    [Test] procedure Quitacao_Erro500_MantemPendenteEIncrementa;
    [Test] procedure Quitacao_GetJaQuitada_ConcluiLocalSemPost;
    [Test] procedure Cancelamento_ReenviaSemMotivo_MotivoNulo;
    [Test] procedure Cancelamento_Erro500_RegistraFalha;
    [Test] procedure Cancelamento_GetJaCancelada_ConcluiSemPost;
    [Test] procedure Email_NaoSuportado_SemEfeito;
    [Test] procedure VendaInexistente_RegistraFalha;
    [Test] procedure GravacaoLocalEInfra_ViraFalhaSemExcecao;
    [Test] procedure RegistrarFalhaEInfra_ViraFalhaSemExcecao;
  end;

implementation

{ TVendaFake }

constructor TVendaFake.Create;
begin
  inherited Create;
  Existe := True;
  Status := svPendente;
end;

function TVendaFake.Obter(AId: Integer): TVenda;
begin
  if not Existe then
    Exit(nil);
  Result := TVenda.Create;
  Result.Id := AId;
  Result.Status := Status;
end;

procedure TVendaFake.AtualizarStatus(AId: Integer; AStatus: TStatusVenda;
  ADataQuitacao: TDateTime; const AMotivoCancelamento: string);
begin
  if FalharAtualizar then
    raise EInfra.Create('falha simulada');
  Status := AStatus;
  UltimoStatus := AStatus;
  UltimoMotivo := AMotivoCancelamento;
  Inc(Atualizacoes);
end;

function TVendaFake.Incluir(const AVenda: TVenda): Integer; begin Result := 0; end;
procedure TVendaFake.Alterar(const AVenda: TVenda); begin end;
procedure TVendaFake.Excluir(AId: Integer); begin end;
function TVendaFake.ListarDataSet(const AStatusFiltro: string; AClienteIdFiltro: Integer): TDataSet; begin Result := nil; end;
function TVendaFake.RelatorioDataSet(AVendaId: Integer): TDataSet; begin Result := nil; end;
function TVendaFake.ExisteVendaPorCliente(AClienteId: Integer): Boolean; begin Result := False; end;
function TVendaFake.ExisteVendaPorProduto(AProdutoId: Integer): Boolean; begin Result := False; end;

{ TGatewayFake }

function TGatewayFake.ConfirmarQuitacao(const AVenda: TVenda): TResultadoFinanceiro;
begin
  Inc(Posts);
  Result := RespPost;
end;

function TGatewayFake.ConfirmarCancelamento(AVendaId: Integer;
  const AMotivo: string): TResultadoFinanceiro;
begin
  Inc(Posts);
  MotivoRecebido := AMotivo;
  Result := RespPost;
end;

function TGatewayFake.ConsultarStatus(AVendaId: Integer): TResultadoFinanceiro;
begin
  Inc(Gets);
  Result := RespStatus;
end;

{ TFilaFake }

procedure TFilaFake.Enfileirar(AVendaId: Integer; ATipo: TTipoFila; const AErro: string); begin end;
function TFilaFake.Listar(ASomentePendentes: Boolean): TDataSet; begin Result := nil; end;
function TFilaFake.ContarPendencias: Integer; begin Result := 0; end;
function TFilaFake.ExistePendenciaPorVenda(AVendaId: Integer; ATipo: TTipoFila): Boolean; begin Result := False; end;

procedure TFilaFake.MarcarConcluido(AId: Integer);
begin
  Inc(Concluidos);
end;

procedure TFilaFake.RegistrarFalha(AId: Integer; const AErro: string);
begin
  if FalharRegistrar then
    raise EInfra.Create('falha simulada');
  Inc(Falhas);
  UltimoErro := AErro;
end;

{ TTestesFilaService }

procedure TTestesFilaService.Setup;
begin
  FVenda := TVendaFake.Create;
  FGw := TGatewayFake.Create;
  FFila := TFilaFake.Create;
  FVendaI := FVenda;
  FGwI := FGw;
  FFilaI := FFila;
  // GET padrao: Financeiro ainda Pendente => segue para o POST.
  FGw.RespStatus := TResultadoFinanceiro.Sucesso(svPendente);
  FSvc := TFilaService.Create(FVendaI, FGwI, FFilaI);
end;

procedure TTestesFilaService.TearDown;
begin
  FSvc.Free;
end;

procedure TTestesFilaService.Quitacao_Erro500DepoisOk_ConcluiEQuita;
var
  R: TResultadoReenvio;
begin
  FGw.RespPost := TResultadoFinanceiro.Indisponivel(500, 'erro 500');
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));

  FGw.RespPost := TResultadoFinanceiro.Sucesso(svQuitada, Now);
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.IsTrue(R.Concluiu);
  Assert.AreEqual(1, FFila.Concluidos);
  Assert.AreEqual(Ord(svQuitada), Ord(FVenda.Status));
end;

procedure TTestesFilaService.Quitacao_Erro500_MantemPendenteEIncrementa;
var
  R: TResultadoReenvio;
begin
  FGw.RespPost := TResultadoFinanceiro.Indisponivel(500, 'erro 500');
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(1, FFila.Falhas);
  Assert.AreEqual('erro 500', FFila.UltimoErro);
  Assert.AreEqual(0, FFila.Concluidos);
  Assert.AreEqual(Ord(svPendente), Ord(FVenda.Status));
end;

procedure TTestesFilaService.Quitacao_GetJaQuitada_ConcluiLocalSemPost;
var
  R: TResultadoReenvio;
begin
  FGw.RespStatus := TResultadoFinanceiro.Sucesso(svQuitada);
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.IsTrue(R.Concluiu);
  Assert.AreEqual(0, FGw.Posts);
  Assert.AreEqual(1, FFila.Concluidos);
  Assert.AreEqual(Ord(svQuitada), Ord(FVenda.Status));
end;

procedure TTestesFilaService.Cancelamento_ReenviaSemMotivo_MotivoNulo;
var
  R: TResultadoReenvio;
begin
  FGw.RespPost := TResultadoFinanceiro.Sucesso(svCancelada);
  R := FSvc.Reenviar(2, 10, tfCancelamento);
  Assert.IsTrue(R.Concluiu);
  Assert.AreEqual('', FGw.MotivoRecebido);
  Assert.AreEqual('', FVenda.UltimoMotivo);
  Assert.AreEqual(Ord(svCancelada), Ord(FVenda.Status));
  Assert.AreEqual(1, FFila.Concluidos);
end;

procedure TTestesFilaService.Cancelamento_Erro500_RegistraFalha;
var
  R: TResultadoReenvio;
begin
  FGw.RespPost := TResultadoFinanceiro.Indisponivel(500, 'erro 500');
  R := FSvc.Reenviar(2, 10, tfCancelamento);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(1, FFila.Falhas);
  Assert.AreEqual(Ord(svPendente), Ord(FVenda.Status));
end;

procedure TTestesFilaService.Cancelamento_GetJaCancelada_ConcluiSemPost;
var
  R: TResultadoReenvio;
begin
  FGw.RespStatus := TResultadoFinanceiro.Sucesso(svCancelada);
  R := FSvc.Reenviar(2, 10, tfCancelamento);
  Assert.IsTrue(R.Concluiu);
  Assert.AreEqual(0, FGw.Posts);
  Assert.AreEqual('', FVenda.UltimoMotivo);
end;

procedure TTestesFilaService.Email_NaoSuportado_SemEfeito;
var
  R: TResultadoReenvio;
begin
  R := FSvc.Reenviar(3, 10, tfEmail);
  Assert.AreEqual(Ord(rrNaoSuportado), Ord(R.Desfecho));
  Assert.AreEqual(0, FFila.Falhas + FFila.Concluidos);
  Assert.AreEqual(0, FGw.Gets + FGw.Posts);
end;

procedure TTestesFilaService.VendaInexistente_RegistraFalha;
var
  R: TResultadoReenvio;
begin
  FVenda.Existe := False;
  R := FSvc.Reenviar(1, 99, tfQuitacao);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(1, FFila.Falhas);
end;

procedure TTestesFilaService.GravacaoLocalEInfra_ViraFalhaSemExcecao;
var
  R: TResultadoReenvio;
begin
  FVenda.FalharAtualizar := True;
  FGw.RespPost := TResultadoFinanceiro.Sucesso(svQuitada, Now);
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(0, FFila.Concluidos);
  Assert.AreEqual(1, FFila.Falhas);
  Assert.AreEqual(Ord(svPendente), Ord(FVenda.Status));
end;

procedure TTestesFilaService.RegistrarFalhaEInfra_ViraFalhaSemExcecao;
var
  R: TResultadoReenvio;
begin
  FFila.FalharRegistrar := True;
  FGw.RespPost := TResultadoFinanceiro.Indisponivel(500, 'erro 500');
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.IsTrue(R.Mensagem <> '');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestesFilaService);

end.
