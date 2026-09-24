unit ERPV.Integracao.FinanceiroDTOs;

{
  DTOs + serializacao/desserializacao JSON do contrato Vendas x Financeiro
  (T33, Lote 8; RNF-05, ADR-004). Fonte unica do formato:
  docs/contrato-api-financeiro.md v1.0.

  Regras (contrato secao 1.4):
   - TFormatSettings invariante ('.' decimal, sem separador de milhar),
     independente do locale pt-BR do SO. Nunca usa o FormatSettings global.
   - valorTotal/precoUnitario: numero JSON com ponto e 2 casas (ex.: 350.90),
     montado por TJSONNumber.Create(string) para preservar o texto exato.
   - vendaId/clienteId/produtoId: string JSON contendo o id inteiro.
   - Datas ISO 8601 sem timezone (AAAA-MM-DDThh:mm:ss), sem conversao de fuso.
   - Cliente tolerante a v1.0: resposta de quitacao sem vendaId e sem corpo
     de erro; campos desconhecidos sao ignorados; qualquer falha de parse
     devolve False (o cliente HTTP, T34-T36, mapeia para RespostaInvalida).

  Depende so de Dominio (TVenda, TVendaItem, TStatusVenda) + System.JSON.
  Nao usa Vcl/FireDAC/System.Net. Delphi 10.3+ (sem inline var).

  ROTEIRO MANUAL DE VERIFICACAO (Delphi Community nao compila via CLI):
   1. Adicionar a unit ao projeto (src\Integracao ja esta no
      DCC_UnitSearchPath) e compilar (Shift+F9): esperado 0 erros.
   2. Com locale pt-BR ativo, chamar SerializarQuitacaoRequest com venda
      Id=1042, ClienteId=17, ValorTotal=350.90, itens (3, 2, 120.00) e
      (8, 1, 110.90). Esperado:
      {"vendaId":"1042","clienteId":"17","valorTotal":350.90,"itens":[
      {"produtoId":"3","quantidade":2,"precoUnitario":120.00},
      {"produtoId":"8","quantidade":1,"precoUnitario":110.90}]}
      (ponto decimal, 2 casas, ids entre aspas).
   3. TryParseQuitacaoResponse('{"status":"Quitada","dataQuitacao":
      "2026-09-22T14:35:12"}', R): True, R.Status = svQuitada,
      FormatDateTime('dd/mm/yyyy hh:nn:ss', R.DataQuitacao) =
      '22/09/2026 14:35:12' (com pt-BR ativo).
   4. Casos False: '' ; 'nao json' ; '{"status":"Quitada"}' (sem data);
      '{"status":"Xpto"}'. Caso True tolerante: '{"status":"Quitada",
      "dataQuitacao":"2026-09-22T14:35:12","extra":1}'.
   5. SerializarCancelamentoRequest(1042, '') nao deve conter "motivo".
   6. TryParseStatusResponse('{"vendaId":"1042","status":"Quitada"}') e sem
      vendaId: ambos True.
}

interface

uses
  System.SysUtils,
  ERPV.Dominio.Enums,
  ERPV.Dominio.Venda;

type
  /// <summary>Resposta de POST /api/vendas/quitacao (200).</summary>
  TQuitacaoResponseDTO = record
    Status: TStatusVenda;
    /// <summary>0 quando o campo veio ausente (so permitido se Status
    /// nao for Quitada).</summary>
    DataQuitacao: TDateTime;
  end;

  /// <summary>Resposta de POST /api/vendas/cancelamento (200).</summary>
  TCancelamentoResponseDTO = record
    Status: TStatusVenda;
  end;

  /// <summary>Resposta de GET /api/vendas/{id}/status (200).</summary>
  TStatusResponseDTO = record
    /// <summary>0 se o servidor nao devolveu vendaId (tolerado).</summary>
    VendaId: Integer;
    Status: TStatusVenda;
  end;

/// <summary>FormatSettings invariante usado em toda (de)serializacao.</summary>
function FinanceiroFormatSettings: TFormatSettings;

/// <summary>Currency -> texto com ponto e 2 casas (ex.: '350.90').</summary>
function CurrencyToJsonNumber(AValor: Currency): string;

/// <summary>TDateTime -> 'AAAA-MM-DDThh:mm:ss' (sem timezone).</summary>
function DateTimeToIso(AValor: TDateTime): string;

/// <summary>ISO 8601 -> TDateTime, independente de locale. False se
/// invalido.</summary>
function TryIsoToDateTime(const AValor: string; out ADataHora: TDateTime): Boolean;

function SerializarQuitacaoRequest(const AVenda: TVenda): string;
function SerializarCancelamentoRequest(AVendaId: Integer; const AMotivo: string): string;

function TryParseQuitacaoResponse(const AJson: string; out ADto: TQuitacaoResponseDTO): Boolean;
function TryParseCancelamentoResponse(const AJson: string; out ADto: TCancelamentoResponseDTO): Boolean;
function TryParseStatusResponse(const AJson: string; out ADto: TStatusResponseDTO): Boolean;

implementation

uses
  System.DateUtils,
  System.JSON,
  ERPV.Dominio.VendaItem;

function FinanceiroFormatSettings: TFormatSettings;
begin
  Result := TFormatSettings.Create('en-US');
  Result.DecimalSeparator := '.';
  Result.ThousandSeparator := ',';
  Result.DateSeparator := '-';
  Result.TimeSeparator := ':';
  Result.ShortDateFormat := 'yyyy-mm-dd';
  Result.LongTimeFormat := 'hh:nn:ss';
end;

function CurrencyToJsonNumber(AValor: Currency): string;
begin
  // ffFixed: sem agrupamento de milhar; 2 casas; ponto do FS invariante.
  Result := CurrToStrF(AValor, ffFixed, 2, FinanceiroFormatSettings);
end;

function DateTimeToIso(AValor: TDateTime): string;
begin
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss', AValor, FinanceiroFormatSettings);
end;

function TryIsoToDateTime(const AValor: string; out ADataHora: TDateTime): Boolean;
begin
  Result := False;
  ADataHora := 0;
  if Trim(AValor) = '' then
    Exit;
  try
    // ISO8601ToDate nao depende de locale; False = nao converte para UTC
    // (contrato: sem timezone, sem conversao de fuso).
    ADataHora := ISO8601ToDate(Trim(AValor), False);
    Result := True;
  except
    on EConvertError do
      Result := False;
  end;
end;

function SerializarQuitacaoRequest(const AVenda: TVenda): string;
var
  LRoot, LItemObj: TJSONObject;
  LItens: TJSONArray;
  LItem: TVendaItem;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('vendaId', TJSONString.Create(IntToStr(AVenda.Id)));
    LRoot.AddPair('clienteId', TJSONString.Create(IntToStr(AVenda.ClienteId)));
    LRoot.AddPair('valorTotal', TJSONNumber.Create(CurrencyToJsonNumber(AVenda.ValorTotal)));
    LItens := TJSONArray.Create;
    LRoot.AddPair('itens', LItens);
    for LItem in AVenda.Itens do
    begin
      LItemObj := TJSONObject.Create;
      LItemObj.AddPair('produtoId', TJSONString.Create(IntToStr(LItem.ProdutoId)));
      LItemObj.AddPair('quantidade', TJSONNumber.Create(LItem.Quantidade));
      LItemObj.AddPair('precoUnitario', TJSONNumber.Create(CurrencyToJsonNumber(LItem.PrecoUnitario)));
      LItens.AddElement(LItemObj);
    end;
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function SerializarCancelamentoRequest(AVendaId: Integer; const AMotivo: string): string;
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('vendaId', TJSONString.Create(IntToStr(AVendaId)));
    if Trim(AMotivo) <> '' then
      LRoot.AddPair('motivo', TJSONString.Create(AMotivo));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

// Le um campo string do objeto; False se ausente ou nao-string.
function TryGetString(AObj: TJSONObject; const ANome: string; out AValor: string): Boolean;
var
  LVal: TJSONValue;
begin
  LVal := AObj.GetValue(ANome);
  Result := (LVal <> nil) and (LVal is TJSONString);
  if Result then
    AValor := TJSONString(LVal).Value
  else
    AValor := '';
end;

// Parse tolerante: devolve o objeto raiz (dono = chamador) ou nil.
function ParseObjeto(const AJson: string): TJSONObject;
var
  LVal: TJSONValue;
begin
  Result := nil;
  if Trim(AJson) = '' then
    Exit;
  LVal := nil;
  try
    LVal := TJSONObject.ParseJSONValue(AJson);
  except
    LVal := nil;
  end;
  if LVal is TJSONObject then
    Result := TJSONObject(LVal)
  else
    LVal.Free; // Free em nil e seguro
end;

function TryParseQuitacaoResponse(const AJson: string; out ADto: TQuitacaoResponseDTO): Boolean;
var
  LObj: TJSONObject;
  LStatus, LData: string;
  LTemData: Boolean;
begin
  Result := False;
  ADto.Status := svPendente;
  ADto.DataQuitacao := 0;
  LObj := ParseObjeto(AJson);
  if LObj = nil then
    Exit;
  try
    if not TryGetString(LObj, 'status', LStatus) then
      Exit;
    if not TryStrToStatusVenda(LStatus, ADto.Status) then
      Exit;
    LTemData := TryGetString(LObj, 'dataQuitacao', LData);
    if LTemData then
      LTemData := TryIsoToDateTime(LData, ADto.DataQuitacao);
    // Quitada exige dataQuitacao valida (contrato 1.5: campo obrigatorio).
    if (ADto.Status = svQuitada) and not LTemData then
      Exit;
    Result := True;
  finally
    LObj.Free;
  end;
end;

function TryParseCancelamentoResponse(const AJson: string; out ADto: TCancelamentoResponseDTO): Boolean;
var
  LObj: TJSONObject;
  LStatus: string;
begin
  Result := False;
  ADto.Status := svPendente;
  LObj := ParseObjeto(AJson);
  if LObj = nil then
    Exit;
  try
    Result := TryGetString(LObj, 'status', LStatus) and TryStrToStatusVenda(LStatus, ADto.Status);
  finally
    LObj.Free;
  end;
end;

function TryParseStatusResponse(const AJson: string; out ADto: TStatusResponseDTO): Boolean;
var
  LObj: TJSONObject;
  LStatus, LId: string;
begin
  Result := False;
  ADto.Status := svPendente;
  ADto.VendaId := 0;
  LObj := ParseObjeto(AJson);
  if LObj = nil then
    Exit;
  try
    if not (TryGetString(LObj, 'status', LStatus) and TryStrToStatusVenda(LStatus, ADto.Status)) then
      Exit;
    // vendaId opcional/tolerante: ausente ou invalido nao invalida a resposta.
    if TryGetString(LObj, 'vendaId', LId) then
      ADto.VendaId := StrToIntDef(LId, 0);
    Result := True;
  finally
    LObj.Free;
  end;
end;

end.
