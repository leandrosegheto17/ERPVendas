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
  ERPV.Dominio.Contratos.IClienteRepository,
  ERPV.Dominio.Contratos.IRelatorioPedido,
  ERPV.Dominio.Contratos.IEmailSender, ERPV.Dominio.Cliente,
  ERPV.Negocio.QuitacaoService, ERPV.Negocio.FilaService,
  ERPV.Negocio.VendaService, ERPV.Negocio.PendenciaFila;

type
  TVendaFake = class(TInterfacedObject, IVendaRepository)
  public
    Status: TStatusVenda;
    Existe: Boolean;
    UltimoStatus: TStatusVenda;
    UltimoMotivo: string;
    Atualizacoes: Integer;
    FalharAtualizar: Boolean;
    ObterEInfra: Boolean;
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
    Enfileirados: Integer;
    UltimoTipoEnfileirado: TTipoFila;
    UltimoErro: string;
    FalharRegistrar: Boolean;
    FalharConcluir: Boolean;
    PendenciaBloqueia, PendenciaEInfra: Boolean;
    ItemExiste, ItemPendente, ItemTipoForcado: Boolean;
    ItemVendaId: Integer;
    ItemTipo: TTipoFila;
    constructor Create;
    function ObterItem(AId: Integer; out AVendaId: Integer; out ATipo: TTipoFila;
      out APendente: Boolean): Boolean;
    procedure Enfileirar(AVendaId: Integer; ATipo: TTipoFila; const AErro: string = '');
    function Listar(ASomentePendentes: Boolean): TDataSet;
    procedure MarcarConcluido(AId: Integer);
    procedure RegistrarFalha(AId: Integer; const AErro: string);
    function ContarPendencias: Integer;
    function ExistePendenciaPorVenda(AVendaId: Integer; ATipo: TTipoFila): Boolean;
  end;

  TClienteRepoFake = class(TInterfacedObject, IClienteRepository)
  public
    Email: string;
    constructor Create;
    function Incluir(const ACliente: TCliente): Integer;
    procedure Alterar(const ACliente: TCliente);
    procedure Excluir(AId: Integer);
    function Obter(AId: Integer): TCliente;
    function ListarDataSet(const AFiltroBusca: string; AIncluirInativos: Boolean): TDataSet;
    function ExistePorDocumento(const ACpfCnpj: string; AIgnorarId: Integer = 0): Boolean;
  end;

  TRelatorioFake = class(TInterfacedObject, IRelatorioPedido)
  public
    Gerados, Limpezas: Integer;
    LevantarGerar: Boolean;
    function GerarPdf(const AVenda: TVenda): string;
    procedure Limpar(const ACaminhoArquivo: string);
  end;

  TEmailFake = class(TInterfacedObject, IEmailSender)
  public
    Resp: TResultadoEnvioEmail;
    Envios: Integer;
    Levantar: Boolean;
    constructor Create;
    function Enviar(const ADestinatario, AAssunto, ACorpo, ACaminhoAnexoPdf: string): TResultadoEnvioEmail;
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
    FCli: TClienteRepoFake;
    FRel: TRelatorioFake;
    FEmail: TEmailFake;
    FCliI: IClienteRepository;
    FRelI: IRelatorioPedido;
    FEmailI: IEmailSender;
    FSvc: TFilaService;
    FQuit: TQuitacaoService;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure Quitacao_Erro500DepoisOk_ConcluiEQuita;
    [Test] procedure Quitacao_Erro500_MantemPendenteEIncrementa;
    [Test] procedure Quitacao_Recusa4xxComCpfEEmail_MensagemEErroMascarados;
    [Test] procedure Quitacao_GetJaQuitada_ConcluiLocalSemPost;
    [Test] procedure Cancelamento_ReenviaSemMotivo_MotivoNulo;
    [Test] procedure Cancelamento_Erro500_RegistraFalha;
    [Test] procedure Cancelamento_GetJaCancelada_ConcluiSemPost;
    [Test] procedure Email_SmtpOk_ConcluiELimpaPdf;
    [Test] procedure Email_SmtpFalha_MantemPendenteELimpaPdf;
    [Test] procedure Email_ExcecaoNoEnvio_ViraFalhaELimpaPdf;
    [Test] procedure Email_ExcecaoNoPdf_ViraFalhaSemLimpar;
    [Test] procedure Email_ClienteSemEmail_Falha;
    [Test] procedure Email_VendaNaoQuitada_Falha;
    [Test] procedure Email_MarcarConcluidoEInfra_ViraFalhaSemExcecao;
    [Test] procedure Email_RegistrarFalhaEInfra_ViraFalhaSemExcecao;
    [Test] procedure VendaInexistente_RegistraFalha;
    [Test] procedure GravacaoLocalEInfra_ViraFalhaSemExcecao;
    [Test] procedure RegistrarFalhaEInfra_ViraFalhaSemExcecao;
    [Test] procedure Item_Concluido_RecusaSemEfeitos;
    [Test] procedure Item_Inexistente_RecusaSemEfeitos;
    [Test] procedure Item_VinculoVendaErrada_RecusaSemEfeitos;
    [Test] procedure Item_TipoDivergente_RecusaSemEfeitos;
    [Test] procedure Item_Pendente_SegueFluxoNormal;
    [Test] procedure PosQuitacao_GetQuitada_EnviaEmailUmaVez;
    [Test] procedure PosQuitacao_PostOk_EnviaEmailUmaVez;
    [Test] procedure PosQuitacao_EmailFalha_EnfileiraEmail;
    [Test] procedure PosQuitacao_JaQuitadaLocal_NaoExecuta;
    [Test] procedure PosQuitacao_Cancelamento_NaoExecuta;
    [Test] procedure PosQuitacao_Excecao_NaoAlteraConcluido;
    [Test] procedure Bloqueio_Confirmar_ComPendencia_NaoChamaFinanceiro;
    [Test] procedure Bloqueio_Confirmar_FilaEInfra_ResultadoTipado;
    [Test] procedure Bloqueio_Cancelar_ComPendencia_NaoChamaFinanceiro;
    [Test] procedure Bloqueio_Cancelar_FilaEInfra_ResultadoTipado;
    [Test] procedure Bloqueio_VendaSalvar_ComPendencia_ERegraNegocio;
    [Test] procedure Bloqueio_VendaSalvar_FilaEInfra_ERegraNegocio;
    [Test] procedure Bloqueio_VendaExcluir_ComPendencia_ERegraNegocio;
    [Test] procedure Bloqueio_VendaExcluir_FilaEInfra_ERegraNegocio;
    [Test] procedure Reenviar_ObterEInfra_ViraFalha;
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
  if ObterEInfra then
    raise EInfra.Create('falha simulada');
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

constructor TFilaFake.Create;
begin
  inherited Create;
  ItemExiste := True;
  ItemPendente := True;
  ItemVendaId := 10;
  ItemTipo := tfQuitacao;
end;

function TFilaFake.ObterItem(AId: Integer; out AVendaId: Integer;
  out ATipo: TTipoFila; out APendente: Boolean): Boolean;
begin
  Result := ItemExiste;
  AVendaId := ItemVendaId;
  ATipo := ItemTipo;
  APendente := ItemPendente;
  if ItemTipoForcado then
    Exit;
  // Mapeamento padrao dos testes: Id 1 = QUITACAO, 2 = CANCELAMENTO, 3 = EMAIL.
  case AId of
    2: ATipo := tfCancelamento;
    3: ATipo := tfEmail;
  else
    ATipo := tfQuitacao;
  end;
end;

procedure TFilaFake.Enfileirar(AVendaId: Integer; ATipo: TTipoFila; const AErro: string);
begin
  Inc(Enfileirados);
  UltimoTipoEnfileirado := ATipo;
end;

function TFilaFake.Listar(ASomentePendentes: Boolean): TDataSet; begin Result := nil; end;
function TFilaFake.ContarPendencias: Integer; begin Result := 0; end;
function TFilaFake.ExistePendenciaPorVenda(AVendaId: Integer; ATipo: TTipoFila): Boolean;
begin
  if PendenciaEInfra then
    raise EInfra.Create('falha simulada');
  Result := PendenciaBloqueia and (ATipo = tfQuitacao);
end;

procedure TFilaFake.MarcarConcluido(AId: Integer);
begin
  if FalharConcluir then
    raise EInfra.Create('falha simulada');
  Inc(Concluidos);
end;

procedure TFilaFake.RegistrarFalha(AId: Integer; const AErro: string);
begin
  if FalharRegistrar then
    raise EInfra.Create('falha simulada');
  Inc(Falhas);
  UltimoErro := AErro;
end;

{ TClienteRepoFake }

constructor TClienteRepoFake.Create;
begin
  inherited Create;
  Email := 'cliente@teste.com';
end;

function TClienteRepoFake.Obter(AId: Integer): TCliente;
begin
  Result := TCliente.Create;
  Result.Id := AId;
  Result.Email := Email;
end;

function TClienteRepoFake.Incluir(const ACliente: TCliente): Integer; begin Result := 0; end;
procedure TClienteRepoFake.Alterar(const ACliente: TCliente); begin end;
procedure TClienteRepoFake.Excluir(AId: Integer); begin end;
function TClienteRepoFake.ListarDataSet(const AFiltroBusca: string; AIncluirInativos: Boolean): TDataSet; begin Result := nil; end;
function TClienteRepoFake.ExistePorDocumento(const ACpfCnpj: string; AIgnorarId: Integer): Boolean; begin Result := False; end;

{ TRelatorioFake }

function TRelatorioFake.GerarPdf(const AVenda: TVenda): string;
begin
  if LevantarGerar then
    raise Exception.Create('falha pdf');
  Inc(Gerados);
  Result := 'C:\temp\pedido.pdf';
end;

procedure TRelatorioFake.Limpar(const ACaminhoArquivo: string);
begin
  Inc(Limpezas);
end;

{ TEmailFake }

constructor TEmailFake.Create;
begin
  inherited Create;
  Resp := TResultadoEnvioEmail.Ok;
end;

function TEmailFake.Enviar(const ADestinatario, AAssunto, ACorpo,
  ACaminhoAnexoPdf: string): TResultadoEnvioEmail;
begin
  Inc(Envios);
  if Levantar then
    raise Exception.Create('falha smtp ' + ADestinatario);
  Result := Resp;
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
  FCli := TClienteRepoFake.Create;
  FRel := TRelatorioFake.Create;
  FEmail := TEmailFake.Create;
  FCliI := FCli;
  FRelI := FRel;
  FEmailI := FEmail;
  // GET padrao: Financeiro ainda Pendente => segue para o POST.
  FGw.RespStatus := TResultadoFinanceiro.Sucesso(svPendente);
  FQuit := TQuitacaoService.Create(FVendaI, FGwI, FFilaI, FCliI, FRelI, FEmailI);
  FSvc := TFilaService.Create(FVendaI, FGwI, FFilaI, FCliI, FRelI, FEmailI, FQuit);
end;

procedure TTestesFilaService.TearDown;
begin
  FSvc.Free;
  FQuit.Free;
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

procedure TTestesFilaService.Quitacao_Recusa4xxComCpfEEmail_MensagemEErroMascarados;
var
  R: TResultadoReenvio;
begin
  // RF13-04: dado pessoal na resposta do Financeiro nao chega em claro a UI.
  FGw.RespPost := TResultadoFinanceiro.Indisponivel(422,
    'Recusado: cliente 123.456.789-09 joao@example.com');
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.IsFalse(R.Mensagem.Contains('123.456.789-09'));
  Assert.IsFalse(R.Mensagem.Contains('joao@example.com'));
  Assert.IsTrue(R.Mensagem.Contains('***.456.789-**'));
  Assert.IsTrue(R.Mensagem.Contains('j***@example.com'));
  Assert.IsFalse(FFila.UltimoErro.Contains('123.456.789-09'));
  Assert.IsFalse(FFila.UltimoErro.Contains('joao@example.com'));
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

procedure TTestesFilaService.Email_SmtpOk_ConcluiELimpaPdf;
var
  R: TResultadoReenvio;
begin
  FVenda.Status := svQuitada;
  R := FSvc.Reenviar(3, 10, tfEmail);
  Assert.IsTrue(R.Concluiu);
  Assert.AreEqual(1, FFila.Concluidos);
  Assert.AreEqual(0, FFila.Falhas);
  Assert.AreEqual(1, FEmail.Envios);
  Assert.AreEqual(1, FRel.Gerados);
  Assert.AreEqual(1, FRel.Limpezas);
  Assert.AreEqual(0, FVenda.Atualizacoes);
  Assert.AreEqual(0, FGw.Gets + FGw.Posts);
end;

procedure TTestesFilaService.Email_SmtpFalha_MantemPendenteELimpaPdf;
var
  R: TResultadoReenvio;
begin
  FVenda.Status := svQuitada;
  FEmail.Resp := TResultadoEnvioEmail.Falha('SMTP fora do ar');
  R := FSvc.Reenviar(3, 10, tfEmail);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(0, FFila.Concluidos);
  Assert.AreEqual(1, FFila.Falhas);
  Assert.AreEqual('SMTP fora do ar', FFila.UltimoErro);
  Assert.AreEqual(1, FRel.Limpezas);
  Assert.AreEqual(0, FVenda.Atualizacoes);
end;

procedure TTestesFilaService.Email_ExcecaoNoEnvio_ViraFalhaELimpaPdf;
var
  R: TResultadoReenvio;
begin
  FVenda.Status := svQuitada;
  FEmail.Levantar := True;
  R := FSvc.Reenviar(3, 10, tfEmail);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(1, FFila.Falhas);
  Assert.AreEqual(1, FRel.Limpezas);
  Assert.IsFalse(FFila.UltimoErro.Contains('@'));
end;

procedure TTestesFilaService.Email_ExcecaoNoPdf_ViraFalhaSemLimpar;
var
  R: TResultadoReenvio;
begin
  FVenda.Status := svQuitada;
  FRel.LevantarGerar := True;
  R := FSvc.Reenviar(3, 10, tfEmail);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(1, FFila.Falhas);
  Assert.AreEqual(0, FEmail.Envios);
end;

procedure TTestesFilaService.Email_ClienteSemEmail_Falha;
var
  R: TResultadoReenvio;
begin
  FVenda.Status := svQuitada;
  FCli.Email := '';
  R := FSvc.Reenviar(3, 10, tfEmail);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(0, FEmail.Envios);
  Assert.AreEqual(1, FFila.Falhas);
end;

procedure TTestesFilaService.Email_VendaNaoQuitada_Falha;
var
  R: TResultadoReenvio;
begin
  FVenda.Status := svPendente;
  R := FSvc.Reenviar(3, 10, tfEmail);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(0, FEmail.Envios);
end;

procedure TTestesFilaService.Email_MarcarConcluidoEInfra_ViraFalhaSemExcecao;
var
  R: TResultadoReenvio;
begin
  FVenda.Status := svQuitada;
  FFila.FalharConcluir := True;
  R := FSvc.Reenviar(3, 10, tfEmail);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(1, FRel.Limpezas);
end;

procedure TTestesFilaService.Email_RegistrarFalhaEInfra_ViraFalhaSemExcecao;
var
  R: TResultadoReenvio;
begin
  FVenda.Status := svQuitada;
  FEmail.Resp := TResultadoEnvioEmail.Falha('x');
  FFila.FalharRegistrar := True;
  R := FSvc.Reenviar(3, 10, tfEmail);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.IsTrue(R.Mensagem <> '');
end;

procedure TTestesFilaService.VendaInexistente_RegistraFalha;
var
  R: TResultadoReenvio;
begin
  FVenda.Existe := False;
  FFila.ItemVendaId := 99;
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

procedure TTestesFilaService.Item_Concluido_RecusaSemEfeitos;
var
  R: TResultadoReenvio;
begin
  FFila.ItemPendente := False;
  R := FSvc.Reenviar(3, 10, tfEmail);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(0, FEmail.Envios);
  Assert.AreEqual(0, FGw.Gets + FGw.Posts);
  Assert.AreEqual(0, FFila.Concluidos);
  Assert.AreEqual(0, FFila.Falhas);
  Assert.AreEqual(0, FVenda.Atualizacoes);
end;

procedure TTestesFilaService.Item_Inexistente_RecusaSemEfeitos;
var
  R: TResultadoReenvio;
begin
  FFila.ItemExiste := False;
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(0, FGw.Gets + FGw.Posts);
  Assert.AreEqual(0, FFila.Concluidos + FFila.Falhas);
end;

procedure TTestesFilaService.Item_VinculoVendaErrada_RecusaSemEfeitos;
var
  R: TResultadoReenvio;
begin
  FFila.ItemVendaId := 99;
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(0, FGw.Gets + FGw.Posts);
  Assert.AreEqual(0, FFila.Concluidos + FFila.Falhas);
end;

procedure TTestesFilaService.Item_TipoDivergente_RecusaSemEfeitos;
var
  R: TResultadoReenvio;
begin
  FFila.ItemTipoForcado := True;
  FFila.ItemTipo := tfCancelamento;
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(0, FGw.Gets + FGw.Posts);
  Assert.AreEqual(0, FFila.Concluidos + FFila.Falhas);
end;

procedure TTestesFilaService.Item_Pendente_SegueFluxoNormal;
var
  R: TResultadoReenvio;
begin
  FGw.RespPost := TResultadoFinanceiro.Sucesso(svQuitada, Now);
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.IsTrue(R.Concluiu);
  Assert.AreEqual(1, FFila.Concluidos);
end;

procedure TTestesFilaService.PosQuitacao_GetQuitada_EnviaEmailUmaVez;
var
  R: TResultadoReenvio;
begin
  FGw.RespStatus := TResultadoFinanceiro.Sucesso(svQuitada);
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.IsTrue(R.Concluiu);
  Assert.AreEqual(0, FGw.Posts);
  Assert.AreEqual(1, FEmail.Envios);
  Assert.AreEqual(1, FRel.Gerados);
  Assert.AreEqual(1, FRel.Limpezas);
  Assert.AreEqual(0, FFila.Enfileirados);
end;

procedure TTestesFilaService.PosQuitacao_PostOk_EnviaEmailUmaVez;
var
  R: TResultadoReenvio;
begin
  FGw.RespPost := TResultadoFinanceiro.Sucesso(svQuitada, Now);
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.IsTrue(R.Concluiu);
  Assert.AreEqual(1, FGw.Posts);
  Assert.AreEqual(1, FEmail.Envios);
  Assert.AreEqual(1, FRel.Gerados);
  Assert.AreEqual(1, FFila.Concluidos);
end;

procedure TTestesFilaService.PosQuitacao_EmailFalha_EnfileiraEmail;
var
  R: TResultadoReenvio;
begin
  FEmail.Resp := TResultadoEnvioEmail.Falha('SMTP fora do ar');
  FGw.RespPost := TResultadoFinanceiro.Sucesso(svQuitada, Now);
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.IsTrue(R.Concluiu);
  Assert.AreEqual(1, FFila.Concluidos);
  Assert.AreEqual(1, FFila.Enfileirados);
  Assert.AreEqual(Ord(tfEmail), Ord(FFila.UltimoTipoEnfileirado));
  Assert.AreEqual(Ord(svQuitada), Ord(FVenda.Status));
end;

procedure TTestesFilaService.PosQuitacao_JaQuitadaLocal_NaoExecuta;
var
  R: TResultadoReenvio;
begin
  FVenda.Status := svQuitada;
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.IsTrue(R.Concluiu);
  Assert.AreEqual(0, FEmail.Envios);
  Assert.AreEqual(0, FRel.Gerados);
  Assert.AreEqual(0, FFila.Enfileirados);
end;

procedure TTestesFilaService.PosQuitacao_Cancelamento_NaoExecuta;
var
  R: TResultadoReenvio;
begin
  FGw.RespPost := TResultadoFinanceiro.Sucesso(svCancelada);
  R := FSvc.Reenviar(2, 10, tfCancelamento);
  Assert.IsTrue(R.Concluiu);
  Assert.AreEqual(0, FEmail.Envios);
  Assert.AreEqual(0, FRel.Gerados);
  Assert.AreEqual(0, FFila.Enfileirados);
end;

procedure TTestesFilaService.PosQuitacao_Excecao_NaoAlteraConcluido;
var
  R: TResultadoReenvio;
begin
  FRel.LevantarGerar := True;
  FGw.RespPost := TResultadoFinanceiro.Sucesso(svQuitada, Now);
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.AreEqual(Ord(rrConcluido), Ord(R.Desfecho));
  Assert.AreEqual(1, FFila.Concluidos);
  Assert.AreEqual(0, FFila.Falhas);
  Assert.AreEqual(Ord(svQuitada), Ord(FVenda.Status));
  Assert.AreEqual(1, FFila.Enfileirados);
end;

procedure TTestesFilaService.Bloqueio_Confirmar_ComPendencia_NaoChamaFinanceiro;
var
  Levantou: Boolean;
begin
  FFila.PendenciaBloqueia := True;
  Levantou := False;
  try
    FQuit.Confirmar(10);
  except
    on ERegraNegocio do
      Levantou := True;
  end;
  Assert.IsTrue(Levantou);
  Assert.AreEqual(0, FGw.Posts);
  Assert.AreEqual(0, FGw.Gets);
end;

procedure TTestesFilaService.Bloqueio_Confirmar_FilaEInfra_ResultadoTipado;
var
  R: TResultadoQuitacao;
begin
  FFila.PendenciaEInfra := True;
  R := FQuit.Confirmar(10);
  Assert.AreEqual(Ord(qdIndisponivel), Ord(R.Desfecho));
  Assert.AreEqual(MSG_FALHA_VERIFICAR_FILA, R.Mensagem);
  Assert.AreEqual(0, FGw.Posts);
  Assert.AreEqual(0, FGw.Gets);
  Assert.AreEqual(Ord(svPendente), Ord(FVenda.Status));
end;

procedure TTestesFilaService.Bloqueio_Cancelar_ComPendencia_NaoChamaFinanceiro;
var
  R: TResultadoCancelamento;
begin
  FFila.PendenciaBloqueia := True;
  R := FQuit.Cancelar(10, 'x');
  Assert.AreEqual(Ord(dcNaoPermitida), Ord(R.Desfecho));
  Assert.AreEqual(MSG_BLOQUEIO_FILA, R.Mensagem);
  Assert.AreEqual(0, FGw.Posts);
end;

procedure TTestesFilaService.Bloqueio_Cancelar_FilaEInfra_ResultadoTipado;
var
  R: TResultadoCancelamento;
begin
  FFila.PendenciaEInfra := True;
  R := FQuit.Cancelar(10, 'x');
  Assert.AreEqual(Ord(dcNaoPermitida), Ord(R.Desfecho));
  Assert.AreEqual(MSG_FALHA_VERIFICAR_FILA, R.Mensagem);
  Assert.AreEqual(0, FGw.Posts);
end;

procedure TTestesFilaService.Bloqueio_VendaSalvar_ComPendencia_ERegraNegocio;
var
  Svc: TVendaService;
  V: TVenda;
  Msg: string;
begin
  FFila.PendenciaBloqueia := True;
  Svc := TVendaService.Create(FVendaI, FCliI, nil, FFilaI);
  V := TVenda.Create;
  try
    V.Id := 10;
    Msg := '';
    try
      Svc.Salvar(V);
    except
      on E: ERegraNegocio do
        Msg := E.Message;
    end;
    Assert.AreEqual(MSG_BLOQUEIO_FILA, Msg);
  finally
    V.Free;
    Svc.Free;
  end;
end;

procedure TTestesFilaService.Bloqueio_VendaSalvar_FilaEInfra_ERegraNegocio;
var
  Svc: TVendaService;
  V: TVenda;
  Msg: string;
begin
  FFila.PendenciaEInfra := True;
  Svc := TVendaService.Create(FVendaI, FCliI, nil, FFilaI);
  V := TVenda.Create;
  try
    V.Id := 10;
    Msg := '';
    try
      Svc.Salvar(V);
    except
      on E: ERegraNegocio do
        Msg := E.Message;
    end;
    Assert.AreEqual(MSG_FALHA_VERIFICAR_FILA, Msg);
  finally
    V.Free;
    Svc.Free;
  end;
end;

procedure TTestesFilaService.Bloqueio_VendaExcluir_ComPendencia_ERegraNegocio;
var
  Svc: TVendaService;
  Msg: string;
begin
  FFila.PendenciaBloqueia := True;
  Svc := TVendaService.Create(FVendaI, FCliI, nil, FFilaI);
  try
    Msg := '';
    try
      Svc.Excluir(10);
    except
      on E: ERegraNegocio do
        Msg := E.Message;
    end;
    Assert.AreEqual(MSG_BLOQUEIO_FILA, Msg);
  finally
    Svc.Free;
  end;
end;

procedure TTestesFilaService.Bloqueio_VendaExcluir_FilaEInfra_ERegraNegocio;
var
  Svc: TVendaService;
  Msg: string;
begin
  FFila.PendenciaEInfra := True;
  Svc := TVendaService.Create(FVendaI, FCliI, nil, FFilaI);
  try
    Msg := '';
    try
      Svc.Excluir(10);
    except
      on E: ERegraNegocio do
        Msg := E.Message;
    end;
    Assert.AreEqual(MSG_FALHA_VERIFICAR_FILA, Msg);
  finally
    Svc.Free;
  end;
end;

procedure TTestesFilaService.Reenviar_ObterEInfra_ViraFalha;
var
  R: TResultadoReenvio;
begin
  FVenda.ObterEInfra := True;
  R := FSvc.Reenviar(1, 10, tfQuitacao);
  Assert.AreEqual(Ord(rrFalha), Ord(R.Desfecho));
  Assert.AreEqual(0, FGw.Posts);
  Assert.AreEqual(0, FFila.Concluidos);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestesFilaService);

end.
