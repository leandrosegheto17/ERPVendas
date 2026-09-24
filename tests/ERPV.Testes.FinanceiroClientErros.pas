unit ERPV.Testes.FinanceiroClientErros;

(*
  T55 - testes DUnitX do mapeamento de erro do TFinanceiroClient contra as
  respostas reais do C# (contrato v1.1, divergencias D1-D3 de
  docs/contrato-api-financeiro.md): funcoes puras ExtrairErro/MapearErroHttp,
  sem rede. Nao compilado (sem CLI); rodar na IDE junto do projeto de testes
  (inclui src\Integracao\ERPV.Integracao.FinanceiroClient e dependencias).
*)

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  ERPV.Dominio.Resultados,
  ERPV.Integracao.FinanceiroClient;

type
  [TestFixture]
  TTestesFinanceiroClientErros = class
  public
    // D1 - envelope {"erro":{"codigo","mensagem"}}
    [Test] procedure D1_EnvelopeReal_LeCodigoEMensagem;
    [Test] procedure D1_RaizV10_ContinuaLendoMensagem;
    [Test] procedure D1_CorpoVazioOuNaoJson_SemMensagem;
    [Test] procedure D1_CodigoInvalido_Descartado;
    [Test] procedure D1_Mensagem_LimpaControlesETrunca;
    [Test] procedure D1_Recusa400_ExibeMensagemDoEnvelope;
    [Test] procedure D1_SemMensagem_FallbackComCodigoHttp;
    // D2 - nao existe 422; 400/409 = recusa; 409 CONFLITO_CONCORRENCIA = retentavel
    [Test] procedure D2_400ValorDivergente_Recusado;
    [Test] procedure D2_409VendaJaCancelada_Recusado;
    [Test] procedure D2_409MotivoObrigatorio_Recusado;
    [Test] procedure D2_409Conflito_Indisponivel;
    [Test] procedure D2_409ConflitoDecideSoPeloCodigo_NaoPelaMensagem;
    [Test] procedure D2_409OutroCodigo_ComTextoDeConflito_Recusado;
    [Test] procedure D2_404_Recusado;
    [Test] procedure D2_500_Indisponivel;
    // D3 - 401 = configuracao da chave
    [Test] procedure D3_401SemChave_MensagemDeConfiguracao;
    [Test] procedure D3_401ComChave_MensagemChaveRejeitada;
    [Test] procedure D3_401_NaoUsaMensagemDoServidor;
    // RF14-01 / SG14-01 - http:// nao-loopback com ApiKey
    [Test] procedure RF1401_HttpLoopback_ComChave_Permitido;
    [Test] procedure RF1401_HttpRemoto_ComChave_Recusado;
    [Test] procedure RF1401_HttpRemoto_SemChave_Permitido;
    [Test] procedure RF1401_Https_ComChave_Permitido;
    [Test] procedure RF1401_HostDisfarcado_Recusado;
    [Test] procedure RF1401_Recusa_NaoVazaChaveEMensagemClara;
  end;

implementation

const
  ENV_CONFLITO =
    '{"erro":{"codigo":"CONFLITO_CONCORRENCIA","mensagem":"Conflito de concorrencia. Tente novamente."}}';

procedure TTestesFinanceiroClientErros.D1_EnvelopeReal_LeCodigoEMensagem;
var
  LCod, LMsg: string;
begin
  TFinanceiroClient.ExtrairErro(
    '{"erro":{"codigo":"VENDA_JA_CANCELADA","mensagem":"Venda ja cancelada."}}',
    LCod, LMsg);
  Assert.AreEqual('VENDA_JA_CANCELADA', LCod);
  Assert.AreEqual('Venda ja cancelada.', LMsg);
end;

procedure TTestesFinanceiroClientErros.D1_RaizV10_ContinuaLendoMensagem;
var
  LCod, LMsg: string;
begin
  TFinanceiroClient.ExtrairErro('{"mensagem":"Recusado pelo mock"}', LCod, LMsg);
  Assert.AreEqual('', LCod);
  Assert.AreEqual('Recusado pelo mock', LMsg);
end;

procedure TTestesFinanceiroClientErros.D1_CorpoVazioOuNaoJson_SemMensagem;
var
  LCod, LMsg: string;
begin
  TFinanceiroClient.ExtrairErro('', LCod, LMsg);
  Assert.AreEqual('', LMsg);
  TFinanceiroClient.ExtrairErro('<html>502 Bad Gateway</html>', LCod, LMsg);
  Assert.AreEqual('', LCod);
  Assert.AreEqual('', LMsg);
  TFinanceiroClient.ExtrairErro('{"erro":"texto solto"}', LCod, LMsg);
  Assert.AreEqual('', LMsg);
end;

procedure TTestesFinanceiroClientErros.D1_CodigoInvalido_Descartado;
var
  LCod, LMsg: string;
begin
  TFinanceiroClient.ExtrairErro(
    '{"erro":{"codigo":"COD; DROP TABLE","mensagem":"x"}}', LCod, LMsg);
  Assert.AreEqual('', LCod);
  Assert.AreEqual('x', LMsg);
end;

procedure TTestesFinanceiroClientErros.D1_Mensagem_LimpaControlesETrunca;
var
  LCod, LMsg: string;
begin
  TFinanceiroClient.ExtrairErro(
    '{"erro":{"codigo":"X","mensagem":"linha1\nlinha2"}}', LCod, LMsg);
  Assert.AreEqual('linha1 linha2', LMsg);
  TFinanceiroClient.ExtrairErro(
    '{"erro":{"codigo":"X","mensagem":"' + StringOfChar('a', 500) + '"}}', LCod, LMsg);
  Assert.IsTrue(Length(LMsg) <= 201);
end;

procedure TTestesFinanceiroClientErros.D1_Recusa400_ExibeMensagemDoEnvelope;
var
  R: TResultadoFinanceiro;
begin
  R := TFinanceiroClient.MapearErroHttp(400,
    '{"erro":{"codigo":"VALOR_TOTAL_DIVERGENTE","mensagem":"valorTotal diverge da soma."}}',
    'Quitacao', True);
  Assert.AreEqual(Ord(rfRecusado), Ord(R.Categoria));
  Assert.AreEqual(400, R.CodigoHttp);
  Assert.AreEqual('valorTotal diverge da soma.', R.Mensagem);
end;

procedure TTestesFinanceiroClientErros.D1_SemMensagem_FallbackComCodigoHttp;
var
  R: TResultadoFinanceiro;
begin
  R := TFinanceiroClient.MapearErroHttp(404, '', 'Consulta de status', True);
  Assert.AreEqual(Ord(rfRecusado), Ord(R.Categoria));
  Assert.IsTrue(R.Mensagem.Contains('codigo HTTP 404'));
end;

procedure TTestesFinanceiroClientErros.D2_400ValorDivergente_Recusado;
var
  R: TResultadoFinanceiro;
begin
  R := TFinanceiroClient.MapearErroHttp(400,
    '{"erro":{"codigo":"PAYLOAD_INVALIDO","mensagem":"itens vazio"}}', 'Quitacao', True);
  Assert.AreEqual(Ord(rfRecusado), Ord(R.Categoria));
  Assert.AreEqual(400, R.CodigoHttp);
end;

procedure TTestesFinanceiroClientErros.D2_409VendaJaCancelada_Recusado;
var
  R: TResultadoFinanceiro;
begin
  R := TFinanceiroClient.MapearErroHttp(409,
    '{"erro":{"codigo":"VENDA_JA_CANCELADA","mensagem":"Venda ja cancelada."}}',
    'Quitacao', True);
  Assert.AreEqual(Ord(rfRecusado), Ord(R.Categoria));
  Assert.AreEqual(409, R.CodigoHttp);
  Assert.AreEqual('Venda ja cancelada.', R.Mensagem);
end;

procedure TTestesFinanceiroClientErros.D2_409MotivoObrigatorio_Recusado;
var
  R: TResultadoFinanceiro;
begin
  R := TFinanceiroClient.MapearErroHttp(409,
    '{"erro":{"codigo":"MOTIVO_OBRIGATORIO","mensagem":"Motivo obrigatorio."}}',
    'Cancelamento', True);
  Assert.AreEqual(Ord(rfRecusado), Ord(R.Categoria));
end;

procedure TTestesFinanceiroClientErros.D2_409Conflito_Indisponivel;
var
  R: TResultadoFinanceiro;
begin
  R := TFinanceiroClient.MapearErroHttp(409, ENV_CONFLITO, 'Quitacao', True);
  Assert.AreEqual(Ord(rfIndisponivel), Ord(R.Categoria));
  Assert.AreEqual(409, R.CodigoHttp);
  Assert.IsTrue(R.Mensagem <> '');
end;

procedure TTestesFinanceiroClientErros.D2_409ConflitoDecideSoPeloCodigo_NaoPelaMensagem;
var
  R: TResultadoFinanceiro;
begin
  // mesmo com mensagem diferente, o codigo decide
  R := TFinanceiroClient.MapearErroHttp(409,
    '{"erro":{"codigo":"CONFLITO_CONCORRENCIA","mensagem":"qualquer texto"}}',
    'Cancelamento', True);
  Assert.AreEqual(Ord(rfIndisponivel), Ord(R.Categoria));
end;

procedure TTestesFinanceiroClientErros.D2_409OutroCodigo_ComTextoDeConflito_Recusado;
var
  R: TResultadoFinanceiro;
begin
  R := TFinanceiroClient.MapearErroHttp(409,
    '{"erro":{"codigo":"DADOS_DIVERGENTES","mensagem":"CONFLITO_CONCORRENCIA"}}',
    'Quitacao', True);
  Assert.AreEqual(Ord(rfRecusado), Ord(R.Categoria));
  // e o mesmo codigo com status diferente de 409 nao vira retentavel
  R := TFinanceiroClient.MapearErroHttp(400, ENV_CONFLITO, 'Quitacao', True);
  Assert.AreEqual(Ord(rfRecusado), Ord(R.Categoria));
end;

procedure TTestesFinanceiroClientErros.D2_404_Recusado;
var
  R: TResultadoFinanceiro;
begin
  R := TFinanceiroClient.MapearErroHttp(404,
    '{"erro":{"codigo":"VENDA_NAO_ENCONTRADA","mensagem":"Venda nao encontrada."}}',
    'Consulta de status', True);
  Assert.AreEqual(Ord(rfRecusado), Ord(R.Categoria));
  Assert.AreEqual(404, R.CodigoHttp);
end;

procedure TTestesFinanceiroClientErros.D2_500_Indisponivel;
var
  R: TResultadoFinanceiro;
begin
  R := TFinanceiroClient.MapearErroHttp(500,
    '{"erro":{"codigo":"ERRO_INTERNO","mensagem":"Erro interno."}}', 'Quitacao', True);
  Assert.AreEqual(Ord(rfIndisponivel), Ord(R.Categoria));
  Assert.AreEqual(500, R.CodigoHttp);
end;

procedure TTestesFinanceiroClientErros.D3_401SemChave_MensagemDeConfiguracao;
var
  R: TResultadoFinanceiro;
begin
  R := TFinanceiroClient.MapearErroHttp(401,
    '{"erro":{"codigo":"NAO_AUTORIZADO","mensagem":"Credencial ausente ou invalida."}}',
    'Quitacao', False);
  Assert.AreEqual(Ord(rfRecusado), Ord(R.Categoria)); // nao enfileira
  Assert.AreEqual(401, R.CodigoHttp);
  Assert.IsTrue(R.Mensagem.Contains('nenhuma esta configurada'));
  Assert.IsTrue(R.Mensagem.Contains('ERPV_FINANCEIRO_APIKEY'));
end;

procedure TTestesFinanceiroClientErros.D3_401ComChave_MensagemChaveRejeitada;
var
  R: TResultadoFinanceiro;
begin
  R := TFinanceiroClient.MapearErroHttp(401, ENV_CONFLITO, 'Quitacao', True);
  Assert.AreEqual(Ord(rfRecusado), Ord(R.Categoria));
  Assert.IsTrue(R.Mensagem.Contains('rejeitou a chave'));
  Assert.IsFalse(R.Mensagem.Contains('nenhuma esta configurada'));
end;

procedure TTestesFinanceiroClientErros.D3_401_NaoUsaMensagemDoServidor;
var
  R: TResultadoFinanceiro;
begin
  R := TFinanceiroClient.MapearErroHttp(401,
    '{"erro":{"codigo":"NAO_AUTORIZADO","mensagem":"TEXTO_DO_SERVIDOR"}}',
    'Quitacao', True);
  Assert.IsFalse(R.Mensagem.Contains('TEXTO_DO_SERVIDOR'));
end;

procedure TTestesFinanceiroClientErros.RF1401_HttpLoopback_ComChave_Permitido;
begin
  Assert.IsFalse(TFinanceiroClient.UrlInseguraComChave('http://localhost:5000', 'k'));
  Assert.IsFalse(TFinanceiroClient.UrlInseguraComChave('HTTP://LocalHost', 'k'));
  Assert.IsFalse(TFinanceiroClient.UrlInseguraComChave('http://127.0.0.1:8080/', 'k'));
  Assert.IsFalse(TFinanceiroClient.UrlInseguraComChave('http://[::1]:5000', 'k'));
end;

procedure TTestesFinanceiroClientErros.RF1401_HttpRemoto_ComChave_Recusado;
begin
  Assert.IsTrue(TFinanceiroClient.UrlInseguraComChave('http://host-remoto', 'k'));
  Assert.IsTrue(TFinanceiroClient.UrlInseguraComChave('http://192.168.0.10:5000/api', 'k'));
  Assert.IsTrue(TFinanceiroClient.UrlInseguraComChave('http://financeiro.empresa.com', 'k'));
end;

procedure TTestesFinanceiroClientErros.RF1401_HttpRemoto_SemChave_Permitido;
begin
  Assert.IsFalse(TFinanceiroClient.UrlInseguraComChave('http://host-remoto', ''));
  Assert.IsFalse(TFinanceiroClient.UrlInseguraComChave('http://host-remoto', '   '));
end;

procedure TTestesFinanceiroClientErros.RF1401_Https_ComChave_Permitido;
begin
  Assert.IsFalse(TFinanceiroClient.UrlInseguraComChave('https://host-remoto', 'k'));
  Assert.IsFalse(TFinanceiroClient.UrlInseguraComChave('https://financeiro.empresa.com:443', 'k'));
end;

procedure TTestesFinanceiroClientErros.RF1401_HostDisfarcado_Recusado;
begin
  // "localhost" so como prefixo/usuario nao vale
  Assert.IsTrue(TFinanceiroClient.UrlInseguraComChave('http://localhost.evil.com', 'k'));
  Assert.IsTrue(TFinanceiroClient.UrlInseguraComChave('http://localhost@evil.com', 'k'));
  Assert.IsTrue(TFinanceiroClient.UrlInseguraComChave('http://', 'k'));
  Assert.IsTrue(TFinanceiroClient.UrlInseguraComChave('http://127.evil.com', 'k'));
  Assert.IsTrue(TFinanceiroClient.UrlInseguraComChave('http://127.0.0.1.evil.com', 'k'));
  Assert.IsTrue(TFinanceiroClient.UrlInseguraComChave('http://127.0.0.256', 'k'));
  Assert.IsTrue(TFinanceiroClient.UrlInseguraComChave('http://127.1', 'k'));
  // IPv4 127.a.b.c valido segue permitido
  Assert.IsFalse(TFinanceiroClient.UrlInseguraComChave('http://127.0.0.1:8080/', 'k'));
  Assert.IsFalse(TFinanceiroClient.UrlInseguraComChave('http://127.1.2.3', 'k'));
end;

procedure TTestesFinanceiroClientErros.RF1401_Recusa_NaoVazaChaveEMensagemClara;
var
  R: TResultadoFinanceiro;
  C: TFinanceiroClient;
begin
  C := TFinanceiroClient.Create('http://host-remoto', 1000, 'CHAVE_SECRETA_XYZ');
  try
    // Falha antes de qualquer rede: o retorno e imediato
    R := C.ConsultarStatus(1);
  finally
    C.Free;
  end;
  Assert.AreEqual(Ord(rfRecusado), Ord(R.Categoria));
  Assert.IsTrue(R.Mensagem.Contains('https://'));
  Assert.IsFalse(R.Mensagem.Contains('CHAVE_SECRETA_XYZ'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestesFinanceiroClientErros);

end.
