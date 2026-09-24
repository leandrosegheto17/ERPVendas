unit ERPV.Negocio.QuitacaoService;

(*
  T38 (Lote 9) - QuitacaoService.Confirmar, caminho feliz (RF-12/13, ADR-006).
  Camada Negocio: so depende de interfaces do Dominio e do Core.
  T49: apos Quitada gravada, PosQuitacao gera PDF, envia e-mail, apaga PDF; falha
  => venda segue Quitada + item EMAIL na fila; EmailStatus/EmailDestino no
  resultado (UI mostra UX 4.3 via Notificar). Roteiro manual T49: 1. mock ok +
  SMTP ok: e-mail com PDF, EmailStatus=eqEnviado, PDF some da pasta temp. 2. SMTP
  senha errada: STATUS=QUITADA, 1 linha EMAIL PENDENTE, aviso modal UX 4.3, sem
  excecao. 3. mock recusa/erro500: nenhum e-mail (EmailStatus=eqNaoAplicavel).
  4. Repetir falha: continua 1 item PENDENTE (tentativas+1). Nao compilado.
  T43 (Lote 10) acrescenta Cancelar nesta mesma classe (ver abaixo).

  T43 - QuitacaoService.Cancelar (RF-16/17, RN-02/08, ADR-005/006).
  Cancelar(AVendaId, AMotivo): le a venda do banco; nao encontrada, Quitada ou
  Cancelada => dcNaoPermitida, SEM POST (RN-02). POST de cancelamento fora de
  transacao (ADR-006). Sucesso com Status Cancelada => commit curto
  (AtualizarStatus, status + motivo) => dcCancelada. Recusado (4xx) => Pendente,
  nada na fila => dcRecusada (RN-08). Indisponivel => Pendente e enfileira
  CANCELAMENTO => dcEnfileirada. Resposta invalida => Pendente, nao enfileira
  (reconciliacao por GET e T50) => dcRespostaInvalida. Motivo opcional, aparado;
  '' = nao enviar. Falha esperada vira resultado tipado, nunca excecao.
  Roteiro manual T43: 1. mock ok + venda Pendente: Cancelar(Id,'Cliente
  desistiu') => dcCancelada, STATUS='Cancelada' e motivo gravado. 2. mock
  recusa: Pendente, fila sem linha, Mensagem preenchida => dcRecusada. 3. mock
  erro500/timeout: Pendente, 1 linha CANCELAMENTO PENDENTE com ULTIMO_ERRO =>
  dcEnfileirada; repetir = tentativas 2. 4. venda Quitada/Cancelada:
  dcNaoPermitida e o mock NAO recebe POST.

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
*)

interface

uses
  System.SysUtils,
  ERPV.Core.Erros,
  ERPV.Core.Log,
  ERPV.Dominio.Enums,
  ERPV.Dominio.Venda,
  ERPV.Dominio.Resultados,
  ERPV.Dominio.Contratos.IVendaRepository,
  ERPV.Dominio.Contratos.IFinanceiroGateway,
  ERPV.Dominio.Contratos.IFilaRepository,
  ERPV.Dominio.Contratos.IClienteRepository,
  ERPV.Dominio.Contratos.IRelatorioPedido,
  ERPV.Dominio.Contratos.IEmailSender,
  ERPV.Dominio.Cliente;

type
  /// <summary>T49: resultado do e-mail pos-quitacao (so relevante em qdSucesso).
  /// RF12-01: eqFalhouSemFila = e-mail falhou E o item EMAIL nao pode ser
  /// enfileirado (nao ha pendencia para reenviar); tambem e falha de e-mail.</summary>
  TEmailQuitacao = (eqNaoAplicavel, eqEnviado, eqFalhou, eqFalhouSemFila);

  TDesfechoQuitacao = (qdSucesso, qdRecusado, qdIndisponivel, qdRespostaInvalida);

  TDesfechoCancelamento = (
    dcCancelada,        // Financeiro confirmou; venda gravada como Cancelada
    dcRecusada,         // 4xx: continua Pendente, nao enfileirou
    dcEnfileirada,      // 5xx/timeout/rede: continua Pendente, na fila CANCELAMENTO
    dcNaoPermitida,     // venda inexistente ou nao Pendente: sem POST
    dcRespostaInvalida  // 200 ilegivel/inconsistente: continua Pendente, nao enfileirou
  );

  TResultadoCancelamento = record
    Desfecho: TDesfechoCancelamento;
    /// <summary>Mensagem para o chamador (UI, T44); vazia em dcCancelada.</summary>
    Mensagem: string;
    function Cancelou: Boolean; inline;
  end;

  TResultadoQuitacao = record
    Desfecho: TDesfechoQuitacao;
    /// <summary>Mensagem do Financeiro (vazia no sucesso).</summary>
    Mensagem: string;
    CodigoHttp: Integer;
    /// <summary>Preenchida so em qdSucesso.</summary>
    DataQuitacao: TDateTime;
    /// <summary>T49: eqEnviado (EmailDestino preenchido) ou eqFalhou (item EMAIL
    /// na fila). A UI exibe (UX 4.3); a quitacao nunca e desfeita.</summary>
    EmailStatus: TEmailQuitacao;
    EmailDestino: string;
    function EhSucesso: Boolean;
  end;

  TQuitacaoService = class
  private
    FVendaRepositorio: IVendaRepository;
    FFinanceiro: IFinanceiroGateway;
    FFilaRepositorio: IFilaRepository;
    FClienteRepositorio: IClienteRepository;
    FRelatorio: IRelatorioPedido;
    FEmailSender: IEmailSender;
    FLogger: TLogger; // RF12-01: nao e dono; pode ser nil
    FOnFase: TProc<string>;
    procedure PosQuitacao(AVendaId: Integer; var AResultado: TResultadoQuitacao);
    procedure EnfileirarIndisponivel(AVendaId: Integer;
      var AResultado: TResultadoQuitacao);
    function GravarQuitada(AVendaId: Integer; const AData: TDateTime;
      var AResultado: TResultadoQuitacao): Boolean;
    class function ResultadoCancelamento(ADesfecho: TDesfechoCancelamento;
      const AMensagem: string = ''): TResultadoCancelamento; static;
  public
    constructor Create(const AVendaRepositorio: IVendaRepository;
      const AFinanceiro: IFinanceiroGateway; const AFilaRepositorio: IFilaRepository;
      const AClienteRepositorio: IClienteRepository;
      const ARelatorio: IRelatorioPedido; const AEmailSender: IEmailSender;
      ALogger: TLogger = nil);

    /// <summary>Confirma a quitacao no Financeiro. Falha esperada de
    /// integracao vira resultado tipado, nunca excecao.</summary>
    /// <exception cref="ERegraNegocio">Venda inexistente ou nao Pendente
    /// (lancada antes do POST).</exception>
    function Confirmar(AVendaId: Integer): TResultadoQuitacao;

    /// <summary>RF13-02: pos-quitacao (PDF + e-mail; falha => item EMAIL na fila)
    /// para quitacao concluida fora do caminho sincrono (Reenviar/Pendencias).
    /// Nunca levanta excecao nem reposta o Financeiro; devolve o EmailStatus.</summary>
    function ExecutarPosQuitacao(AVendaId: Integer): TEmailQuitacao;

    /// <summary>RF12-03: aviso opcional de fase (best-effort; default nil).
    /// Recebe 'pos-quitacao' no inicio de PosQuitacao (PDF + SMTP).</summary>
    property OnFase: TProc<string> read FOnFase write FOnFase;

    /// <summary>Cancela venda Pendente no Financeiro e localmente (T43).
    /// AMotivo opcional. Sem excecao para falha esperada de integracao.</summary>
    function Cancelar(AVendaId: Integer; const AMotivo: string): TResultadoCancelamento;
  end;

implementation

uses
  ERPV.Negocio.PendenciaFila;

const
  MsgCancelarLocalFalhou = 'O cancelamento foi confirmado no Financeiro, mas não ' +
    'foi possível gravá-lo localmente; a venda continua Pendente';

{ TResultadoCancelamento }

function TResultadoCancelamento.Cancelou: Boolean;
begin
  Result := Desfecho = dcCancelada;
end;

function TResultadoQuitacao.EhSucesso: Boolean;
begin
  Result := Desfecho = qdSucesso;
end;

constructor TQuitacaoService.Create(const AVendaRepositorio: IVendaRepository;
  const AFinanceiro: IFinanceiroGateway; const AFilaRepositorio: IFilaRepository;
  const AClienteRepositorio: IClienteRepository;
  const ARelatorio: IRelatorioPedido; const AEmailSender: IEmailSender;
  ALogger: TLogger);
begin
  inherited Create;
  // Erro de programacao/config: falha cedo, nao vira "falha de e-mail" depois.
  if (AVendaRepositorio = nil) or (AFinanceiro = nil) or (AFilaRepositorio = nil) or
    (AClienteRepositorio = nil) or (ARelatorio = nil) or (AEmailSender = nil) then
    raise EInfra.Create('TQuitacaoService: dependencia obrigatoria ausente ' +
      '(Venda/Financeiro/Fila/Cliente/Relatorio/EmailSender).');
  FLogger := ALogger;
  FClienteRepositorio := AClienteRepositorio;
  FRelatorio := ARelatorio;
  FEmailSender := AEmailSender;
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

function TQuitacaoService.GravarQuitada(AVendaId: Integer;
  const AData: TDateTime; var AResultado: TResultadoQuitacao): Boolean;
begin
  // RF9-01: o Financeiro ja quitou; se a gravacao local falhar (EInfra), a
  // excecao nao escapa: venda segue Pendente e QUITACAO e enfileirada para
  // reenvio/reconciliacao. Mensagem sem dados do Financeiro nem erro tecnico.
  Result := True;
  try
    FVendaRepositorio.AtualizarStatus(AVendaId, svQuitada, AData, '');
  except
    on EInfra do
    begin
      Result := False;
      AResultado.Desfecho := qdIndisponivel;
      AResultado.Mensagem := 'A quitação foi confirmada no Financeiro, mas não ' +
        'foi possível gravá-la localmente; a venda segue Pendente e será ' +
        'reconciliada pela fila de pendências';
      EnfileirarIndisponivel(AVendaId, AResultado);
    end;
  end;
end;

procedure TQuitacaoService.PosQuitacao(AVendaId: Integer;
  var AResultado: TResultadoQuitacao);
var
  Venda: TVenda;
  Cliente: TCliente;
  Destino, Erro, Pdf: string;
  Env: TResultadoEnvioEmail;
begin
  // T49 (RF-13/21/22, RN-06, ADR-006): so chamado APOS o commit local de Quitada.
  // Sem transacao aberta (PDF/SMTP). Nada aqui levanta excecao nem desfaz a
  // quitacao; falha => item EMAIL na fila (1 PENDENTE por venda+tipo, RN-08).
  // Nao loga e-mail/CPF; o erro gravado na fila nao inclui o destinatario.
  if Assigned(FOnFase) then
    try
      FOnFase('pos-quitacao'); // RF12-03: best-effort
    except
    end;
  AResultado.EmailStatus := eqFalhou;
  AResultado.EmailDestino := '';
  Erro := '';
  Destino := '';
  Pdf := '';
  Venda := nil;
  Cliente := nil;
  try
    try
      Venda := FVendaRepositorio.Obter(AVendaId);
      if Venda = nil then
        Erro := 'Venda não encontrada para envio de e-mail'
      else
      begin
        Cliente := FClienteRepositorio.Obter(Venda.ClienteId);
        if Cliente <> nil then
          Destino := Trim(Cliente.Email);
        if Destino = '' then
          Erro := 'Cliente sem e-mail cadastrado'
        else
        begin
          Pdf := FRelatorio.GerarPdf(Venda);
          Env := FEmailSender.Enviar(Destino,
            Format('Confirmação de Pedido %d', [AVendaId]),
            Format('Segue em anexo a confirmação do pedido %d.', [AVendaId]), Pdf);
          if Env.Sucesso then
          begin
            AResultado.EmailStatus := eqEnviado;
            AResultado.EmailDestino := Destino;
          end
          else
            Erro := Env.MensagemErro;
        end;
      end;
    except
      on E: Exception do
        Erro := 'Falha ao gerar/enviar e-mail: ' + E.ClassName;
    end;
  finally
    Cliente.Free;
    Venda.Free;
  end;

  if Pdf <> '' then
    try
      // Apaga em sucesso e em falha (T51 regenera do banco; PDF nao persiste).
      FRelatorio.Limpar(Pdf);
    except
      // limpeza best-effort
    end;

  if AResultado.EmailStatus = eqFalhou then
  begin
    if Trim(Erro) = '' then
      Erro := 'Falha no envio de e-mail';
    try
      FFilaRepositorio.Enfileirar(AVendaId, tfEmail, Erro);
    except
      // RF12-01: sem item na fila; venda segue Quitada. Sinaliza para a UI nao
      // afirmar "ficou na fila" e loga so o Id (sem e-mail/CPF/msg tecnica).
      AResultado.EmailStatus := eqFalhouSemFila;
      if FLogger <> nil then
        try
          FLogger.Aviso(Format('Venda %d quitada; e-mail falhou e nao foi ' +
            'possivel enfileirar o item EMAIL', [AVendaId]));
        except
          // log best-effort
        end;
    end;
  end;
end;

function TQuitacaoService.ExecutarPosQuitacao(AVendaId: Integer): TEmailQuitacao;
var
  Res: TResultadoQuitacao;
begin
  Res := Default(TResultadoQuitacao);
  Res.Desfecho := qdSucesso;
  Res.EmailStatus := eqNaoAplicavel;
  try
    PosQuitacao(AVendaId, Res);
  except
    // defesa: pos-quitacao nunca deve derrubar o chamador
    Res.EmailStatus := eqFalhouSemFila;
  end;
  Result := Res.EmailStatus;
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
    // T53 (UX 4.2): QUITACAO/CANCELAMENTO pendente na fila => usar Pendencias.
    // RF13-06: EInfra da verificacao vira resultado tipado, sem chamar o Financeiro.
    try
      if VendaBloqueadaPorFila(FFilaRepositorio, AVendaId) then
        raise ERegraNegocio.Create(MSG_BLOQUEIO_FILA);
    except
      on EInfra do
      begin
        Result := Default(TResultadoQuitacao);
        Result.Desfecho := qdIndisponivel;
        Result.Mensagem := MSG_FALHA_VERIFICAR_FILA;
        Result.EmailStatus := eqNaoAplicavel;
        Exit;
      end;
    end;

    // ADR-006: nenhuma transacao aberta durante o HTTP.
    Resp := FFinanceiro.ConfirmarQuitacao(Venda);
  finally
    Venda.Free;
  end;

  Result.Mensagem := Resp.Mensagem;
  Result.CodigoHttp := Resp.CodigoHttp;
  Result.DataQuitacao := 0;
  Result.EmailStatus := eqNaoAplicavel;
  Result.EmailDestino := '';

  case Resp.Categoria of
    rfSucesso:
      if Resp.Status = svQuitada then
      begin
        Data := Resp.DataQuitacao;
        if Data = 0 then
          Data := Now;
        // Commit curto, isolado (ADR-006).
        if GravarQuitada(AVendaId, Data, Result) then
        begin
          Result.Desfecho := qdSucesso;
          Result.DataQuitacao := Data;
          PosQuitacao(AVendaId, Result);
        end;
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
          if GravarQuitada(AVendaId, Data, Result) then
          begin
            Result.Desfecho := qdSucesso;
            Result.DataQuitacao := Data;
            Result.Mensagem := 'Quitação já registrada no Financeiro; ' +
              'venda concluída localmente (reconciliação por consulta de status)';
            PosQuitacao(AVendaId, Result);
          end;
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

class function TQuitacaoService.ResultadoCancelamento(ADesfecho: TDesfechoCancelamento;
  const AMensagem: string): TResultadoCancelamento;
begin
  Result.Desfecho := ADesfecho;
  Result.Mensagem := AMensagem;
end;

function TQuitacaoService.Cancelar(AVendaId: Integer;
  const AMotivo: string): TResultadoCancelamento;
var
  Venda: TVenda;
  StatusAtual: TStatusVenda;
  Motivo: string;
  Resp: TResultadoFinanceiro;
begin
  // Status sempre lido do banco (RN-02); libera a entidade antes do HTTP.
  Venda := FVendaRepositorio.Obter(AVendaId);
  if Venda = nil then
    Exit(ResultadoCancelamento(dcNaoPermitida, 'Venda não encontrada'));
  try
    StatusAtual := Venda.Status;
  finally
    Venda.Free;
  end;

  if StatusAtual = svQuitada then
    Exit(ResultadoCancelamento(dcNaoPermitida, 'Venda já quitada não pode ser cancelada'));
  if StatusAtual = svCancelada then
    Exit(ResultadoCancelamento(dcNaoPermitida, 'Venda já está cancelada'));
  // T53 (UX 4.2): operacao pendente na fila bloqueia novo cancelamento.
  try
    if VendaBloqueadaPorFila(FFilaRepositorio, AVendaId) then
      Exit(ResultadoCancelamento(dcNaoPermitida, MSG_BLOQUEIO_FILA));
  except
    on EInfra do // RF13-06
      Exit(ResultadoCancelamento(dcNaoPermitida, MSG_FALHA_VERIFICAR_FILA));
  end;

  // RF10-01: MOTIVO_CANCELAMENTO e VARCHAR(255) (UI ja limita); recorta.
  Motivo := Copy(Trim(AMotivo), 1, 255);

  // RF10-02: o motivo NAO e persistido na FILA_INTEGRACAO (LGPD; opcional no
  // contrato). Ao enfileirar CANCELAMENTO ele se perde; o reenvio (T50) sai sem
  // motivo e MOTIVO_CANCELAMENTO fica NULL se concluido localmente no reenvio.
  // HTTP fora de transacao (ADR-006).
  Resp := FFinanceiro.ConfirmarCancelamento(AVendaId, Motivo);

  case Resp.Categoria of
    rfSucesso:
      if Resp.Status = svCancelada then
      begin
        try
          FVendaRepositorio.AtualizarStatus(AVendaId, svCancelada, 0, Motivo);
          Result := ResultadoCancelamento(dcCancelada);
        except
          on EInfra do
          begin
            // RF10-01: Financeiro ja cancelou; gravacao local falhou. Venda
            // segue Pendente; CANCELAMENTO vai para a fila (reconciliacao).
            // Desfecho dcNaoPermitida: a UI exibe a Mensagem como aviso.
            try
              FFilaRepositorio.Enfileirar(AVendaId, tfCancelamento, '');
              Result := ResultadoCancelamento(dcNaoPermitida, MsgCancelarLocalFalhou +
                '; o cancelamento foi colocado na fila de pendências');
            except
              on EInfra do
                Result := ResultadoCancelamento(dcNaoPermitida, MsgCancelarLocalFalhou +
                  ' e não foi possível colocá-lo na fila; tente novamente mais tarde');
            end;
          end;
        end;
      end
      else
        Result := ResultadoCancelamento(dcRespostaInvalida,
          'O Financeiro respondeu com um status inesperado para o cancelamento');
    rfRecusado:
      Result := ResultadoCancelamento(dcRecusada, Resp.Mensagem);
    rfIndisponivel:
      begin
        try
          FFilaRepositorio.Enfileirar(AVendaId, tfCancelamento, Resp.Mensagem);
          Result := ResultadoCancelamento(dcEnfileirada, Resp.Mensagem);
        except
          on EInfra do
            // RF10-01: sem fila nao ha reenvio; venda segue Pendente.
            Result := ResultadoCancelamento(dcNaoPermitida,
              'Financeiro indisponível e não foi possível colocar o cancelamento ' +
              'na fila; a venda continua Pendente. Tente novamente mais tarde');
        end;
      end;
  else
    Result := ResultadoCancelamento(dcRespostaInvalida, Resp.Mensagem);
  end;
end;

end.
