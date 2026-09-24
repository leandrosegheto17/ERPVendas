unit ERPV.Negocio.QuitacaoService;

{
  T43 - QuitacaoService.Cancelar (RF-16/17, RN-02/08, ADR-005/006).
  Camada Negocio: so depende de interfaces do Dominio. T38 acrescenta
  Confirmar nesta mesma classe (mesmas dependencias, sem retrabalho).

  Fluxo de Cancelar(AVendaId, AMotivo):
   1. Le a venda do banco (o status do chamador nao e confiavel). Nao
      encontrada ou nao Pendente => dcNaoPermitida, SEM POST (RN-02).
   2. POST de cancelamento via IFinanceiroGateway - fora de qualquer
      transacao (ADR-006: nada de transacao aberta durante HTTP).
   3. Desfecho:
      - Sucesso com Status Cancelada => commit curto (AtualizarStatus) de
        status + motivo => dcCancelada.
      - Recusado (4xx)        => venda continua Pendente, NADA na fila,
        devolve a mensagem do Financeiro => dcRecusada (RN-08).
      - Indisponivel (5xx/timeout/rede) => venda continua Pendente e
        enfileira CANCELAMENTO com o erro em ULTIMO_ERRO => dcEnfileirada.
      - Resposta invalida (200 ilegivel ou status diferente de Cancelada)
        => Pendente, nao enfileira (estado no Financeiro incerto; o
        reenvio com reconciliacao por GET status e T50) => dcRespostaInvalida.
   Falha esperada vira resultado tipado, nunca excecao.

  Motivo: opcional; espacos nas pontas removidos; '' = nao enviar.
  Se AtualizarStatus falhar depois do POST ok, a excecao de infra sobe
  (inesperada, ADR-008) e a venda segue Pendente localmente; a
  reconciliacao (T41/T50) resolve.

  ==========================================================================
  ROTEIRO MANUAL (sem Delphi na automacao; DEC-14: sem testes automatizados)
  ==========================================================================
  Pre-requisitos: banco de T03, erpvendas.ini valido, mock:
  python tools/mock-financeiro/mock_financeiro.py (porta 8101). Usar botao
  temporario ou projeto de teste com
  TQuitacaoService.Create(Root.VendaRepository, Gateway, Root.FilaRepository).
  1. Mock ok + venda Pendente: Cancelar(Id, 'Cliente desistiu') =>
     dcCancelada; no banco STATUS='Cancelada' e motivo gravado.
  2. Mock modo recusa: venda continua Pendente, tabela de fila sem linha,
     Mensagem preenchida => dcRecusada.
  3. Mock erro500 (ou timeout): venda Pendente, 1 linha CANCELAMENTO
     PENDENTE com ULTIMO_ERRO => dcEnfileirada; repetir = tentativas 2.
  4. Venda Quitada (ou Cancelada): dcNaoPermitida e o mock NAO recebe POST
     (conferir no log do mock).
  Compilacao/execucao real pendente de confirmacao do usuario na IDE.
}

interface

uses
  System.SysUtils,
  ERPV.Dominio.Enums,
  ERPV.Dominio.Venda,
  ERPV.Dominio.Resultados,
  ERPV.Dominio.Contratos.IVendaRepository,
  ERPV.Dominio.Contratos.IFinanceiroGateway,
  ERPV.Dominio.Contratos.IFilaRepository;

type
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

  TQuitacaoService = class
  private
    FVendaRepositorio: IVendaRepository;
    FFinanceiro: IFinanceiroGateway;
    FFilaRepositorio: IFilaRepository;
    class function Resultado(ADesfecho: TDesfechoCancelamento;
      const AMensagem: string = ''): TResultadoCancelamento; static;
  public
    constructor Create(const AVendaRepositorio: IVendaRepository;
      const AFinanceiro: IFinanceiroGateway; const AFilaRepositorio: IFilaRepository);

    /// <summary>Cancela venda Pendente no Financeiro e localmente (T43).
    /// AMotivo opcional. Sem excecao para falha esperada de integracao.</summary>
    function Cancelar(AVendaId: Integer; const AMotivo: string): TResultadoCancelamento;
  end;

implementation

{ TResultadoCancelamento }

function TResultadoCancelamento.Cancelou: Boolean;
begin
  Result := Desfecho = dcCancelada;
end;

{ TQuitacaoService }

constructor TQuitacaoService.Create(const AVendaRepositorio: IVendaRepository;
  const AFinanceiro: IFinanceiroGateway; const AFilaRepositorio: IFilaRepository);
begin
  inherited Create;
  FVendaRepositorio := AVendaRepositorio;
  FFinanceiro := AFinanceiro;
  FFilaRepositorio := AFilaRepositorio;
end;

class function TQuitacaoService.Resultado(ADesfecho: TDesfechoCancelamento;
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
    Exit(Resultado(dcNaoPermitida, 'Venda não encontrada'));
  try
    StatusAtual := Venda.Status;
  finally
    Venda.Free;
  end;

  if StatusAtual = svQuitada then
    Exit(Resultado(dcNaoPermitida, 'Venda já quitada não pode ser cancelada'));
  if StatusAtual = svCancelada then
    Exit(Resultado(dcNaoPermitida, 'Venda já está cancelada'));

  Motivo := Trim(AMotivo);

  // HTTP fora de transacao (ADR-006).
  Resp := FFinanceiro.ConfirmarCancelamento(AVendaId, Motivo);

  case Resp.Categoria of
    rfSucesso:
      if Resp.Status = svCancelada then
      begin
        FVendaRepositorio.AtualizarStatus(AVendaId, svCancelada, 0, Motivo);
        Result := Resultado(dcCancelada);
      end
      else
        Result := Resultado(dcRespostaInvalida,
          'O Financeiro respondeu com um status inesperado para o cancelamento');
    rfRecusado:
      Result := Resultado(dcRecusada, Resp.Mensagem);
    rfIndisponivel:
      begin
        FFilaRepositorio.Enfileirar(AVendaId, tfCancelamento, Resp.Mensagem);
        Result := Resultado(dcEnfileirada, Resp.Mensagem);
      end;
  else
    Result := Resultado(dcRespostaInvalida, Resp.Mensagem);
  end;
end;

end.
