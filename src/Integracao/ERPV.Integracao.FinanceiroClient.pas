unit ERPV.Integracao.FinanceiroClient;

(*
  FinanceiroClient (T34, Lote 8; RF-12/13, ADR-004). Implementa
  IFinanceiroGateway sobre THTTPClient SINCRONO (sem threads, sem Vcl).

  Regras:
   - Timeout do INI (TConfiguracao.Financeiro.TimeoutMs, JA em ms) aplicado
     a ConnectionTimeout/SendTimeout/ResponseTimeout (docs/ambiente-licencas.md
     secao 4).
   - X-Api-Key enviado somente se ApiKey <> ''. Nunca logada.
   - Falha esperada vira TResultadoFinanceiro, nunca excecao:
       200 + corpo valido   => Sucesso
       200 + corpo invalido => RespostaInvalida
       4xx                  => Recusado (mensagem do corpo {"mensagem"} ou
                               fallback "... (codigo HTTP xxx)"); nao reenfileira
       5xx / timeout / rede => Indisponivel
       demais codigos (1xx/3xx) => Indisponivel (inesperado, tratado como infra)
   - Log (opcional, ALogger pode ser nil): so metodo, rota e codigo HTTP;
     nunca corpo nem cabecalhos.
   - Estrutura: Enviar(...) privado e generico (metodo, rota, corpo, parser);
     T35/T36 so acrescentam metodos publicos chamando Enviar.
   - ConfirmarCancelamento (T35) e ConsultarStatus (T36) reutilizam Enviar.

  Composition root: ERPV.App.Root ainda nao expoe gateways (nenhum consumidor
  ate T38); instanciar la sera feito em T38 com
  TFinanceiroClient.Create(Cfg.Financeiro.BaseUrl, Cfg.Financeiro.TimeoutMs,
  Cfg.Financeiro.ApiKey, Logger). Units de Dominio/Integracao nao estao no
  .dproj via DCCReference (padrao vigente; resolvidas por DCC_UnitSearchPath).

  ROTEIRO MANUAL (Delphi Community nao compila via CLI; usar projeto de teste
  ou botao temporario; mock: python tools/mock-financeiro/mock_financeiro.py,
  porta 8101; BaseUrl http://localhost:8101, TimeoutMs 10000; venda Id=1042
  Pendente com 1 item):
   1. Compilar (Shift+F9): 0 erros.
   2. GET http://localhost:8101/_modo?m=ok; ConfirmarQuitacao => Categoria
      rfSucesso, Status svQuitada, DataQuitacao <> 0.
   3. m=recusa => rfRecusado, CodigoHttp 422, Mensagem preenchida (do corpo
      ou "... (codigo HTTP 422)").
   4. m=erro500 => rfIndisponivel, CodigoHttp 500.
   5. m=timeout => rfIndisponivel, CodigoHttp 0, retorno em ~10 s (nao 11+).
   6. m=offline-simulado => rfIndisponivel (conexao derrubada).
   7. Parar o mock => rfIndisponivel imediato (conexao recusada).
   8. Com ApiKey='abc', conferir no mock que X-Api-Key chegou; com
      ApiKey='' o header nao deve existir. Log do app sem corpo/ApiKey.
   T36 (ConsultarStatus, GET /api/vendas/{id}/status):
   9. m=ok; ConsultarStatus(1042) => rfSucesso, Status svPendente (ou
      svQuitada apos quitar a venda); DataQuitacao = 0.
  10. Status desconhecido/corpo invalido => rfRespostaInvalida. Venda inexistente (404) => rfRecusado, CodigoHttp 404.
  11. m=erro500/timeout/parar mock => rfIndisponivel (igual aos passos 4-7).

  ROTEIRO MANUAL T35 (ConfirmarCancelamento; mesmo mock/BaseUrl):
   1. m=ok; ConfirmarCancelamento(1042, 'Cliente desistiu') => rfSucesso,
      Status svCancelada. Com motivo '' o corpo enviado nao tem "motivo".
   2. m=recusa => rfRecusado, CodigoHttp 422, Mensagem preenchida.
   3. m=erro500 => rfIndisponivel, CodigoHttp 500.
   4. m=timeout / offline-simulado / mock parado => rfIndisponivel.
   5. Resposta 2xx com status diferente de Cancelada (ex.: Quitada) ou corpo
      invalido => rfRespostaInvalida.
*)

interface

uses
  System.SysUtils,
  System.Classes,
  System.Net.HttpClient,
  System.Net.URLClient,
  ERPV.Core.Log,
  ERPV.Dominio.Venda,
  ERPV.Dominio.Resultados,
  ERPV.Dominio.Contratos.IFinanceiroGateway;

type
  TFinanceiroClient = class(TInterfacedObject, IFinanceiroGateway)
  private
    FBaseUrl: string;
    FTimeoutMs: Integer;
    FApiKey: string;
    FLogger: TLogger; // nao e dono; pode ser nil
    function MontarUrl(const ARota: string): string;
    function ExtrairMensagem(const ACorpo: string): string;
    /// <summary>Executa AMetodo ('POST'/'GET') em ARota; nunca lanca.
    /// Devolve o codigo HTTP em ACodigo e o corpo em ACorpo; False = falha
    /// de rede/timeout (AErro = so nome da classe da excecao).</summary>
    function Executar(const AMetodo, ARota, ACorpoEnvio: string;
      out ACodigo: Integer; out ACorpo, AErro: string): Boolean;
    /// <summary>Envio generico + mapeamento de codigo HTTP; em 2xx chama
    /// AInterpretar com o corpo (que devolve Sucesso ou RespostaInvalida).</summary>
    function Enviar(const AMetodo, ARota, ACorpoEnvio, ADescricao: string;
      const AInterpretar: TFunc<string, TResultadoFinanceiro>): TResultadoFinanceiro;
  public
    /// <param name="ATimeoutMs">Em milissegundos (TConfiguracaoFinanceiro.TimeoutMs).</param>
    /// <param name="AApiKey">'' = nao envia X-Api-Key.</param>
    constructor Create(const ABaseUrl: string; ATimeoutMs: Integer;
      const AApiKey: string; ALogger: TLogger = nil);
    function ConfirmarQuitacao(const AVenda: TVenda): TResultadoFinanceiro;
    function ConfirmarCancelamento(AVendaId: Integer; const AMotivo: string): TResultadoFinanceiro;
    function ConsultarStatus(AVendaId: Integer): TResultadoFinanceiro;
  end;

implementation

uses
  System.JSON,
  ERPV.Dominio.Enums,
  ERPV.Integracao.FinanceiroDTOs;

const
  ROTA_QUITACAO = '/api/vendas/quitacao';
  ROTA_STATUS_PREFIXO = '/api/vendas/';
  ROTA_STATUS_SUFIXO = '/status';
  ROTA_CANCELAMENTO = '/api/vendas/cancelamento';

constructor TFinanceiroClient.Create(const ABaseUrl: string; ATimeoutMs: Integer;
  const AApiKey: string; ALogger: TLogger);
begin
  inherited Create;
  FBaseUrl := ABaseUrl;
  while (FBaseUrl <> '') and (FBaseUrl[Length(FBaseUrl)] = '/') do
    Delete(FBaseUrl, Length(FBaseUrl), 1);
  FTimeoutMs := ATimeoutMs;
  FApiKey := Trim(AApiKey);
  FLogger := ALogger;
end;

function TFinanceiroClient.MontarUrl(const ARota: string): string;
begin
  Result := FBaseUrl + ARota;
end;

function TFinanceiroClient.ExtrairMensagem(const ACorpo: string): string;
var
  LVal: TJSONValue;
  LMsg: TJSONValue;
  LI, LTam: Integer;
const
  CMaxMensagem = 200;
begin
  Result := '';
  if Trim(ACorpo) = '' then
    Exit;
  LVal := nil;
  try
    try
      LVal := TJSONObject.ParseJSONValue(ACorpo);
    except
      LVal := nil;
    end;
    if LVal is TJSONObject then
    begin
      LMsg := TJSONObject(LVal).GetValue('mensagem');
      if (LMsg <> nil) and (LMsg is TJSONString) then
        Result := Trim(TJSONString(LMsg).Value);
    end;
  finally
    LVal.Free; // Free em nil e seguro
  end;
  // Uma linha, sem controles; teste de vazio (fallback "codigo HTTP") fica depois da limpeza
  for LI := 1 to Length(Result) do
    if Result[LI] < ' ' then
      Result[LI] := ' ';
  Result := Trim(Result);
  if Length(Result) > CMaxMensagem then
  begin
    LTam := CMaxMensagem;
    if (Result[LTam] >= #$D800) and (Result[LTam] <= #$DBFF) then
      Dec(LTam); // nao deixa par substituto partido
    Result := Trim(Copy(Result, 1, LTam)) + #$2026;
  end;
end;

function TFinanceiroClient.Executar(const AMetodo, ARota, ACorpoEnvio: string;
  out ACodigo: Integer; out ACorpo, AErro: string): Boolean;
var
  LHttp: THTTPClient;
  LResp: IHTTPResponse;
  LStream: TStringStream;
  LHeaders: TNetHeaders;
begin
  Result := False;
  ACodigo := 0;
  ACorpo := '';
  AErro := '';
  LHttp := nil;
  LStream := nil;
  try
    try
      LHttp := THTTPClient.Create;
      LHttp.ConnectionTimeout := FTimeoutMs;
      LHttp.SendTimeout := FTimeoutMs;
      LHttp.ResponseTimeout := FTimeoutMs;
      LHttp.HandleRedirects := False;
      LHttp.Accept := 'application/json';

      SetLength(LHeaders, 0);
      if FApiKey <> '' then
      begin
        SetLength(LHeaders, 1);
        LHeaders[0] := TNameValuePair.Create('X-Api-Key', FApiKey);
      end;

      if AMetodo = 'GET' then
        LResp := LHttp.Get(MontarUrl(ARota), nil, LHeaders)
      else
      begin
        LHttp.ContentType := 'application/json; charset=utf-8';
        LStream := TStringStream.Create(ACorpoEnvio, TEncoding.UTF8, False);
        LResp := LHttp.Post(MontarUrl(ARota), LStream, nil, LHeaders);
      end;

      ACodigo := LResp.StatusCode;
      ACorpo := LResp.ContentAsString(TEncoding.UTF8);
      Result := True;
    except
      on E: Exception do
      begin
        // Timeout, DNS, conexao recusada/derrubada etc. Guarda so a classe
        // da excecao (sem URL, cabecalhos ou corpo).
        AErro := E.ClassName;
        Result := False;
      end;
    end;
  finally
    LStream.Free;
    LHttp.Free;
  end;
end;

function TFinanceiroClient.Enviar(const AMetodo, ARota, ACorpoEnvio, ADescricao: string;
  const AInterpretar: TFunc<string, TResultadoFinanceiro>): TResultadoFinanceiro;
var
  LCodigo: Integer;
  LCorpo, LErro, LMsg: string;
begin
  if not Executar(AMetodo, ARota, ACorpoEnvio, LCodigo, LCorpo, LErro) then
  begin
    if FLogger <> nil then
      FLogger.Aviso(Format('Financeiro %s %s: sem resposta (%s)', [AMetodo, ARota, LErro]));
    Result := TResultadoFinanceiro.Indisponivel(0,
      'Financeiro indisponivel (sem resposta no tempo limite ou falha de conexao).');
    Exit;
  end;

  if FLogger <> nil then
    FLogger.Info(Format('Financeiro %s %s: HTTP %d', [AMetodo, ARota, LCodigo]));

  if (LCodigo >= 200) and (LCodigo < 300) then
  begin
    Result := AInterpretar(LCorpo);
    Exit;
  end;

  if (LCodigo >= 400) and (LCodigo < 500) then
  begin
    LMsg := ExtrairMensagem(LCorpo);
    if LMsg = '' then
      LMsg := Format('%s recusada pelo Financeiro (codigo HTTP %d)', [ADescricao, LCodigo]);
    Result := TResultadoFinanceiro.Recusado(LCodigo, LMsg);
    Exit;
  end;

  // 5xx e qualquer outro codigo inesperado: infraestrutura.
  Result := TResultadoFinanceiro.Indisponivel(LCodigo,
    Format('Financeiro indisponivel (codigo HTTP %d)', [LCodigo]));
end;

function TFinanceiroClient.ConfirmarQuitacao(const AVenda: TVenda): TResultadoFinanceiro;
var
  LBody: string;
begin
  LBody := SerializarQuitacaoRequest(AVenda);
  Result := Enviar('POST', ROTA_QUITACAO, LBody, 'Quitacao',
    function(ACorpo: string): TResultadoFinanceiro
    var
      LDto: TQuitacaoResponseDTO;
    begin
      if TryParseQuitacaoResponse(ACorpo, LDto) then
        Result := TResultadoFinanceiro.Sucesso(LDto.Status, LDto.DataQuitacao)
      else
        Result := TResultadoFinanceiro.RespostaInvalida(
          'Resposta invalida do Financeiro na quitacao.');
    end);
end;

function TFinanceiroClient.ConfirmarCancelamento(AVendaId: Integer;
  const AMotivo: string): TResultadoFinanceiro;
begin
  Result := Enviar('POST', ROTA_CANCELAMENTO,
    SerializarCancelamentoRequest(AVendaId, AMotivo), 'Cancelamento',
    function(ACorpo: string): TResultadoFinanceiro
    var
      LDto: TCancelamentoResponseDTO;
    begin
      if TryParseCancelamentoResponse(ACorpo, LDto)
        and (LDto.Status = ERPV.Dominio.Enums.svCancelada) then
        Result := TResultadoFinanceiro.Sucesso(LDto.Status)
      else
        Result := TResultadoFinanceiro.RespostaInvalida(
          'Resposta invalida do Financeiro no cancelamento.');
    end);
end;

function TFinanceiroClient.ConsultarStatus(AVendaId: Integer): TResultadoFinanceiro;
var
  LRota: string;
begin
  LRota := ROTA_STATUS_PREFIXO + IntToStr(AVendaId) + ROTA_STATUS_SUFIXO;
  Result := Enviar('GET', LRota, '', 'Consulta de status',
    function(ACorpo: string): TResultadoFinanceiro
    var
      LDto: TStatusResponseDTO;
    begin
      if TryParseStatusResponse(ACorpo, LDto) then
        Result := TResultadoFinanceiro.Sucesso(LDto.Status)
      else
        Result := TResultadoFinanceiro.RespostaInvalida(
          'Resposta invalida do Financeiro na consulta de status.');
    end);
end;

end.
