unit ERPV.Negocio.FilaService;

(*
  T50 (Lote 13) - FilaService.Reenviar QUITACAO/CANCELAMENTO (RF-23, ADR-005).
  Camada Negocio: so depende de interfaces do Dominio e do Core.

  Reenviar(AFilaId, AVendaId, ATipo): antes de repostar, GET status (ADR-005).
  - Venda ja no estado alvo localmente (Quitada p/ QUITACAO, Cancelada p/
    CANCELAMENTO) ou GET devolve o estado alvo => conclui local (sem POST) e
    MarcarConcluido.
  - Caso contrario, POST fora de transacao (ADR-006). Sucesso com status alvo =>
    commit curto (AtualizarStatus) + MarcarConcluido. Recusado/Indisponivel/
    resposta invalida/estado conflitante => RegistrarFalha (mantem PENDENTE,
    tentativas+1, ULTIMO_ERRO; a mascara RF9-05 e aplicada no FilaRepository).
  - RF10-02: CANCELAMENTO reenvia SEM motivo; ao concluir no reenvio,
    MOTIVO_CANCELAMENTO fica NULL (AtualizarStatus com ''). Motivo nunca e
    logado nem persistido aqui.
  - EInfra (banco) NAO escapa (padrao RF9-01/RF10-01): falha ao gravar o status
    local, ao MarcarConcluido ou ao RegistrarFalha vira rrFalha com mensagem
    amigavel (sem dado pessoal/erro tecnico); item segue PENDENTE e o proximo
    reenvio reconcilia pelo GET. Sem log aqui (o service nao tem logger).
  - tfEmail e responsabilidade de T51: aqui devolve rrNaoSuportado, sem efeito.
  Roteiro manual T50: 1. mock erro500, Confirmar => item QUITACAO PENDENTE;
  mock ok, Reenviar => rrConcluido, item CONCLUIDO, venda QUITADA. 2. mock
  ainda erro500: rrFalha, TENTATIVAS+1, ULTIMO_ERRO preenchido, item PENDENTE.
  3. Cancelamento idem, MOTIVO_CANCELAMENTO NULL. Nao compilado.
*)

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
  TDesfechoReenvio = (
    rrConcluido,     // item CONCLUIDO e venda no estado alvo
    rrFalha,         // segue PENDENTE, tentativas+1, erro registrado
    rrNaoSuportado   // tipo tratado por outra tarefa (EMAIL, T51)
  );

  TResultadoReenvio = record
    Desfecho: TDesfechoReenvio;
    /// <summary>Mensagem para a UI (T52): erro no rrFalha; vazia se concluido.</summary>
    Mensagem: string;
    function Concluiu: Boolean; inline;
  end;

  TFilaService = class
  private
    FVendaRepositorio: IVendaRepository;
    FFinanceiro: IFinanceiroGateway;
    FFilaRepositorio: IFilaRepository;
    function Falha(AFilaId: Integer; const AMensagem: string): TResultadoReenvio;
    function ConcluirLocal(AFilaId, AVendaId: Integer; AAlvo: TStatusVenda;
      const AData: TDateTime): TResultadoReenvio;
  public
    constructor Create(const AVendaRepositorio: IVendaRepository;
      const AFinanceiro: IFinanceiroGateway; const AFilaRepositorio: IFilaRepository);

    /// <summary>Reenvia item PENDENTE de QUITACAO/CANCELAMENTO. Falha esperada
    /// de integracao vira resultado tipado, nunca excecao.</summary>
    function Reenviar(AFilaId, AVendaId: Integer; ATipo: TTipoFila): TResultadoReenvio;
  end;

implementation

const
  MsgFalhaLocal = 'Não foi possível concluir o item localmente; ele segue ' +
    'pendente e será reconciliado no próximo reenvio';

function TResultadoReenvio.Concluiu: Boolean;
begin
  Result := Desfecho = rrConcluido;
end;

constructor TFilaService.Create(const AVendaRepositorio: IVendaRepository;
  const AFinanceiro: IFinanceiroGateway; const AFilaRepositorio: IFilaRepository);
begin
  inherited Create;
  FVendaRepositorio := AVendaRepositorio;
  FFinanceiro := AFinanceiro;
  FFilaRepositorio := AFilaRepositorio;
end;

function TFilaService.Falha(AFilaId: Integer; const AMensagem: string): TResultadoReenvio;
var
  Msg: string;
begin
  Msg := Trim(AMensagem);
  if Msg = '' then
    Msg := 'Falha no reenvio';
  try
    FFilaRepositorio.RegistrarFalha(AFilaId, Msg);
  except
    on EInfra do
      Msg := MsgFalhaLocal;
  end;
  Result.Desfecho := rrFalha;
  Result.Mensagem := Msg;
end;

function TFilaService.ConcluirLocal(AFilaId, AVendaId: Integer;
  AAlvo: TStatusVenda; const AData: TDateTime): TResultadoReenvio;
begin
  // Commit curto (ADR-006). Motivo sempre '' (RF10-02: NULL no reenvio).
  try
    FVendaRepositorio.AtualizarStatus(AVendaId, AAlvo, AData, '');
    FFilaRepositorio.MarcarConcluido(AFilaId);
  except
    on EInfra do
      Exit(Falha(AFilaId, MsgFalhaLocal));
  end;
  Result.Desfecho := rrConcluido;
  Result.Mensagem := '';
end;

function TFilaService.Reenviar(AFilaId, AVendaId: Integer;
  ATipo: TTipoFila): TResultadoReenvio;
var
  Venda: TVenda;
  StatusLocal, Alvo, Oposto: TStatusVenda;
  Resp: TResultadoFinanceiro;
  Data: TDateTime;
begin
  if not (ATipo in [tfQuitacao, tfCancelamento]) then
  begin
    Result.Desfecho := rrNaoSuportado;
    Result.Mensagem := '';
    Exit;
  end;

  if ATipo = tfQuitacao then
  begin
    Alvo := svQuitada;
    Oposto := svCancelada;
  end
  else
  begin
    Alvo := svCancelada;
    Oposto := svQuitada;
  end;

  Venda := FVendaRepositorio.Obter(AVendaId);
  if Venda = nil then
    Exit(Falha(AFilaId, 'Venda não encontrada'));
  try
    StatusLocal := Venda.Status;
  finally
    Venda.Free;
  end;

  // Ja no estado alvo localmente: nada a repostar.
  if StatusLocal = Alvo then
  begin
    try
      FFilaRepositorio.MarcarConcluido(AFilaId);
    except
      on EInfra do
        Exit(Falha(AFilaId, MsgFalhaLocal));
    end;
    Result.Desfecho := rrConcluido;
    Result.Mensagem := '';
    Exit;
  end;
  if StatusLocal = Oposto then
    Exit(Falha(AFilaId, 'A venda já está ' + StatusVendaToStr(Oposto) +
      '; a operação pendente não pode ser reenviada'));

  // ADR-005: reconcilia por GET status antes de repostar (sem transacao).
  Resp := FFinanceiro.ConsultarStatus(AVendaId);
  if Resp.Categoria = rfSucesso then
  begin
    if Resp.Status = Alvo then
    begin
      Data := 0;
      if Alvo = svQuitada then
      begin
        Data := Resp.DataQuitacao;
        if Data = 0 then
          Data := Now; // GET status nao devolve data
      end;
      Exit(ConcluirLocal(AFilaId, AVendaId, Alvo, Data));
    end;
    if Resp.Status = Oposto then
      Exit(Falha(AFilaId, 'O Financeiro já registrou a venda como ' +
        StatusVendaToStr(Oposto) + '; reenvio não realizado'));
  end;

  // POST fora de transacao (ADR-006); cancelamento sai SEM motivo (RF10-02).
  if ATipo = tfQuitacao then
  begin
    Venda := FVendaRepositorio.Obter(AVendaId);
    if Venda = nil then
      Exit(Falha(AFilaId, 'Venda não encontrada'));
    try
      Resp := FFinanceiro.ConfirmarQuitacao(Venda);
    finally
      Venda.Free;
    end;
  end
  else
    Resp := FFinanceiro.ConfirmarCancelamento(AVendaId, '');

  case Resp.Categoria of
    rfSucesso:
      if Resp.Status = Alvo then
      begin
        Data := 0;
        if Alvo = svQuitada then
        begin
          Data := Resp.DataQuitacao;
          if Data = 0 then
            Data := Now;
        end;
        Result := ConcluirLocal(AFilaId, AVendaId, Alvo, Data);
      end
      else
        Result := Falha(AFilaId, 'Resposta do Financeiro com status inesperado');
  else
    Result := Falha(AFilaId, Resp.Mensagem);
  end;
end;

end.
