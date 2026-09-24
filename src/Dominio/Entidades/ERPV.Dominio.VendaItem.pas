unit ERPV.Dominio.VendaItem;

(*
  Entidade de Domínio TVendaItem (T08, Lote 2). Campos batendo com
  db/01_schema.sql (tabela VENDA_ITENS, criada em T03). Unit pura, sem
  Vcl/FireDAC/System.Net/Id* (ADR-001/010).

  PrecoUnitario é o snapshot do preço do produto no momento da venda
  (RN-04, T28): mudar o preço do produto depois não altera itens já
  gravados. Subtotal é sempre calculado (Quantidade * PrecoUnitario),
  nunca um campo editável — espelha a coluna COMPUTED do banco.
*)

interface

type
  TVendaItem = class
  private
    FId: Integer;
    FVendaId: Integer;
    FProdutoId: Integer;
    FQuantidade: Integer;
    FPrecoUnitario: Currency;
    function GetSubtotal: Currency;
  public
    constructor Create;

    property Id: Integer read FId write FId;
    property VendaId: Integer read FVendaId write FVendaId;
    property ProdutoId: Integer read FProdutoId write FProdutoId;
    property Quantidade: Integer read FQuantidade write FQuantidade;
    /// <summary>Snapshot do preço do produto na data da venda.</summary>
    property PrecoUnitario: Currency read FPrecoUnitario write FPrecoUnitario;
    /// <summary>Calculado (Quantidade * PrecoUnitario); nunca atribuído
    /// diretamente (RN-04).</summary>
    property Subtotal: Currency read GetSubtotal;
  end;

implementation

constructor TVendaItem.Create;
begin
  inherited Create;
  FQuantidade := 0;
  FPrecoUnitario := 0;
end;

function TVendaItem.GetSubtotal: Currency;
begin
  Result := FQuantidade * FPrecoUnitario;
end;

end.
