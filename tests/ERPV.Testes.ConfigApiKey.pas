unit ERPV.Testes.ConfigApiKey;

(*
  RF14-03 - testes DUnitX do aviso de ApiKey vazia. Nao compilado (sem CLI);
  rodar na IDE junto do projeto de testes.
*)

interface

uses
  DUnitX.TestFramework, ERPV.Core.Config;

type
  [TestFixture]
  TTestesConfigApiKey = class
  public
    [Test] procedure ApiKeyVazia_GeraAviso;
    [Test] procedure ApiKeyApenasEspacos_GeraAviso;
    [Test] procedure ApiKeyPreenchida_SemAviso;
    [Test] procedure Aviso_NaoContemValorDaChave;
  end;

implementation

procedure TTestesConfigApiKey.ApiKeyVazia_GeraAviso;
begin
  Assert.AreEqual(MSG_AVISO_APIKEY_VAZIA, TConfiguracao.AvisoApiKeyVazia(''));
end;

procedure TTestesConfigApiKey.ApiKeyApenasEspacos_GeraAviso;
begin
  Assert.AreNotEqual('', TConfiguracao.AvisoApiKeyVazia('   '));
end;

procedure TTestesConfigApiKey.ApiKeyPreenchida_SemAviso;
begin
  Assert.AreEqual('', TConfiguracao.AvisoApiKeyVazia('abc123'));
end;

procedure TTestesConfigApiKey.Aviso_NaoContemValorDaChave;
begin
  // O aviso e texto fixo: nunca ecoa a entrada.
  Assert.IsFalse(Pos('segredo-xyz', TConfiguracao.AvisoApiKeyVazia('')) > 0);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestesConfigApiKey);

end.
