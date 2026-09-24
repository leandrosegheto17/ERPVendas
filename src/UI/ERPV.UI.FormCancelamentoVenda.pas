unit ERPV.UI.FormCancelamentoVenda;

(*
  T44 (Lote 10) - Dialogo de cancelamento de venda (UX-SPEC 2.6) e mensagens de
  desfecho (UX-SPEC 4.3). Herda TFormBaseEdicao (T15); 100% em codigo.

  A tela SO exibe: a regra (RN-02/08, fila, POST) e do TQuitacaoService.Cancelar
  (T43). Aqui: coleta o motivo (opcional, ate 255), confirma e traduz o
  TResultadoCancelamento em mensagem via Notificar (nada de MessageDlg).

  Uso pelas telas (T31 menu de contexto / T32 botao dentro da venda):
    if CancelarVendaComDialogo(Self, QuitacaoService, VendaId) then
      AvisarVendaCancelada(VendaId, Self);   // banner Info (UX 4.3)
  CancelarVendaComDialogo devolve True SOMENTE se a venda ficou Cancelada;
  mensagens de Aviso/Erro (modais) sao exibidas aqui. Independentemente do
  retorno, o chamador deve recarregar a lista (status pode ter mudado). O banner
  Info fica a cargo do chamador porque a tela de edicao fecha apos cancelar.

  Decisoes:
  - Botoes: "Confirmar cancelamento" (papel Perigoso, reaproveita Salvar da
    base) e "Voltar" (secundario, reaproveita Cancelar). Modificado nunca e
    marcado: Esc/Voltar fecham sem pedir descarte. Enter no campo confirma.
  - Botao Confirmar/Voltar ficam desabilitados e cursor de espera durante a
    chamada ao Financeiro (UX 4.1); dialogo fecha ao terminar.
  - dcNaoPermitida nao tem texto em UX 4.3: exibe-se a Mensagem do service
    como Aviso (interpretacao pequena, documentada).
  - Textos de "recusado/indisponivel" seguem a analogia pedida por UX 4.3
    ("mensagens acima com 'cancelamento'").
  - Erro inesperado: texto literal de UX 4.3; o log fica com o tratador de
    excecoes da aplicacao (T13) - a UI nao loga.

  ==========================================================================
  ROTEIRO MANUAL NA IDE (sem compilacao via CLI; pendente de confirmacao)
  ==========================================================================
  Pre: mock do Financeiro no ar, venda Pendente na lista.
  1. Lista de Vendas > selecionar Pendente > botao direito > "Cancelar venda":
     dialogo "Cancelar venda nº N", botao vermelho/perigoso a direita.
     Quitada/Cancelada: item do menu desabilitado.
  2. Voltar/Esc: fecha sem chamar o Financeiro (mock sem POST).
  3. Motivo "Cliente desistiu" + Confirmar (mock ok): banner info "Venda N
     cancelada."; lista mostra Cancelada; motivo gravado no banco.
  4. Mock recusa: modal Erro "Cancelamento recusado pelo Financeiro: ... A venda
     continua Pendente."; venda segue Pendente.
  5. Mock erro500/timeout/parado: modal Aviso "Financeiro indisponível. O
     cancelamento da venda N continua Pendente e foi colocado na fila..."; 1
     linha CANCELAMENTO na fila; UI nao trava alem do timeout.
  6. Abrir a venda Pendente (Editar) > "Cancelar venda" (esquerda, perigoso):
     mesmo fluxo; sucesso fecha a edicao e a lista mostra o banner.
     Quitada/Cancelada aberta como Visualizar: botao desabilitado.
  7. Teclado: Tab percorre Motivo > Confirmar > Voltar; Esc = Voltar.
  8. Sob "Motivo (opcional)": texto de apoio "Não informe dados pessoais (CPF,
     telefone, e-mail) no motivo." (RF10-03/SG8-03), legivel, sem sobreposicao.
*)

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  cxButtons, cxEdit, cxTextEdit,
  ERPV.Core.Erros,
  ERPV.Negocio.QuitacaoService,
  ERPV.UI.Tokens, ERPV.UI.Tema, ERPV.UI.FormBaseEdicao;

type
  TFormCancelamentoVenda = class(TFormBaseEdicao)
  private
    FQuitacaoService: TQuitacaoService;
    FVendaId: Integer;
    FResultado: TResultadoCancelamento;
    FMotivo: TcxTextEdit;
    procedure MontarTela;
  protected
    function Validar: Boolean; override;
  public
    constructor Create(AOwner: TComponent; AQuitacaoService: TQuitacaoService;
      AVendaId: Integer); reintroduce;
    /// <summary>Resultado do service; valido apos ShowModal = mrOk.</summary>
    property Resultado: TResultadoCancelamento read FResultado;
  end;

/// <summary>Abre o dialogo, cancela e exibe as mensagens Aviso/Erro de UX 4.3.
/// True somente se a venda ficou Cancelada (Info a cargo do chamador, ver
/// AvisarVendaCancelada). O servico e do chamador (nunca liberado aqui).</summary>
function CancelarVendaComDialogo(AOwner: TComponent;
  AQuitacaoService: TQuitacaoService; AVendaId: Integer): Boolean;

/// <summary>Banner Info "Venda N cancelada." (UX 4.3) no container informado.</summary>
procedure AvisarVendaCancelada(AVendaId: Integer; AHost: TWinControl);

implementation

const
  cAlturaLinha = 18;

{ TFormCancelamentoVenda }

constructor TFormCancelamentoVenda.Create(AOwner: TComponent;
  AQuitacaoService: TQuitacaoService; AVendaId: Integer);
begin
  inherited Create(AOwner);
  if AQuitacaoService = nil then
    raise EArgumentException.Create('TFormCancelamentoVenda: serviço não informado.');
  FQuitacaoService := AQuitacaoService;
  FVendaId := AVendaId;
  Caption := Format('Cancelar venda nº %d', [AVendaId]);
  MontarTela;
end;

procedure TFormCancelamentoVenda.MontarTela;
var
  L, Apoio: TLabel;
begin
  PnlCampos.AutoSize := False;
  ClientHeight := EscalarPx(160);

  // Botoes (UX 2.6): Confirmar cancelamento = perigoso; Voltar = secundario.
  BtnSalvar.Caption := 'Confirmar cancelamento';
  BtnSalvar.Width := EscalarPx(190);
  EstilizarBotao(BtnSalvar, upbPerigoso);
  BtnCancelar.Caption := 'Voltar';
  // Forca o LayoutRodape da base com as larguras novas (OnResize).
  ClientWidth := EscalarPx(560);

  L := TLabel.Create(Self);
  L.Parent := PnlCampos;
  L.AutoSize := False;
  L.Align := alTop;
  L.Height := EscalarPx(cAlturaLinha);
  L.Layout := tlCenter;
  L.Caption := 'Motivo (opcional)';
  L.Font.Name := ERPVFontePrincipal;
  L.Font.Size := ERPVTamRotuloCampo;
  L.Font.Style := [fsBold];
  L.Font.Color := clERPVTextoPrincipal;

  // Texto de apoio LGPD (SG8-03): nao digitar dado pessoal no motivo.
  Apoio := TLabel.Create(Self);
  Apoio.Parent := PnlCampos;
  Apoio.AutoSize := False;
  Apoio.WordWrap := True;
  Apoio.Align := alTop;
  Apoio.Top := EscalarPx(cAlturaLinha);
  Apoio.Height := EscalarPx(cAlturaLinha);
  Apoio.Layout := tlCenter;
  Apoio.Caption := 'Não informe dados pessoais (CPF, telefone, e-mail) no motivo.';
  Apoio.Font.Name := ERPVFontePrincipal;
  Apoio.Font.Size := ERPVTamCorpo;
  Apoio.Font.Color := clERPVTextoSecundario;

  FMotivo := TcxTextEdit.Create(Self);
  FMotivo.Parent := PnlCampos;
  FMotivo.Align := alTop;
  FMotivo.Properties.MaxLength := 255; // MOTIVO_CANCELAMENTO VARCHAR(255)
  FMotivo.Top := EscalarPx(cAlturaLinha * 2);
  L.FocusControl := FMotivo;
  FMotivo.TabOrder := 0;
  ActiveControl := FMotivo;
end;

function TFormCancelamentoVenda.Validar: Boolean;
begin
  // "Validar" da base = executa o cancelamento; True fecha (mrOk).
  Result := False;
  BtnSalvar.Enabled := False;
  BtnCancelar.Enabled := False;
  FMotivo.Enabled := False;
  Screen.Cursor := crHourGlass;
  try
    try
      FResultado := FQuitacaoService.Cancelar(FVendaId, FMotivo.Text);
      Result := True;
    except
      on E: Exception do
      begin
        Screen.Cursor := crDefault;
        if E is EErpVendas then
          Notificar(utnErro, E.Message)
        else
          Notificar(utnErro,
            'Ocorreu um erro inesperado. Os detalhes foram gravados no log.');
      end;
    end;
  finally
    Screen.Cursor := crDefault;
    if not Result then
    begin
      BtnSalvar.Enabled := True;
      BtnCancelar.Enabled := True;
      FMotivo.Enabled := True;
    end;
  end;
end;

{ ---- funcoes de fluxo ---- }

function CancelarVendaComDialogo(AOwner: TComponent;
  AQuitacaoService: TQuitacaoService; AVendaId: Integer): Boolean;
var
  Tela: TFormCancelamentoVenda;
  Res: TResultadoCancelamento;
  Detalhe: string;
begin
  Result := False;
  Tela := TFormCancelamentoVenda.Create(AOwner, AQuitacaoService, AVendaId);
  try
    if Tela.ShowModal <> mrOk then
      Exit;
    Res := Tela.Resultado;
  finally
    Tela.Free;
  end;

  // UX 4.3: Info = banner (chamador); Aviso/Erro = modal via Notificar.
  Detalhe := Trim(Res.Mensagem);
  case Res.Desfecho of
    dcCancelada:
      Result := True;
    dcRecusada:
      begin
        if Detalhe <> '' then
          Detalhe := ': ' + Detalhe
        else
          Detalhe := '';
        Notificar(utnErro, 'Cancelamento recusado pelo Financeiro' + Detalhe +
          '. A venda continua Pendente.');
      end;
    dcEnfileirada:
      Notificar(utnAviso, Format('Financeiro indisponível. O cancelamento da ' +
        'venda %d foi colocado na fila e a venda continua Pendente. ' +
        'Tente novamente em Pendências.', [AVendaId]));
    dcRespostaInvalida:
      Notificar(utnErro,
        'Resposta inesperada do Financeiro. Venda mantida como Pendente.');
    dcNaoPermitida:
      if Detalhe <> '' then
        Notificar(utnAviso, Detalhe)
      else
        Notificar(utnAviso, 'A venda não pode ser cancelada.');
  end;
end;

procedure AvisarVendaCancelada(AVendaId: Integer; AHost: TWinControl);
begin
  Notificar(utnInfo, Format('Venda %d cancelada.', [AVendaId]), AHost);
end;

end.
