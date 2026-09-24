unit ERPV.Negocio.QuitacaoService;

{
  T38 (Lote 9) - QuitacaoService.Confirmar, caminho feliz (RF-12/13, ADR-006).
  Camada Negocio: so depende de interfaces do Dominio e do Core.

  Fluxo: (1) le a venda do banco e exige Pendente (senao ERegraNegocio, ANTES
  do POST); (2) POST via IFinanceiroGateway SEM transacao aberta; (3) 200
  Quitada => commit curto AtualizarStatus(Quitada, dataQuitacao).
  Demais desfechos so sao MAPEADOS, sem efeito colateral: T39 (recusa), T40
  (indisponivel + fila), T49 (PDF/e-mail) acrescentam comportamento.

  ==========================================================================
  ROTEIRO MANUAL NA IDE (sem compilacao via CLI; pendente de confirmacao)
  ==========================================================================
  Pre: mock do Financeiro no ar, INI apontando para ele, venda Pendente.
  1. Mock ok: Confirmar(Id) => Desfecho = qdSucesso; no banco STATUS=QUITADA e
     DATA_QUITACAO preenchida.
  2. Chamar Confirmar de novo na mesma venda => ERegraNegocio, sem POST
     (conferir que o mock nao registrou nova requisicao).
  3. Venda Cancelada ou inexistente => ERegraNegocio.
  4. Mock recusa/erro500/timeout/parado => Desfecho qdRecusado/qdIndisponivel
     com Mensagem; venda continua Pendente no banco, nada gravado.
  T40 (manual): mock erro500 ou timeout ou parado => Confirmar devolve
     qdIndisponivel (retorna em ate o timeout, UI nao trava); venda Pendente;
     SELECT na FILA_SINCRONIZACAO: 1 linha TIPO=QUITACAO, STATUS=PENDENTE,
     ULTIMO_ERRO preenchido. Repetir Confirmar: continua 1 item PENDENTE (sem
     duplicar). Com a fila forcada a falhar: qdIndisponivel com "Aviso: nao
     foi possivel enfileirar" na Mensagem, sem excecao.
  T41 (reconciliacao): LIMITACAO do mock: o modo global "timeout" atrasa 11 s
     tambem o GET status, entao o GET da reconciliacao tambem estoura e o fluxo
     cai na fila (T40). Roteiro possivel: (a) mock ok, quitar via POST manual
     (curl) SEM a venda local saber; (b) mock timeout; (c) Confirmar => POST
     estoura, GET estoura => enfileira (comportamento T40, esperado). Para
     validar o caminho T41 de ponta a ponta na IDE e preciso GET respondendo
     ok com POST em timeout. Alteracao minima sugerida no mock (nao feita):
     modo "timeout-post" que atrasa so POST e deixa GET /status normal; entao:
     quitar via curl, "_modo?m=timeout-post", Confirmar => venda QUITADA,
     DATA_QUITACAO = Now, FILA_SINCRONIZACAO vazia, log do mock com 1 POST
     (o da confirmacao) e nenhum reenvio. Alternativa: teste unitario com
     IFinanceiroGateway falso (POST=Indisponivel, GET=Quitada).
  T39 (recusa 4xx): mock modo recusa => Desfecho = qdRecusado, Mensagem igual a
     do Financeiro (se vazia: "Quitação recusada pelo Financeiro (código HTTP
     xxx)"), CodigoHttp preenchido; venda segue Pendente e a fila de pendencias
     fica vazia (nenhum item QUITACAO).
}

interface

uses
  System.SysUtils,
  ERPV.Core.Erros,
  ERPV.Dominio.Enums,
  ERPV.Dominio.Venda,
  ERPV.Dominio.Resultados,
  ERPV.Dominio.Contratos.IVendaRepository,
  ERPV.Dominio.Contratos.IFinanceiroGateway,
  ERPV.Dominio.Contratos.IFilaRepository;

type
  TDesfechoQuitacao = (qdSucesso, qdRecusado, qdIndisponivel, qdRespostaInvalida);

  TResultadoQuitacao = record
    Desfecho: TDesfechoQuitacao;
    /// <summary>Mensagem do Financeiro (vazia no sucesso).</summary>
    Mensagem: string;
    CodigoHttp: Integer;
    /// <summary>Preenchida so em qdSucesso.</summary>
    DataQuitacao: TDateTime;
    function EhSucesso: Boolean;
  end;

  TQuitacaoService = class
  private
    FVendaRepositorio: IVendaRepository;
    FFinanceiro: IFinanceiroGateway;
    FFilaRepositorio: IFilaRepository;
    procedure EnfileirarIndisponivel(AVendaId: Integer;
      var AResultado: TResultadoQuitacao);
  public
    constructor Create(const AVendaRepositorio: IVendaRepository;
      const AFinanceiro: IFinanceiroGateway; const AFilaRepositorio: IFilaRepository);

    /// <summary>Confirma a quitacao no Financeiro. Falha esperada de
    /// integracao vira resultado tipado, nunca excecao.</summary>
    /// <exception cref="ERegraNegocio">Venda inexistente ou nao Pendente
    /// (lancada antes do POST).</exception>
    function Confirmar(AVendaId: Integer): TResultadoQuitacao;
  end;

implementation

function TResultadoQuitacao.EhSucesso: Boolean;
begin
  Result := Desfecho = qdSucesso;
end;

constructor TQuitacaoService.Create(const AVendaRepositorio: IVendaRepository;
  const AFinanceiro: IFinanceiroGateway; const AFilaRepositorio: IFilaRepository);
begin
  inherited Create;
  FVendaRepositorio := AVendaRepositorio;
  FFinanceiro := AFinanceiro;
  FFilaRepositorio := AFilaRepositorio;
end;

procedure TQuitacaoService.EnfileirarIndisponivel(AVendaId: Integer;
  var AResultado: TResultadoQuitacao);
var
  Erro: string;
begin
  // Ponto unico de enfileiramento (T41 reconcilia por GET antes de chamar).
  // Decisao: falha ao enfileirar (EInfra) NAO mascara o desfecho nem propaga:
  // devolve qdIndisponivel com aviso na mensagem; venda segue Pendente.
  Erro := AResultado.Mensagem;
  if Trim(Erro) = '' then
    Erro := 'Financeiro indisponível (código HTTP ' +
      IntToStr(AResultado.CodigoHttp) + ')';
  AResultado.Mensagem := Erro;
  try
    FFilaRepositorio.Enfileirar(AVendaId, tfQuitacao, Erro);
  except
    on E: EInfra do
      AResultado.Mensagem := Erro +
        ' | Aviso: não foi possível enfileirar o reenvio (' + E.Message + ')';
  end;
end;

function TQuitacaoService.Confirmar(AVendaId: Integer): TResultadoQuitacao;
var
  Venda: TVenda;
  Resp: TResultadoFinanceiro;
  Data: TDateTime;
begin
  // Status sempre lido do banco (mesmo padrao de VendaService.ExigirPendente).
  Venda := FVendaRepositorio.Obter(AVendaId);
  try
    if Venda = nil then
      raise ERegraNegocio.Create('Venda não encontrada');
    if Venda.Status <> svPendente then
      raise ERegraNegocio.Create(
        'Somente venda pendente pode ser quitada (status atual: ' +
        StatusVendaToStr(Venda.Status) + ')');

    // ADR-006: nenhuma transacao aberta durante o HTTP.
    Resp := FFinanceiro.ConfirmarQuitacao(Venda);
  finally
    Venda.Free;
  end;

  Result.Mensagem := Resp.Mensagem;
  Result.CodigoHttp := Resp.CodigoHttp;
  Result.DataQuitacao := 0;

  case Resp.Categoria of
    rfSucesso:
      if Resp.Status = svQuitada then
      begin
        Data := Resp.DataQuitacao;
        if Data = 0 then
          Data := Now;
        // Commit curto, isolado (ADR-006).
        FVendaRepositorio.AtualizarStatus(AVendaId, svQuitada, Data, '');
        Result.Desfecho := qdSucesso;
        Result.DataQuitacao := Data;
      end
      else
      begin
        // 200 com status diferente de Quitada: nao confiavel, sem efeito.
        Result.Desfecho := qdRespostaInvalida;
        Result.Mensagem := 'Resposta do Financeiro com status inesperado';
      end;
    rfRecusado:
      begin
        // T39 (RF-15, RN-08): 4xx => nao grava status, nao enfileira; a venda
        // segue Pendente. Mensagem do Financeiro chega integra; se vazia,
        // fallback com o codigo HTTP.
        Result.Desfecho := qdRecusado;
        if Trim(Result.Mensagem) = '' then
          Result.Mensagem := 'Quitação recusada pelo Financeiro (código HTTP ' +
            IntToStr(Result.CodigoHttp) + ')';
      end;
    rfIndisponivel:
      begin
        // T40 (RF-14, RN-07/08): 5xx/timeout/rede => venda segue Pendente e
        // enfileira QUITACAO para reenvio.
        // T41 (RF-18, ADR-005): antes de enfileirar, reconcilia por GET status
        // (sem transacao aberta). Quitada no Financeiro => conclui local, sem
        // novo POST e sem fila. Qualquer outro resultado segue o fluxo T40.
        Resp := FFinanceiro.ConsultarStatus(AVendaId);
        if (Resp.Categoria = rfSucesso) and (Resp.Status = svQuitada) then
        begin
          Data := Resp.DataQuitacao;
          if Data = 0 then
            Data := Now; // GET status nao devolve data
          FVendaRepositorio.AtualizarStatus(AVendaId, svQuitada, Data, '');
          Result.Desfecho := qdSucesso;
          Result.DataQuitacao := Data;
          Result.Mensagem := 'Quitação já registrada no Financeiro; ' +
            'venda concluída localmente (reconciliação por consulta de status)';
        end
        else
        begin
          Result.Desfecho := qdIndisponivel;
          EnfileirarIndisponivel(AVendaId, Result);
        end;
      end;
  else
    Result.Desfecho := qdRespostaInvalida;
  end;
end;

end.
