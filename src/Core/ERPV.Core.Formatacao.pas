unit ERPV.Core.Formatacao;

(*
  RF11-08 - Formatacao pt-BR pura, independente do locale do Windows.
  Usa um TFormatSettings fixo (nunca o FormatSettings global), para que o PDF
  do pedido saia igual em qualquer maquina: 1.234,56 e dd/mm/yyyy hh:nn.
*)

interface

function FormatarMoedaPtBR(AValor: Currency): string;
function FormatarDataHoraPtBR(AValor: TDateTime): string;

implementation

uses
  System.SysUtils;

function ConfigPtBR: TFormatSettings;
begin
  Result := TFormatSettings.Create('en-US'); // base neutra; tudo abaixo e sobrescrito
  Result.DecimalSeparator := ',';
  Result.ThousandSeparator := '.';
  Result.DateSeparator := '/';
  Result.TimeSeparator := ':';
  Result.ShortDateFormat := 'dd/mm/yyyy';
  Result.ShortTimeFormat := 'hh:nn';
end;

function FormatarMoedaPtBR(AValor: Currency): string;
begin
  Result := FormatFloat('#,##0.00', AValor, ConfigPtBR);
end;

function FormatarDataHoraPtBR(AValor: TDateTime): string;
begin
  Result := FormatDateTime('dd/mm/yyyy hh:nn', AValor, ConfigPtBR);
end;

end.
