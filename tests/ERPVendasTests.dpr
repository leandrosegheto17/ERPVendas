program ERPVendasTests;
{$APPTYPE CONSOLE}
uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.TestRunner,
  ERPV.Testes.FilaService in 'ERPV.Testes.FilaService.pas',
  ERPV.Testes.FinanceiroClientErros in 'ERPV.Testes.FinanceiroClientErros.pas',
  ERPV.Testes.PendenciaFila in 'ERPV.Testes.PendenciaFila.pas',
  ERPV.Testes.PendenciasApresentacao in 'ERPV.Testes.PendenciasApresentacao.pas',
  ERPV.Testes.Formatacao in 'ERPV.Testes.Formatacao.pas',
  ERPV.Testes.ConfigApiKey in 'ERPV.Testes.ConfigApiKey.pas';

var
  LRunner: ITestRunner;
  LResults: IRunResults;
begin
  LRunner := TDUnitX.CreateRunner;
  LRunner.AddLogger(TDUnitXConsoleLogger.Create(True));
  LResults := LRunner.Execute;
  {$IFDEF DEBUG} Readln; {$ENDIF}
end.

