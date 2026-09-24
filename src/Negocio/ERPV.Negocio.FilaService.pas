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
    reenvio reconcilia pelo GET. Log so de Ids/desfecho (RF13-05).
  - T51 (EMAIL): venda ja Quitada, status intocado. Regenera PDF do banco
    (IRelatorioPedido), envia (IEmailSender), apaga o PDF sempre; sucesso =>
    MarcarConcluido; falha (SMTP, sem e-mail, excecao) => rrFalha + RegistrarFalha
    (PENDENTE, tentativas+1). EInfra/Exception nao escapam; sem log de e-mail.
    rrNaoSuportado fica so para tipos desconhecidos.
  Roteiro manual T50: 1. mock erro500, Confirmar => item QUITACAO PENDENTE;
  mock ok, Reenviar => rrConcluido, item CONCLUIDO, venda QUITADA. 2. mock
  ainda erro500: rrFalha, TENTATIVAS+1, ULTIMO_ERRO preenchido, item PENDENTE.
  3. Cancelamento idem, MOTIVO_CANCELAMENTO NULL. Nao compilado.
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
  ERPV.Dominio.Cliente,
  ERPV.Negocio.QuitacaoService;

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
    FClienteRepositorio: IClienteRepository;
    FRelatorio: IRelatorioPedido;
    FEmailSender: IEmailSender;
    FQuitacao: TQuitacaoService; // RF13-02: nao e dono; pode ser nil
    FLogger: TLogger; // RF13-05: nao e dono; pode ser nil
    function ReenviarEmail(AFilaId, AVendaId: Integer): TResultadoReenvio;
    function ReenviarInterno(AFilaId, AVendaId: Integer;
      ATipo: TTipoFila): TResultadoReenvio;
    procedure Registrar(AFilaId, AVendaId: Integer; ATipo: TTipoFila;
      ADesfecho: TDesfechoReenvio);
    function Falha(AFilaId: Integer; const AMensagem: string): TResultadoReenvio;
    function ConcluirLocal(AFilaId, AVendaId: Integer; AAlvo: TStatusVenda;
      const AData: TDateTime): TResultadoReenvio;
  public
    constructor Create(const AVendaRepositorio: IVendaRepository;
      const AFinanceiro: IFinanceiroGateway; const AFilaRepositorio: IFilaRepository;
      const AClienteRepositorio: IClienteRepository;
      const ARelatorio: IRelatorioPedido; const AEmailSender: IEmailSender;
      AQuitacao: TQuitacaoService = nil; ALogger: TLogger = nil);

    ///<summary>Reenvia item PENDENTE de QUITACAO/CANCELAMENTO. Falha esperada
    /// de integracao vira resultado tipado, nunca excecao.</summary>
    function Reenviar(AFilaId, AVendaId: Integer; ATipo: TTipoFila): TResultadoReenvio;
  end;

implementation

const
  MsgItemInvalido = 'Este item não está pendente ou não pertence à venda informada.';
  MsgFalhaLocal = 'Não foi possível concluir o item localmente; ele segue ' +
    'pendente e será reconciliado no próximo reenvio';

function TResultadoReenvio.Concluiu: Boolean;
begin
  Result := Desfecho = rrConcluido;
end;

constructor TFilaService.Create(const AVendaRepositorio: IVendaRepository;
  const AFinanceiro: IFinanceiroGateway; const AFilaRepositorio: IFilaRepository;
  const AClienteRepositorio: IClienteRepository;
  const ARelatorio: IRelatorioPedido; const AEmailSender: IEmailSender;
  AQuitacao: TQuitacaoService; ALogger: TLogger);
begin
  inherited Create;
  FQuitacao := AQuitacao;
  FLogger := ALogger;
  FClienteRepositorio := AClienteRepositorio;
  FRelatorio := ARelatorio;
  FEmailSender := AEmailSender;
  FVendaRepositorio := AVendaRepositorio;
  FFinanceiro := AFinanceiro;
  FFilaRepositorio := AFilaRepositorio;
end;

function TFilaService.Falha(AFilaId: Integer; const AMensagem: string): TResultadoReenvio;
var
  Msg: string;
begin
  // RF13-04: texto do Financeiro/excecoes e mascarado (CPF/e-mail) antes de ir
  // para RegistrarFalha e para a UI (mesma variavel; idempotente).
  Msg := TLogger.MascararSensiveis(Trim(AMensagem));
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
  // RF13-02: transicao Pendente->Quitada feita AGORA no reenvio => pos-quitacao
  // (PDF + e-mail; falha => item EMAIL na fila) uma vez, como na T49. Nunca
  // reposta o Financeiro nem altera o desfecho (rrConcluido) se o pos falhar.
  if (AAlvo = svQuitada) and (FQuitacao <> nil) then
  begin
    try
      case FQuitacao.ExecutarPosQuitacao(AVendaId) of
        eqEnviado: Result.Mensagem := 'Quitação concluída; e-mail enviado';
        eqFalhou: Result.Mensagem := 'Quitação concluída; e-mail pendente na fila';
        eqFalhouSemFila: Result.Mensagem := 'Quitação concluída; não foi possível ' +
          'enviar o e-mail nem registrá-lo na fila';
      end;
    except
      // best-effort: a quitacao ja esta concluida
    end;
  end;
end;

function TFilaService.ReenviarEmail(AFilaId, AVendaId: Integer): TResultadoReenvio;
var
  Venda: TVenda;
  Cliente: TCliente;
  Destino, Erro, Pdf: string;
  Env: TResultadoEnvioEmail;
  Enviado: Boolean;
begin
  // T51 (RF-22/23, ADR-005/006/007): a venda ja esta Quitada; status nunca muda.
  // PDF regenerado do banco (nao persiste), sem transacao aberta (PDF/SMTP).
  // Nada de log/mensagem com e-mail ou dado pessoal. PDF apagado sempre.
  Enviado := False;
  Erro := '';
  Destino := '';
  Pdf := '';
  Venda := nil;
  Cliente := nil;
  try
    try
      Venda := FVendaRepositorio.Obter(AVendaId);
      if Venda = nil then
        Erro := 'Venda não encontrada'
      else if Venda.Status <> svQuitada then
        Erro := 'A venda não está quitada; e-mail de confirmação não reenviado'
      else
      begin
        Cliente := FClienteRepositorio.Obter(Venda.ClienteId);
        if Cliente <> nil then
          Destino := Trim(Cliente.Email);
        if Destino = '' then
          Erro := 'Cliente sem e-mail cadastrado'
        else
        begin
          // RF13-05: se GerarPdf falhar, ele mesmo apaga o PDF parcial (RF11-02)
          // e LimparAntigos varre residuos > 24 h; Pdf so e atribuido no sucesso.
          Pdf := FRelatorio.GerarPdf(Venda);
          Env := FEmailSender.Enviar(Destino,
            Format('Confirmação de Pedido %d', [AVendaId]),
            Format('Segue em anexo a confirmação do pedido %d.', [AVendaId]), Pdf);
          Enviado := Env.Sucesso;
          if not Enviado then
            Erro := Env.MensagemErro;
        end;
      end;
    except
      on E: Exception do
      begin
        Enviado := False;
        Erro := 'Falha ao gerar/enviar e-mail: ' + E.ClassName;
      end;
    end;
  finally
    Cliente.Free;
    Venda.Free;
  end;

  if Pdf <> '' then
    try
      FRelatorio.Limpar(Pdf);
    except
      // limpeza best-effort
    end;

  if not Enviado then
    Exit(Falha(AFilaId, Erro));

  try
    FFilaRepositorio.MarcarConcluido(AFilaId);
  except
    on EInfra do
      Exit(Falha(AFilaId, MsgFalhaLocal));
  end;
  Result.Desfecho := rrConcluido;
  Result.Mensagem := '';
end;

procedure TFilaService.Registrar(AFilaId, AVendaId: Integer; ATipo: TTipoFila;
  ADesfecho: TDesfechoReenvio);
const
  Nomes: array[TDesfechoReenvio] of string =
    ('rrConcluido', 'rrFalha', 'rrNaoSuportado');
begin
  // RF13-05: so Ids, tipo e desfecho (sem e-mail/CPF/mensagem de erro).
  if FLogger = nil then
    Exit;
  try
    FLogger.Info(Format('Reenvio fila %d venda %d tipo %s: %s',
      [AFilaId, AVendaId, TipoFilaToStr(ATipo), Nomes[ADesfecho]]));
  except
    // log best-effort
  end;
end;

function TFilaService.Reenviar(AFilaId, AVendaId: Integer;
  ATipo: TTipoFila): TResultadoReenvio;
begin
  Result := ReenviarInterno(AFilaId, AVendaId, ATipo);
  Registrar(AFilaId, AVendaId, ATipo, Result.Desfecho);
end;

function TFilaService.ReenviarInterno(AFilaId, AVendaId: Integer;
  ATipo: TTipoFila): TResultadoReenvio;
var
  Venda: TVenda;
  StatusLocal, Alvo, Oposto: TStatusVenda;
  Resp: TResultadoFinanceiro;
  Data: TDateTime;
  ItemVendaId: Integer;
  ItemTipo: TTipoFila;
  ItemPendente: Boolean;
begin
  // RF13-01 (SG13-02): nao confia no chamador; o item precisa existir, estar
  // PENDENTE e pertencer a (AVendaId, ATipo). Recusa sem tocar em nada
  // (sem RegistrarFalha, sem HTTP, sem e-mail).
  try
    if not FFilaRepositorio.ObterItem(AFilaId, ItemVendaId, ItemTipo, ItemPendente)
      or not ItemPendente or (ItemVendaId <> AVendaId) or (ItemTipo <> ATipo) then
    begin
      Result.Desfecho := rrFalha;
      Result.Mensagem := MsgItemInvalido;
      Exit;
    end;
  except
    on EInfra do
    begin
      Result.Desfecho := rrFalha;
      Result.Mensagem := MsgFalhaLocal;
      Exit;
    end;
  end;

  if ATipo = tfEmail then
    Exit(ReenviarEmail(AFilaId, AVendaId));
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

  try
    Venda := FVendaRepositorio.Obter(AVendaId);
  except
    on EInfra do
      Exit(Falha(AFilaId, MsgFalhaLocal)); // RF13-06: banco indisponivel
  end;
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
    try
      Venda := FVendaRepositorio.Obter(AVendaId);
    except
      on EInfra do
        Exit(Falha(AFilaId, MsgFalhaLocal)); // RF13-06
    end;
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
