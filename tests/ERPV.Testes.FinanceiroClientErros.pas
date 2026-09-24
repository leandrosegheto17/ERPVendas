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
    [Test] procedure D1_Mensagem_RemoveDelBidiESeparadoresUnicode;
    [Test] procedure D1_Mensagem_MascaraDadoSensivel;
    [Test] procedure D1_Mensagem_SanitizaMascaraETrunca;
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

procedure TTestesFinanceiroClientErros.D1_Mensagem_RemoveDelBidiESeparadoresUnicode;
var
  LCod, LMsg: string;
begin
  // JSON com escapes \u: DEL, U+2028, U+2029, RLO (202E), LRI (2066), LRM (200E)
  TFinanceiroClient.ExtrairErro(
    '{"erro":{"codigo":"X","mensagem":"a\u007Fb\u2028c\u2029d\u202Ee\u2066f\u200Eg"}}',
    LCod, LMsg);
  Assert.AreEqual('a b c d e f g', LMsg);
end;

procedure TTestesFinanceiroClientErros.D1_Mensagem_MascaraDadoSensivel;
var
  LCod, LMsg: string;
begin
  TFinanceiroClient.ExtrairErro(
    '{"erro":{"codigo":"X","mensagem":"CPF 123.456.789-09 de joao@empresa.com apikey=abc123"}}',
    LCod, LMsg);
  Assert.IsFalse(LMsg.Contains('123.456.789-09'));
  Assert.IsFalse(LMsg.Contains('joao@'));
  Assert.IsFalse(LMsg.Contains('abc123'));
  Assert.IsTrue(LMsg.Contains('***.456.789-**'));
end;

procedure TTestesFinanceiroClientErros.D1_Mensagem_SanitizaMascaraETrunca;
var
  R: TResultadoFinanceiro;
begin
  R := TFinanceiroClient.MapearErroHttp(400,
    '{"erro":{"codigo":"X","mensagem":"12345678909\n\u202E' +
    StringOfChar('a', 400) + '"}}', 'Quitacao', True);
  Assert.AreEqual(Ord(rfRecusado), Ord(R.Categoria));
  Assert.IsFalse(R.Mensagem.Contains('12345678909'));
  Assert.IsFalse(R.Mensagem.Contains(#$202E));
  Assert.IsFalse(R.Mensagem.Contains(#10));
  Assert.IsTrue(Length(R.Mensagem) <= 201);
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

initialization
  TDUnitX.RegisterTestFixture(TTestesFinanceiroClientErros);

end.
