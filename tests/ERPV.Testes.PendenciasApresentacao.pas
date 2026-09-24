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
    // T53
    [Test] procedure Status_TextoSempreComN;
    [Test] procedure Chip_SoAparecePositivo_E_Satura;
    [Test] procedure Sinc_ParenteseExclamacaoSoComFila;
    [Test] procedure Acoes_PendenteSemFila_LiberaTudo;
    [Test] procedure Acoes_PendenteComFila_BloqueiaEditarConfirmarCancelar;
    [Test] procedure Acoes_QuitadaCancelada_SoVisualizar;
    [Test] procedure Acoes_SemQuitacaoService_BloqueiaConfirmarCancelar;
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

procedure TTestesPendenciasApresentacao.Status_TextoSempreComN;
begin
  Assert.AreEqual('Pendências: 0', TextoPendenciasStatus(0));
  Assert.AreEqual('Pendências: 2', TextoPendenciasStatus(2));
  Assert.AreEqual('Pendências: 0', TextoPendenciasStatus(-1));
end;

procedure TTestesPendenciasApresentacao.Chip_SoAparecePositivo_E_Satura;
begin
  Assert.AreEqual('', TextoChipPendencias(0));
  Assert.AreEqual('1', TextoChipPendencias(1));
  Assert.AreEqual('99', TextoChipPendencias(99));
  Assert.AreEqual('99+', TextoChipPendencias(100));
end;

procedure TTestesPendenciasApresentacao.Sinc_ParenteseExclamacaoSoComFila;
begin
  Assert.AreEqual('(!)', TextoSincVenda(True));
  Assert.AreEqual('', TextoSincVenda(False));
end;

procedure TTestesPendenciasApresentacao.Acoes_PendenteSemFila_LiberaTudo;
var
  A: TAcoesVenda;
begin
  A := AcoesDaVenda('Pendente', False, True);
  Assert.IsTrue(A.EditarExcluir);
  Assert.IsTrue(A.Confirmar);
  Assert.IsTrue(A.Cancelar);
  Assert.IsFalse(A.Visualizar);
end;

procedure TTestesPendenciasApresentacao.Acoes_PendenteComFila_BloqueiaEditarConfirmarCancelar;
var
  A: TAcoesVenda;
begin
  A := AcoesDaVenda('Pendente', True, True);
  Assert.IsFalse(A.EditarExcluir);
  Assert.IsFalse(A.Confirmar);
  Assert.IsFalse(A.Cancelar);
  Assert.IsTrue(A.Visualizar);
  // apos reenvio ok (fila vazia) libera de novo
  A := AcoesDaVenda('Pendente', False, True);
  Assert.IsTrue(A.EditarExcluir and A.Confirmar and A.Cancelar);
end;

procedure TTestesPendenciasApresentacao.Acoes_QuitadaCancelada_SoVisualizar;
var
  A: TAcoesVenda;
begin
  A := AcoesDaVenda('Quitada', False, True);
  Assert.IsFalse(A.EditarExcluir or A.Confirmar or A.Cancelar);
  Assert.IsTrue(A.Visualizar);
  A := AcoesDaVenda('Cancelada', False, True);
  Assert.IsFalse(A.EditarExcluir or A.Confirmar or A.Cancelar);
  Assert.IsTrue(A.Visualizar);
end;

procedure TTestesPendenciasApresentacao.Acoes_SemQuitacaoService_BloqueiaConfirmarCancelar;
var
  A: TAcoesVenda;
begin
  A := AcoesDaVenda('Pendente', False, False);
  Assert.IsTrue(A.EditarExcluir);
  Assert.IsFalse(A.Confirmar);
  Assert.IsFalse(A.Cancelar);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestesPendenciasApresentacao);

end.
