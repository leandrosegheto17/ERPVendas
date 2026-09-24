unit ERPV.Dominio.Enums;

{
  Enums do Domínio (T08, Lote 2). Unit pura, sem Vcl/FireDAC/System.Net/Id*
  (ADR-001/010, TASK.md Seção 1 "Camadas e dependência").

  Literais de persistência/exibição exatamente iguais aos usados no banco
  (db/01_schema.sql, CK_VENDAS_STATUS / CK_FILA_TIPO) e no contrato de API
  (docs/contrato-api-financeiro.md): 'Pendente'/'Quitada'/'Cancelada' para
  status de venda e 'QUITACAO'/'CANCELAMENTO'/'EMAIL' para tipo de fila.
}

interface

uses
  System.SysUtils;

type
  TStatusVenda = (svPendente, svQuitada, svCancelada);

  TTipoFila = (tfQuitacao, tfCancelamento, tfEmail);

/// <summary>Converte o enum para o literal exato usado no banco/contrato.</summary>
function StatusVendaToStr(AStatus: TStatusVenda): string;

/// <summary>Converte o literal do banco/contrato para o enum. Lança
/// EArgumentException se o literal não for reconhecido.</summary>
function StrToStatusVenda(const AValor: string): TStatusVenda;

/// <summary>Idem StrToStatusVenda, mas devolve False em vez de lançar
/// exceção quando o literal não é reconhecido (uso em GET status, onde um
/// valor fora do enum vira RespostaInvalida em vez de travar o fluxo).</summary>
function TryStrToStatusVenda(const AValor: string; out AStatus: TStatusVenda): Boolean;

function TipoFilaToStr(ATipo: TTipoFila): string;
function StrToTipoFila(const AValor: string): TTipoFila;

implementation

const
  STATUS_VENDA_STR: array [TStatusVenda] of string = ('Pendente', 'Quitada', 'Cancelada');
  TIPO_FILA_STR: array [TTipoFila] of string = ('QUITACAO', 'CANCELAMENTO', 'EMAIL');

function StatusVendaToStr(AStatus: TStatusVenda): string;
begin
  Result := STATUS_VENDA_STR[AStatus];
end;

function TryStrToStatusVenda(const AValor: string; out AStatus: TStatusVenda): Boolean;
var
  LStatus: TStatusVenda;
begin
  Result := False;
  for LStatus := Low(TStatusVenda) to High(TStatusVenda) do
    if SameText(STATUS_VENDA_STR[LStatus], AValor) then
    begin
      AStatus := LStatus;
      Exit(True);
    end;
end;

function StrToStatusVenda(const AValor: string): TStatusVenda;
begin
  if not TryStrToStatusVenda(AValor, Result) then
    raise EArgumentException.CreateFmt('Status de venda desconhecido: "%s"', [AValor]);
end;

function TipoFilaToStr(ATipo: TTipoFila): string;
begin
  Result := TIPO_FILA_STR[ATipo];
end;

function StrToTipoFila(const AValor: string): TTipoFila;
var
  LTipo: TTipoFila;
begin
  for LTipo := Low(TTipoFila) to High(TTipoFila) do
    if SameText(TIPO_FILA_STR[LTipo], AValor) then
      Exit(LTipo);
  raise EArgumentException.CreateFmt('Tipo de fila desconhecido: "%s"', [AValor]);
end;

end.
