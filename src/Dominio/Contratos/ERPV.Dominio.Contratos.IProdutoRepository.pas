unit ERPV.Dominio.Contratos.IProdutoRepository;

{
  Interface de fronteira do Domínio (ADR-010) — só assinaturas; a
  implementação FireDAC é ProdutoRepository (T21). Unit pura, sem
  Vcl/FireDAC/System.Net/Id*; TDataSet (Data.DB) é a única exceção,
  conforme ADR-010.
}

interface

uses
  Data.DB,
  ERPV.Dominio.Produto;

type
  IProdutoRepository = interface
    ['{7B2C3D21-0F4D-4C6B-A01B-2E3F4A5B6C7D}']

    /// <summary>Grava um novo produto e devolve o Id gerado.</summary>
    function Incluir(const AProduto: TProduto): Integer;

    /// <summary>Grava as alterações de um produto já existente (AProduto.Id > 0).</summary>
    procedure Alterar(const AProduto: TProduto);

    /// <summary>Exclusão física — a regra "excluir = inativar quando há
    /// venda" (RN-05, T30) é do Service, não do repositório.</summary>
    procedure Excluir(AId: Integer);

    /// <summary>Devolve o produto pelo Id, ou nil se não encontrado.</summary>
    function Obter(AId: Integer): TProduto;

    /// <summary>DataSet somente leitura para a grade de lista (T23), com
    /// busca textual e filtro de inativos.</summary>
    function ListarDataSet(const AFiltroBusca: string; AIncluirInativos: Boolean): TDataSet;
  end;

implementation

end.
