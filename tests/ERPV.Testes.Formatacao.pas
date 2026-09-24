unit ERPV.Testes.Formatacao;

(*
  RF11-08 - testes DUnitX da formatacao pt-BR. Nao compilado (sem CLI);
  rodar na IDE no projeto de testes.
*)

interface

uses
  System.SysUtils, DUnitX.TestFramework, ERPV.Core.Formatacao;

type
  [TestFixture]
  TTestesFormatacao = class
  public
    [Test] procedure Moeda_MilharEDecimal;
    [Test] procedure Moeda_Zero;
    [Test] procedure DataHora_Formato;
    [Test] procedure Independe_DoLocaleGlobal;
  end;

implementation

procedure TTestesFormatacao.Moeda_MilharEDecimal;
begin
  Assert.AreEqual('1.234,56', FormatarMoedaPtBR(1234.56));
end;

procedure TTestesFormatacao.Moeda_Zero;
begin
  Assert.AreEqual('0,00', FormatarMoedaPtBR(0));
end;

procedure TTestesFormatacao.DataHora_Formato;
begin
  Assert.AreEqual('05/03/2026 14:07',
    FormatarDataHoraPtBR(EncodeDate(2026, 3, 5) + EncodeTime(14, 7, 0, 0)));
end;

procedure TTestesFormatacao.Independe_DoLocaleGlobal;
var
  Original: TFormatSettings;
begin
  Original := FormatSettings;
  try
    FormatSettings.DecimalSeparator := '.';
    FormatSettings.ThousandSeparator := ',';
    FormatSettings.DateSeparator := '-';
    FormatSettings.TimeSeparator := '.';
    FormatSettings.ShortDateFormat := 'mm/dd/yyyy';
    Assert.AreEqual('1.234,56', FormatarMoedaPtBR(1234.56));
    Assert.AreEqual('05/03/2026 14:07',
      FormatarDataHoraPtBR(EncodeDate(2026, 3, 5) + EncodeTime(14, 7, 0, 0)));
  finally
    FormatSettings := Original;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestesFormatacao);

end.
