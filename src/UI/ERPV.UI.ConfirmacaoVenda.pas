unit ERPV.UI.ConfirmacaoVenda;

{
  T42 (Lote 9) - Fluxo de UI "Confirmar venda" (quitacao), compartilhado pela
  lista (T31) e pela edicao (T32) de venda. Form fino: sem SQL/HTTP/regra;
  so pergunta, espera visual e traducao do desfecho em mensagem (UX-SPEC 4.3).

  Fluxo de ConfirmarVendaComFeedback:
    1. Notificar(utnPergunta) "Confirmar a venda N (R$ x)? Esta acao envia a
       quitacao ao Financeiro."  Nao => False, nada feito.
    2. Cursor crHourGlass + controles desabilitados + texto "Aguardando
       Financeiro..." no rotulo de espera; Update/ProcessMessages pontual forca
       o repaint (chamada sincrona, DEC-14, sem threads).
    3. TQuitacaoService.Confirmar; no finally: cursor, controles e rotulo
       restaurados (a UI volta a ser utilizavel mesmo com excecao).
    4. Desfecho -> Notificar (Info=banner; Aviso/Erro=modal):
         qdSucesso        Info  "Venda N quitada."
         qdIndisponivel   Aviso "Financeiro indisponivel. A venda N continua
                                Pendente e foi colocada na fila. Tente novamente
                                em Pendencias."
         qdRecusado       Erro  "Quitacao recusada pelo Financeiro: <msg>. A venda
                                continua Pendente."
         qdRespostaInvalida Erro "Resposta inesperada do Financeiro. Venda
                                mantida como Pendente."
       Excecao (ERegraNegocio/EInfra/inesperada): relancada apos restaurar a UI;
       o handler global (TTratadorDeExcecoes) grava log e mostra a mensagem
       ("Ocorreu um erro inesperado. Os detalhes foram gravados no log.").
    Retorna True somente em qdSucesso (chamador recarrega/fecha).

  Limitacao conhecida: a parte "Relatorio enviado para <email>" (e o Aviso
  "e-mail nao pode ser enviado") depende de T49 (PDF/e-mail), ainda inexistente
  no TResultadoQuitacao; por ora o sucesso mostra so "Venda N quitada.".

  ==========================================================================
  ROTEIRO MANUAL NA IDE (sem compilacao via CLI; pendente de confirmacao)
  ==========================================================================
  Pre: mock do Financeiro no ar, INI apontando para ele, venda Pendente na
  lista de Vendas (botao "Confirmar" na barra de filtros) e dentro da edicao.
  1. Mock ok: selecionar venda Pendente > Confirmar > pergunta com Nº e total
     em R$ > Sim: cursor de espera, botoes desabilitados, "Aguardando
     Financeiro..." visivel; ao voltar, banner "Venda N quitada."; a linha
     passa a Quitada e Confirmar/Editar/Excluir ficam desabilitados.
  2. Mock recusa: modal de erro "Quitação recusada pelo Financeiro: <msg>. A
     venda continua Pendente."; venda segue Pendente; botoes reabilitados.
  3. Mock erro500: modal de aviso "Financeiro indisponível. A venda N continua
     Pendente e foi colocada na fila. Tente novamente em Pendências."; UI
     utilizavel.
  4. Mock timeout: idem 3, apos o timeout (~10 s) com "Aguardando..." visivel
     o tempo todo (janela nao responde a cliques nesse periodo: sincrono).
  5. Extra: Confirmar de venda ja quitada por outra via => ERegraNegocio pelo
     handler global; UI restaurada. Responder "Nao" na pergunta => nada ocorre.
  6. Mesmos passos na tela de edicao (botao "Confirmar venda" no cabecalho);
     sucesso fecha a edicao (mrOk) e a lista recarrega.
}

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  ERPV.Negocio.QuitacaoService;

type
  /// <summary>Controles a desabilitar durante a espera e rotulo (opcional) onde
  /// aparece "Aguardando Financeiro...".</summary>
  TControlesEspera = record
    Desabilitar: TArray<TControl>;
    Rotulo: TLabel;
  end;

/// <summary>Pergunta, aguarda e apresenta o desfecho. True = venda quitada.</summary>
function ConfirmarVendaComFeedback(AServico: TQuitacaoService; AVendaId: Integer;
  ATotal: Currency; const AEspera: TControlesEspera;
  AOwnerBanner: TWinControl = nil): Boolean;

/// <summary>Texto literal (UX 4.3) por desfecho; exposto para teste.</summary>
function TextoDesfechoQuitacao(const AResultado: TResultadoQuitacao;
  AVendaId: Integer): string;

implementation

uses
  ERPV.UI.Tema;

const
  MSG_AGUARDANDO = 'Aguardando Financeiro...';

function TextoDesfechoQuitacao(const AResultado: TResultadoQuitacao;
  AVendaId: Integer): string;
begin
  case AResultado.Desfecho of
    qdSucesso:
      Result := Format('Venda %d quitada.', [AVendaId]);
    qdIndisponivel:
      Result := Format('Financeiro indisponível. A venda %d continua Pendente e ' +
        'foi colocada na fila. Tente novamente em Pendências.', [AVendaId]);
    qdRecusado:
      Result := 'Quitação recusada pelo Financeiro: ' + AResultado.Mensagem +
        '. A venda continua Pendente.';
  else
    Result := 'Resposta inesperada do Financeiro. Venda mantida como Pendente.';
  end;
end;

function ConfirmarVendaComFeedback(AServico: TQuitacaoService; AVendaId: Integer;
  ATotal: Currency; const AEspera: TControlesEspera;
  AOwnerBanner: TWinControl): Boolean;
var
  FS: TFormatSettings;
  Resultado: TResultadoQuitacao;
  Estados: TArray<Boolean>;
  CursorAnterior: TCursor;
  TextoAnterior: string;
  I: Integer;
begin
  Result := False;
  FS := TFormatSettings.Create('pt-BR');
  if not Notificar(utnPergunta, Format(
    'Confirmar a venda %d (R$ %s)? Esta ação envia a quitação ao Financeiro.',
    [AVendaId, FormatCurr(',0.00', ATotal, FS)])) then
    Exit;

  SetLength(Estados, Length(AEspera.Desabilitar));
  for I := 0 to High(AEspera.Desabilitar) do
  begin
    Estados[I] := AEspera.Desabilitar[I].Enabled;
    AEspera.Desabilitar[I].Enabled := False;
  end;
  CursorAnterior := Screen.Cursor;
  TextoAnterior := '';
  if AEspera.Rotulo <> nil then
  begin
    TextoAnterior := AEspera.Rotulo.Caption;
    AEspera.Rotulo.Caption := MSG_AGUARDANDO;
    AEspera.Rotulo.Visible := True;
    AEspera.Rotulo.Update; // repaint antes da chamada sincrona (DEC-14)
  end;
  Screen.Cursor := crHourGlass;
  try
    Application.ProcessMessages; // pontual: pinta o estado de espera
    Resultado := AServico.Confirmar(AVendaId);
  finally
    Screen.Cursor := CursorAnterior;
    for I := 0 to High(AEspera.Desabilitar) do
      AEspera.Desabilitar[I].Enabled := Estados[I];
    if AEspera.Rotulo <> nil then
    begin
      AEspera.Rotulo.Caption := TextoAnterior;
      AEspera.Rotulo.Visible := False;
    end;
  end;

  case Resultado.Desfecho of
    qdSucesso:
      Notificar(utnInfo, TextoDesfechoQuitacao(Resultado, AVendaId), AOwnerBanner);
    qdIndisponivel:
      Notificar(utnAviso, TextoDesfechoQuitacao(Resultado, AVendaId));
  else
    Notificar(utnErro, TextoDesfechoQuitacao(Resultado, AVendaId));
  end;
  Result := Resultado.Desfecho = qdSucesso;
end;

end.
