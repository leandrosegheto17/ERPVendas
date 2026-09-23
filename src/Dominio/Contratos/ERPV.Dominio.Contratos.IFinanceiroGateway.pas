unit ERPV.Dominio.Contratos.IFinanceiroGateway;

{
  Interface de fronteira do Domínio (ADR-001/010) — só assinaturas; a
  implementação real (THTTPClient síncrono, System.JSON) é FinanceiroClient
  (T33-T36), fora do Domínio. Esta unit não referencia THTTPClient/
  System.Net/System.JSON — só o "formato de resultado" (TResultadoFinanceiro,
  ERPV.Dominio.Resultados), conforme ADR-004/010 e TASK.md Seção 1
  "Integração".
}

interface

uses
  ERPV.Dominio.Venda,
  ERPV.Dominio.Resultados;

type
  IFinanceiroGateway = interface
    ['{AE5F6A54-3C70-4F9E-D34E-5B6C7D8E9F0A}']

    /// <summary>POST /api/vendas/quitacao (T34). AVenda deve estar
    /// Pendente; a checagem é do Service (QuitacaoService, T38), não
    /// desta interface.</summary>
    function ConfirmarQuitacao(const AVenda: TVenda): TResultadoFinanceiro;

    /// <summary>POST /api/vendas/cancelamento (T35). AMotivo é opcional
    /// ('' = não enviar o campo, conforme contrato).</summary>
    function ConfirmarCancelamento(AVendaId: Integer; const AMotivo: string): TResultadoFinanceiro;

    /// <summary>GET /api/vendas/{id}/status (T36) — usado na
    /// reconciliação antes de reenviar um item QUITACAO/CANCELAMENTO
    /// pendente (T41/T50).</summary>
    function ConsultarStatus(AVendaId: Integer): TResultadoFinanceiro;
  end;

implementation

end.
