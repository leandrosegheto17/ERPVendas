unit ERPV.Testes.PendenciasApresentacao;

(*
  T52 - testes DUnitX da apresentacao pura de Pendencias. Nao compilado (sem
  CLI); rodar na IDE junto do projeto de testes (inclui
  src\UI\ERPV.UI.PendenciasApresentacao e src\Negocio\ERPV.Negocio.FilaService).
*)

interface

uses
  DUnitX.TestFramework, ERPV.Negocio.FilaService, ERPV.UI.PendenciasApresentacao;

type
  [TestFixture]
  TTestesPendenciasApresentacao = class
  public
    [Test] procedure Concluido_MostraItemConcluido;
    [Test] procedure Falha_MostraAindaNaoFoiPossivelComErro;
    [Test] procedure Falha_SemMensagem_TemTextoPadrao;
    [Test] procedure Subtitulo_Singular_Plural_E_Todos;
    [Test] procedure Tipo_E_Situacao_Traduzidos;
  end;

implementation

procedure TTestesPendenciasApresentacao.Concluido_MostraItemConcluido;
var
  R: TResultadoReenvio;
  M: TMensagemReenvio;
begin
  R.Desfecho := rrConcluido;
  R.Mensagem := '';
  M := MensagemDeReenvio(R);
  Assert.AreEqual('Item concluído.', M.Texto);
  Assert.IsTrue(M.Sucesso);
end;

procedure TTestesPendenciasApresentacao.Falha_MostraAindaNaoFoiPossivelComErro;
var
  R: TResultadoReenvio;
  M: TMensagemReenvio;
begin
  R.Desfecho := rrFalha;
  R.Mensagem := 'Timeout (10 s)';
  M := MensagemDeReenvio(R);
  Assert.AreEqual('Ainda não foi possível: Timeout (10 s)', M.Texto);
  Assert.IsFalse(M.Sucesso);
end;

procedure TTestesPendenciasApresentacao.Falha_SemMensagem_TemTextoPadrao;
var
  R: TResultadoReenvio;
  M: TMensagemReenvio;
begin
  R.Desfecho := rrNaoSuportado;
  R.Mensagem := '';
  M := MensagemDeReenvio(R);
  Assert.IsNotEmpty(M.Texto);
  Assert.IsFalse(M.Sucesso);
end;

procedure TTestesPendenciasApresentacao.Subtitulo_Singular_Plural_E_Todos;
begin
  Assert.AreEqual('1 item aguardando reenvio', SubtituloPendencias(1, True));
  Assert.AreEqual('2 itens aguardando reenvio', SubtituloPendencias(2, True));
  Assert.AreEqual('3 itens', SubtituloPendencias(3, False));
end;

procedure TTestesPendenciasApresentacao.Tipo_E_Situacao_Traduzidos;
begin
  Assert.AreEqual('Quitação', TextoTipoFila('QUITACAO'));
  Assert.AreEqual('Cancelamento', TextoTipoFila('CANCELAMENTO'));
  Assert.AreEqual('E-mail', TextoTipoFila('EMAIL'));
  Assert.AreEqual('Pendente', TextoSituacaoFila('PENDENTE'));
  Assert.AreEqual('Concluído', TextoSituacaoFila('CONCLUIDO'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestesPendenciasApresentacao);

end.
