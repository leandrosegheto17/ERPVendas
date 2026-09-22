unit ERPV.Dominio.Venda;

{
  Entidade de Domínio TVenda (T08, Lote 2). Campos batendo com
  db/01_schema.sql (tabela VENDAS, criada em T03). Unit pura, sem
  Vcl/FireDAC/System.Net/Id* (ADR-001/010). ValorTotal em Currency — nunca
  Double/Extended (TASK.md Seção 1 "Dados"). Generics só TObjectList<T>
  padrão (TASK.md Seção 1 "Linguagem/versão").

  DataQuitacao/MotivoCancelamento não têm valor até a venda ser
  Quitada/Cancelada; sem framework de "nullable" de terceiros (proibido em
  Bibliotecas), o "não preenchido" é representado por 0 (TDateTime) / ''
  (string) e exposto via TemDataQuitacao/TemMotivoCancelamento.
}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  ERPV.Dominio.Enums,
  ERPV.Dominio.VendaItem;

type
  TVenda = class
  private
    FId: Integer;
    FClienteId: Integer;
    FDataVenda: TDateTime;
    FValorTotal: Currency;
    FStatus: TStatusVenda;
    FDataQuitacao: TDateTime;
    FMotivoCancelamento: string;
    FItens: TObjectList<TVendaItem>;
    function GetTemDataQuitacao: Boolean;
    function GetTemMotivoCancelamento: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    property Id: Integer read FId write FId;
    property ClienteId: Integer read FClienteId write FClienteId;
    property DataVenda: TDateTime read FDataVenda write FDataVenda;
    /// <summary>Sempre recalculado como Σ(qtd × preço) pelo Service
    /// (RN-04, T28) — nunca aceita valor digitado pela UI.</summary>
    property ValorTotal: Currency read FValorTotal write FValorTotal;
    property Status: TStatusVenda read FStatus write FStatus;
    property DataQuitacao: TDateTime read FDataQuitacao write FDataQuitacao;
    property TemDataQuitacao: Boolean read GetTemDataQuitacao;
    property MotivoCancelamento: string read FMotivoCancelamento write FMotivoCancelamento;
    property TemMotivoCancelamento: Boolean read GetTemMotivoCancelamento;
    property Itens: TObjectList<TVendaItem> read FItens;
  end;

implementation

constructor TVenda.Create;
begin
  inherited Create;
  FStatus := svPendente;
  FValorTotal := 0;
  FDataQuitacao := 0;
  FMotivoCancelamento := '';
  FItens := TObjectList<TVendaItem>.Create(True);
end;

destructor TVenda.Destroy;
begin
  FItens.Free;
  inherited Destroy;
end;

function TVenda.GetTemDataQuitacao: Boolean;
begin
  Result := FDataQuitacao <> 0;
end;

function TVenda.GetTemMotivoCancelamento: Boolean;
begin
  Result := FMotivoCancelamento <> '';
end;

end.
