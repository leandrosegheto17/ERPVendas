unit ERPV.Integracao.FinanceiroClient;

(*
  FinanceiroClient (T34, Lote 8; RF-12/13, ADR-004; ajustes T55). Implementa
  IFinanceiroGateway sobre THTTPClient SINCRONO (sem threads, sem Vcl).

  Regras:
   - Timeout do INI (TConfiguracao.Financeiro.TimeoutMs, JA em ms) aplicado
     a ConnectionTimeout/SendTimeout/ResponseTimeout (docs/ambiente-licencas.md
     secao 4).
   - X-Api-Key enviado somente se ApiKey <> ''. Nunca logada. O C# real EXIGE
     a chave (T55/D3); o cliente segue tolerante ao mock (sem chave).
   - Falha esperada vira TResultadoFinanceiro, nunca excecao:
       200 + corpo valido   => Sucesso
       200 + corpo invalido => RespostaInvalida
       4xx                  => Recusado (mensagem do envelope real do C#
                               {"erro":{"codigo","mensagem"}} - T55/D1 -, ou
                               da raiz {"mensagem"} (v1.0), ou fallback
                               "... (codigo HTTP xxx)"); nao reenfileira.
                               O C# nao usa 422: recusa e 400/409 (T55/D2).
       401                  => Recusado com mensagem de CONFIGURACAO da chave
                               X-Api-Key (T55/D3), nao "recusa de negocio"
       409 CONFLITO_CONCORRENCIA => Indisponivel (retentavel; enfileira):
                               contrato-v1.1 do Financeiro diz que o cliente
                               pode repetir a requisicao (T55/D2). A decisao
                               usa so o `codigo`, nunca o texto da mensagem (D8).
       5xx / timeout / rede => Indisponivel
       demais codigos (1xx/3xx) => Indisponivel (inesperado, tratado como infra)
   - Log (opcional, ALogger pode ser nil): so metodo, rota e codigo HTTP;
     nunca corpo nem cabecalhos.
   - Estrutura: Enviar(...) privado e generico (metodo, rota, corpo, parser);
     ConfirmarCancelamento (T35) e ConsultarStatus (T36), ja implementados,
     reutilizam Enviar. O mapeamento de erro esta em MapearErroHttp/ExtrairErro
     (class functions puras, sem rede, cobertas por ERPV.Testes.FinanceiroClientErros).
   - RF8-01: TryIsoToDateTime (FinanceiroDTOs) captura qualquer Exception;
     dataQuitacao malformada => RespostaInvalida. RF8-03: ExtrairErro
     limpa controles e trunca a mensagem 4xx em 200 caracteres.

  Composition root: ERPV.App.Root instancia
  TFinanceiroClient.Create(Cfg.Financeiro.BaseUrl, Cfg.Financeiro.TimeoutMs,
  Cfg.Financeiro.ApiKey, Logger) e o expoe como IFinanceiroGateway; os
  consumidores sao TQuitacaoService e TFilaService. FinanceiroClient e
  FinanceiroDTOs nao estao no .dproj via DCCReference (resolvidas por
  DCC_UnitSearchPath; em Integracao, so EmailSender consta como DCCReference).

  ROTEIRO MANUAL (Delphi Community nao compila via CLI; usar projeto de teste
  ou botao temporario; mock: python tools/mock-financeiro/mock_financeiro.py,
  porta do mock (padrao 8080); BaseUrl http://localhost:8080, TimeoutMs 10000; venda Id=1042
  Pendente com 1 item):
   1. Compilar (Shift+F9): 0 erros.
   2. GET http://localhost:8080/_modo?m=ok; ConfirmarQuitacao => Categoria
      rfSucesso, Status svQuitada, DataQuitacao <> 0.
   3. m=recusa (o mock agora responde 400 com envelope "erro", como o C# real, que usa
      400/409 e nunca 422) => rfRecusado, CodigoHttp 400, Mensagem
      preenchida (do corpo ou "... (codigo HTTP 400)").
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
   2. m=recusa => rfRecusado, CodigoHttp 400 (mock), Mensagem preenchida.
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
    /// <summary>Le o corpo de erro do C# {"erro":{"codigo","mensagem"}} (D1),
    /// tolerando a raiz {"mensagem"} (v1.0) e corpo vazio/nao-JSON (devolve ''
    /// nos dois). AMensagem e limpa (uma linha, max. 200 chars); ACodigo so
    /// aceita [A-Za-z0-9_] (max. 64), senao ''.</summary>
    class procedure ExtrairErro(const ACorpo: string; out ACodigo,
      AMensagem: string);
    /// <summary>Mapeia resposta NAO-2xx ja recebida (funcao pura, sem rede).
    /// 4xx => Recusado (401 => mensagem de configuracao; 409
    /// CONFLITO_CONCORRENCIA => Indisponivel); demais => Indisponivel.</summary>
    class function MapearErroHttp(ACodigoHttp: Integer; const ACorpo,
      ADescricao: string; ATemApiKey: Boolean): TResultadoFinanceiro;
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

class procedure TFinanceiroClient.ExtrairErro(const ACorpo: string;
  out ACodigo, AMensagem: string);
var
  LVal: TJSONValue;
  LAlvo: TJSONObject;
  LV: TJSONValue;
  LI, LTam: Integer;
const
  CMaxMensagem = 200;
  CMaxCodigo = 64;
begin
  ACodigo := '';
  AMensagem := '';
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
      LAlvo := TJSONObject(LVal);
      // Envelope real do C# (D1): {"erro":{"codigo","mensagem"}}.
      // Sem envelope, LAlvo continua a raiz (tolera v1.0 {"mensagem"}).
      LV := LAlvo.GetValue('erro');
      if LV is TJSONObject then
        LAlvo := TJSONObject(LV);
      LV := LAlvo.GetValue('mensagem');
      if (LV <> nil) and (LV is TJSONString) then
        AMensagem := Trim(TJSONString(LV).Value);
      LV := LAlvo.GetValue('codigo');
      if (LV <> nil) and (LV is TJSONString) then
        ACodigo := Trim(TJSONString(LV).Value);
    end;
  finally
    LVal.Free; // Free em nil e seguro
  end;
  // codigo: so identificador simples (usado em decisao, nunca como texto livre)
  if Length(ACodigo) > CMaxCodigo then
    ACodigo := '';
  for LI := 1 to Length(ACodigo) do
    if not CharInSet(ACodigo[LI], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
    begin
      ACodigo := '';
      Break;
    end;
  // Uma linha, sem controles; teste de vazio (fallback "codigo HTTP") fica depois da limpeza
  // RF14-04: controles C0, DEL, C1, separadores U+2028/2029 e caracteres bidi
  // (U+061C, U+200E/200F, U+202A-202E, U+2066-2069) viram espaco.
  for LI := 1 to Length(AMensagem) do
    if (AMensagem[LI] < ' ') or
       ((AMensagem[LI] >= #$007F) and (AMensagem[LI] <= #$009F)) or
       (AMensagem[LI] = #$061C) or
       (AMensagem[LI] = #$200E) or (AMensagem[LI] = #$200F) or
       (AMensagem[LI] = #$2028) or (AMensagem[LI] = #$2029) or
       ((AMensagem[LI] >= #$202A) and (AMensagem[LI] <= #$202E)) or
       ((AMensagem[LI] >= #$2066) and (AMensagem[LI] <= #$2069)) then
      AMensagem[LI] := ' ';
  // RF14-04: mascara dado sensivel (CPF/CNPJ/e-mail/segredos) antes de exibir;
  // feito antes do truncamento para nao cortar um dado no meio.
  AMensagem := Trim(TLogger.MascararSensiveis(AMensagem));
  if Length(AMensagem) > CMaxMensagem then
  begin
    LTam := CMaxMensagem;
    if (AMensagem[LTam] >= #$D800) and (AMensagem[LTam] <= #$DBFF) then
      Dec(LTam); // nao deixa par substituto partido
    AMensagem := Trim(Copy(AMensagem, 1, LTam)) + #$2026;
  end;
end;

class function TFinanceiroClient.MapearErroHttp(ACodigoHttp: Integer;
  const ACorpo, ADescricao: string; ATemApiKey: Boolean): TResultadoFinanceiro;
var
  LCodigo, LMsg: string;
begin
  if (ACodigoHttp >= 400) and (ACodigoHttp < 500) then
  begin
    // D3: 401 = problema de configuracao da chave, nao recusa de negocio.
    // Texto fixo (nao usa a mensagem do servidor); segue Recusado (nao enfileira:
    // repetir sem corrigir a configuracao nao adianta).
    if ACodigoHttp = 401 then
    begin
      if ATemApiKey then
        Result := TResultadoFinanceiro.Recusado(401,
          'O Financeiro rejeitou a chave de acesso (X-Api-Key). Verifique a ApiKey configurada.')
      else
        Result := TResultadoFinanceiro.Recusado(401,
          'O Financeiro exige chave de acesso (X-Api-Key) e nenhuma esta configurada. ' +
          'Informe ApiKey no INI ou em ERPV_FINANCEIRO_APIKEY.');
      Exit;
    end;
    ExtrairErro(ACorpo, LCodigo, LMsg);
    // D2: 409 CONFLITO_CONCORRENCIA e retentavel (contrato-v1.1 do Financeiro).
    if (ACodigoHttp = 409) and SameText(LCodigo, 'CONFLITO_CONCORRENCIA') then
    begin
      Result := TResultadoFinanceiro.Indisponivel(409,
        'Financeiro ocupado (conflito de concorrencia); a operacao sera retentada.');
      Exit;
    end;
    if LMsg = '' then
      LMsg := Format('%s recusada pelo Financeiro (codigo HTTP %d)', [ADescricao, ACodigoHttp]);
    Result := TResultadoFinanceiro.Recusado(ACodigoHttp, LMsg);
    Exit;
  end;

  // 5xx e qualquer outro codigo inesperado: infraestrutura.
  Result := TResultadoFinanceiro.Indisponivel(ACodigoHttp,
    Format('Financeiro indisponivel (codigo HTTP %d)', [ACodigoHttp]));
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
  LCorpo, LErro: string;
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

  Result := MapearErroHttp(LCodigo, LCorpo, ADescricao, FApiKey <> '');
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
