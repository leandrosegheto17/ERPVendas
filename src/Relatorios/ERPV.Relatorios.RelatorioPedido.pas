unit ERPV.Relatorios.RelatorioPedido;

(*
  T47 (Lote 11) - Implementacao de IRelatorioPedido sobre o layout T46
  (RF-20, ADR-007). Gera o PDF "Confirmacao de Pedido" na pasta temp
  configurada (INI, secao Relatorio, PastaPdfTemp) e devolve o caminho.

  - Dados: IVendaRepository.RelatorioDataSet(Id), liberado aqui em finally.
  - PDF: DeviceType := dtPDF + TextFileName (padrao confirmado em T67,
    docs/ambiente-licencas.md 3.2), sem dialogo e sem abrir o leitor.
  - Falha de escrita/geracao => EInfra amigavel (detalhe tecnico so no log).
  - Limpar remove apenas arquivos dentro da pasta temp configurada; falha
    ao remover vira aviso no log (nao interrompe o fluxo do e-mail).

  ROTEIRO T47 NA IDE (compilacao/execucao pendentes do usuario):
  1. Com venda existente: R := TRelatorioPedido.Create(Pasta, Repo, Logger);
     Caminho := R.GerarPdf(Venda); conferir que o arquivo existe, abre no
     leitor e traz os mesmos dados do banco (faixa Demo Copy e esperada).
  2. Pasta inexistente: e criada. Pasta sem permissao/invalida (ex.: Z:\x):
     GerarPdf levanta EInfra com mensagem amigavel; detalhe no log.
  3. R.Limpar(Caminho): arquivo some. Limpar de caminho inexistente ou fora
     da pasta temp: nao levanta excecao e nao apaga nada fora da pasta.
  4. Venda inexistente: EInfra amigavel, nenhum arquivo criado.
*)

interface

uses
  System.SysUtils,
  Data.DB,
  ppTypes,
  ERPV.Core.Log,
  ERPV.Core.Erros,
  ERPV.Dominio.Venda,
  ERPV.Dominio.Contratos.IVendaRepository,
  ERPV.Dominio.Contratos.IRelatorioPedido,
  ERPV.Relatorios.PedidoLayout;

type
  TRelatorioPedido = class(TInterfacedObject, IRelatorioPedido)
  private
    FPastaTemp: string;
    FVendaRepository: IVendaRepository;
    FLogger: TLogger;
    function DentroDaPastaTemp(const ACaminho: string): Boolean;
  public
    constructor Create(const APastaTemp: string;
      AVendaRepository: IVendaRepository; ALogger: TLogger);
    function GerarPdf(const AVenda: TVenda): string;
    procedure Limpar(const ACaminhoArquivo: string);
  end;

implementation

const
  MSG_FALHA_PDF = 'Não foi possível gerar o PDF do pedido. Tente novamente.';

constructor TRelatorioPedido.Create(const APastaTemp: string;
  AVendaRepository: IVendaRepository; ALogger: TLogger);
begin
  inherited Create;
  FPastaTemp := APastaTemp;
  FVendaRepository := AVendaRepository;
  FLogger := ALogger;
end;

function TRelatorioPedido.DentroDaPastaTemp(const ACaminho: string): Boolean;
var
  Pasta, Arquivo: string;
begin
  Pasta := IncludeTrailingPathDelimiter(ExpandFileName(FPastaTemp));
  Arquivo := ExpandFileName(ACaminho);
  Result := SameText(Copy(Arquivo, 1, Length(Pasta)), Pasta);
end;

function TRelatorioPedido.GerarPdf(const AVenda: TVenda): string;
var
  Dados: TDataSet;
  Layout: TDMPedidoLayout;
begin
  Result := IncludeTrailingPathDelimiter(FPastaTemp) +
    Format('Pedido_%d_%s.pdf', [AVenda.Id, FormatDateTime('yyyymmddhhnnsszzz', Now)]);
  try
    ForceDirectories(FPastaTemp);
    Dados := FVendaRepository.RelatorioDataSet(AVenda.Id);
    try
      if Dados.IsEmpty then
        raise EInfra.Create(MSG_FALHA_PDF);
      Layout := TDMPedidoLayout.Create(nil);
      try
        Layout.AtribuirDados(Dados);
        Layout.rptPedido.ShowPrintDialog := False;
        Layout.rptPedido.DeviceType := dtPDF;
        Layout.rptPedido.PDFSettings.OpenPDFFile := False;
        Layout.rptPedido.TextFileName := Result;
        Layout.rptPedido.Print;
      finally
        Layout.Free;
      end;
    finally
      Dados.Free;
    end;
    if not FileExists(Result) then
      raise EInfra.Create(MSG_FALHA_PDF);
  except
    on E: Exception do
    begin
      FLogger.Erro('Falha ao gerar PDF do pedido ' + IntToStr(AVenda.Id), E);
      if E is EInfra then
        raise;
      raise EInfra.Create(MSG_FALHA_PDF);
    end;
  end;
end;

procedure TRelatorioPedido.Limpar(const ACaminhoArquivo: string);
begin
  if (ACaminhoArquivo = '') or not FileExists(ACaminhoArquivo) then
    Exit;
  if not DentroDaPastaTemp(ACaminhoArquivo) then
  begin
    FLogger.Aviso('Limpeza de PDF ignorada: arquivo fora da pasta temp configurada.');
    Exit;
  end;
  if not DeleteFile(ACaminhoArquivo) then
    FLogger.Aviso('Não foi possível remover o PDF temporário: ' + ACaminhoArquivo);
end;

end.