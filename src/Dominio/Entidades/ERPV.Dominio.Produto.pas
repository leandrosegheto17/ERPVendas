unit ERPV.Dominio.Produto;

{
  Entidade de Domínio TProduto (T08, Lote 2). Campos batendo com
  db/01_schema.sql (tabela PRODUTOS, criada em T03). Unit pura, sem
  Vcl/FireDAC/System.Net/Id* (ADR-001/010). Preço unitário em Currency —
  nunca Double/Extended (TASK.md Seção 1 "Dados").
}

interface

type
  TProduto = class
  private
    FId: Integer;
    FDescricao: string;
    FUnidade: string;
    FPrecoUnitario: Currency;
    FCategoria: string;
    FAtivo: Boolean;
  public
    constructor Create;

    property Id: Integer read FId write FId;
    property Descricao: string read FDescricao write FDescricao;
    property Unidade: string read FUnidade write FUnidade;
    property PrecoUnitario: Currency read FPrecoUnitario write FPrecoUnitario;
    property Categoria: string read FCategoria write FCategoria;
    property Ativo: Boolean read FAtivo write FAtivo;
  end;

implementation

constructor TProduto.Create;
begin
  inherited Create;
  FAtivo := True;
  FPrecoUnitario := 0;
end;

end.
