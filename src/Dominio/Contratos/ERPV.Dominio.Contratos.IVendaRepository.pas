unit ERPV.Dominio.Contratos.IVendaRepository;

{
  Interface de fronteira do Domínio (ADR-010) — só assinaturas; a
  implementação FireDAC é VendaRepository (T25/T26). Unit pura, sem
  Vcl/FireDAC/System.Net/Id*; TDataSet (Data.DB) é a única exceção,
  conforme ADR-010.

  Incluir/Alterar/Excluir tratam mestre+itens numa única transação
  (inseparável, T25); AtualizarStatus é usado pelo fluxo de
  quitação/cancelamento (ADR-006) para o commit curto de status,
  fora da chamada HTTP.
}

interface

uses
  Data.DB,
  ERPV.Dominio.Venda,
  ERPV.Dominio.Enums;

type
  IVendaRepository = interface
    ['{8C3D4E32-1A5E-4D7C-B12C-3F4A5B6C7D8E}']

    /// <summary>Grava a venda (mestre + itens) numa única transação e
    /// devolve o Id gerado. Erro em qualquer item faz rollback do
    /// mestre.</summary>
    function Incluir(const AVenda: TVenda): Integer;

    /// <summary>Regrava mestre + itens (mesma transação); só chamado
    /// pelo Service quando a venda ainda está Pendente (RN-02, T29).</summary>
    procedure Alterar(const AVenda: TVenda);

    /// <summary>Exclui itens e depois o mestre; só chamado pelo Service
    /// quando a venda ainda está Pendente (RN-02, T29).</summary>
    procedure Excluir(AId: Integer);

    /// <summary>Devolve a venda (com itens) pelo Id, ou nil se não
    /// encontrada.</summary>
    function Obter(AId: Integer): TVenda;

    /// <summary>Commit curto e isolado de status/dataQuitacao/motivo,
    /// fora de qualquer transação que envolva chamada HTTP (ADR-006).</summary>
    procedure AtualizarStatus(AId: Integer; AStatus: TStatusVenda; ADataQuitacao: TDateTime;
      const AMotivoCancelamento: string);

    /// <summary>DataSet somente leitura para a grade de lista (T31), já
    /// com nome do cliente e total; AStatusFiltro/AClienteIdFiltro vazios
    /// ou 0 significam "sem filtro" naquele critério.</summary>
    function ListarDataSet(const AStatusFiltro: string; AClienteIdFiltro: Integer): TDataSet;

    /// <summary>Usado por T30 (excluir cliente = inativar quando há
    /// venda).</summary>
    function ExisteVendaPorCliente(AClienteId: Integer): Boolean;

    /// <summary>Usado por T30 (excluir produto = inativar quando há
    /// venda).</summary>
    function ExisteVendaPorProduto(AProdutoId: Integer): Boolean;
  end;

implementation

end.
