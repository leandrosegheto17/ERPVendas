unit ERPV.Relatorios.RelatorioPedido;

(*
  T47 (Lote 11) - Implementacao de IRelatorioPedido sobre o layout T46
  (RF-20, ADR-007). Gera o PDF "Confirmacao de Pedido" na pasta temp
  configurada (INI, secao Relatorio, PastaPdfTemp) e devolve o caminho.

  - Dados: IVendaRepository.RelatorioDataSet(Id), liberado aqui em finally.
  - PDF: DeviceType := dtPDF + TextFileName (padrao confirmado em T67,
    docs/ambiente-licencas.md 3.2), sem dialogo e sem abrir o leitor.
  - Nome do arquivo: Pedido_<VendaId>_<GUID>.pdf (RF11-03; GUID nao
    previsivel, sem chaves). PastaPdfTemp exige ACL restrita (README 3.3).
  - Falha de escrita/geracao => EInfra amigavel (detalhe tecnico so no log).
  - Limpar remove apenas arquivos dentro da pasta temp configurada; falha
    ao remover vira aviso no log (nao interrompe o fluxo do e-mail).
  - Limite (SG11-03, RF11-06): Limpar/LimparAntigos nao seguem nem tratam
    symlink/junction dentro de PastaPdfTemp; a pasta deve ser local e
    controlada pelo usuario do app (ver ACL no README). O Config recusa
    caminho relativo, raiz de unidade e UNC.

  ROTEIRO T47 NA IDE (compilacao/execucao pendentes do usuario):
  1. Com venda existente: R := TRelatorioPedido.Create(Pasta, Repo, Logger);
     Caminho := R.GerarPdf(Venda); conferir que o arquivo existe, abre no
     leitor e traz os mesmos dados do banco (faixa Demo Copy e esperada).
  2. Pasta inexistente: e criada. Pasta sem permissao/invalida (ex.: Z:\x):
     GerarPdf levanta EInfra com mensagem amigavel; detalhe no log.
  3. R.Limpar(Caminho): arquivo some. Limpar de caminho inexistente ou fora
     da pasta temp: nao levanta excecao e nao apaga nada fora da pasta.
  4. Venda inexistente: EInfra amigavel, nenhum arquivo criado.

  RF11-01 (roteiro): GerarPdf(nil) => EInfra amigavel + log "venda nula", sem AV.

  ROTEIRO RF11-02 NA IDE (nao compilado):
  5. Simular falha no Print (ex.: forcar excecao apos criar o arquivo): a
     pasta temp nao deve conter o PDF parcial; erro no log; EInfra amigavel.
  6. Colocar na PastaPdfTemp um Pedido_x.pdf com data > 24 h (RETENCAO_PDF_HORAS),
     um Pedido_y.pdf recente e um outro.txt antigo; chamar GerarPdf: so o
     Pedido_x.pdf some, aviso "Limpeza de PDFs antigos" no log; nada fora da
     pasta e tocado. Arquivo travado: aviso no log, GerarPdf segue normal.
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
    procedure LimparAntigos;
    procedure LogAviso(const AMensagem: string);
    procedure LogErro(const AMensagem: string; AExcecao: Exception = nil);
  public
    constructor Create(const APastaTemp: string;
      AVendaRepository: IVendaRepository; ALogger: TLogger);
    function GerarPdf(const AVenda: TVenda): string;
    procedure Limpar(const ACaminhoArquivo: string);
  end;

implementation

const
  RETENCAO_PDF_HORAS = 24;
  MSG_FALHA_PDF = 'Não foi possível gerar o PDF do pedido. Tente novamente.';

constructor TRelatorioPedido.Create(const APastaTemp: string;
  AVendaRepository: IVendaRepository; ALogger: TLogger);
begin
  inherited Create;
  // RF11-01: repositorio obrigatorio; logger opcional (uso nil-safe)
  if AVendaRepository = nil then
    raise EInfra.Create(MSG_FALHA_PDF);
  FPastaTemp := APastaTemp;
  FVendaRepository := AVendaRepository;
  FLogger := ALogger;
end;

procedure TRelatorioPedido.LogAviso(const AMensagem: string);
begin
  if FLogger <> nil then
    FLogger.Aviso(AMensagem);
end;

procedure TRelatorioPedido.LogErro(const AMensagem: string; AExcecao: Exception);
begin
  if FLogger <> nil then
    FLogger.Erro(AMensagem, AExcecao);
end;

function TRelatorioPedido.DentroDaPastaTemp(const ACaminho: string): Boolean;
var
  Pasta, Arquivo: string;
begin
  Pasta := IncludeTrailingPathDelimiter(ExpandFileName(FPastaTemp));
  Arquivo := ExpandFileName(ACaminho);
  Result := SameText(Copy(Arquivo, 1, Length(Pasta)), Pasta);
end;

procedure TRelatorioPedido.LimparAntigos;
var
  Pasta, Caminho: string;
  SR: TSearchRec;
  DataArquivo: TDateTime;
  Removidos: Integer;
begin
  Removidos := 0;
  try
    Pasta := IncludeTrailingPathDelimiter(FPastaTemp);
    if FindFirst(Pasta + 'Pedido_*.pdf', faAnyFile and not faDirectory, SR) = 0 then
    try
      repeat
        Caminho := Pasta + SR.Name;
        if DentroDaPastaTemp(Caminho) and FileAge(Caminho, DataArquivo) and
          (Now - DataArquivo > RETENCAO_PDF_HORAS / 24) then
        begin
          if DeleteFile(Caminho) then
            Inc(Removidos)
          else
            LogAviso('Não foi possível remover PDF antigo: ' + Caminho);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
    if Removidos > 0 then
      LogAviso(Format('Limpeza de PDFs antigos: %d arquivo(s) removido(s) da pasta temp.',
        [Removidos]));
  except
    on E: Exception do
      LogAviso('Falha na limpeza de PDFs antigos: ' + E.Message);
  end;
end;

function TRelatorioPedido.GerarPdf(const AVenda: TVenda): string;
var
  Dados: TDataSet;
  Layout: TDMPedidoLayout;
  Caminho, Sufixo: string;
  Guid: TGUID;
begin
  // RF11-01: venda nula => EInfra amigavel + log sem dado pessoal (sem AV)
  if AVenda = nil then
  begin
    LogErro('GerarPdf: venda nula');
    raise EInfra.Create(MSG_FALHA_PDF);
  end;
  Caminho := '';
  Result := '';
  try
    // RF11-03: sufixo GUID (nao previsivel), sem chaves: Pedido_<Id>_<GUID>.pdf
    CreateGUID(Guid);
    Sufixo := StringReplace(GUIDToString(Guid), '{', '', [rfReplaceAll]);
    Sufixo := StringReplace(Sufixo, '}', '', [rfReplaceAll]);
    Caminho := IncludeTrailingPathDelimiter(FPastaTemp) +
      Format('Pedido_%d_%s.pdf', [AVenda.Id, Sufixo]);
    Result := Caminho;
    ForceDirectories(FPastaTemp);
    LimparAntigos;
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
      LogErro('Falha ao gerar PDF do pedido ' + IntToStr(AVenda.Id), E);
      // RF11-02: nao deixa PDF parcial (Print falhou apos criar o arquivo)
      if (Caminho <> '') and FileExists(Caminho) and DentroDaPastaTemp(Caminho) then
        if not DeleteFile(Caminho) then
          LogAviso('Não foi possível remover o PDF parcial: ' + Caminho);
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
    LogAviso('Limpeza de PDF ignorada: arquivo fora da pasta temp configurada.');
    Exit;
  end;
  if not DeleteFile(ACaminhoArquivo) then
    LogAviso('Não foi possível remover o PDF temporário: ' + ACaminhoArquivo);
end;

end.