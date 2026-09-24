unit ERPV.UI.PendenciasApresentacao;

(*
  T52 - Logica de apresentacao pura da tela de Pendencias (UX-SPEC 2.7),
  sem VCL: textos de tipo/situacao, subtitulo e mensagens de resultado do
  reenvio. Testavel sem UI (ver tests\ERPV.Testes.PendenciasApresentacao).
  Nao loga nem monta texto com dado pessoal; o erro vem ja mascarado do
  FilaService/FilaRepository (RF9-05).
*)

interface

uses
  System.SysUtils,
  ERPV.Negocio.FilaService;

type
  /// <summary>Mensagem a exibir e se e sucesso (Info) ou falha.</summary>
  TMensagemReenvio = record
    Texto: string;
    Sucesso: Boolean;
  end;

  /// <summary>T53 (UX 4.2): habilitacao dos botoes da lista de vendas.
  /// Visualizar = Editar vira "Visualizar" (mesma tela, somente leitura).</summary>
  TAcoesVenda = record
    EditarExcluir: Boolean;
    Visualizar: Boolean;
    Confirmar: Boolean;
    Cancelar: Boolean;
  end;

const
  MSG_PENDENCIAS_VAZIO = 'Nenhuma pendência.';
  TEXTO_SINC = '(!)';
  HINT_SINC = 'Sincronização pendente';
  HINT_PENDENCIAS_STATUS = 'Abrir Pendências de Integração';

/// <summary>Texto da status bar; o texto acompanha sempre o icone (UX 5).</summary>
function TextoPendenciasStatus(ATotal: Integer): string;
/// <summary>Chip "N" da navegacao: vazio se N &lt;= 0 (so aparece se N &gt; 0).</summary>
function TextoChipPendencias(ATotal: Integer): string;
/// <summary>Coluna Sinc: "(!)" se a venda tem QUITACAO/CANCELAMENTO pendente.</summary>
function TextoSincVenda(ATemFilaPendente: Boolean): string;
/// <summary>UX 4.2. AStatus = Pendente/Quitada/Cancelada (texto da lista).</summary>
function AcoesDaVenda(const AStatus: string; ATemFilaPendente,
  ATemQuitacaoService: Boolean): TAcoesVenda;

function TextoTipoFila(const ATipo: string): string;
function TextoSituacaoFila(const AStatus: string): string;
/// <summary>RF13-01: so item com STATUS PENDENTE pode ser reenviado.</summary>
function PodeReenviarItem(const AStatus: string): Boolean;
function SubtituloPendencias(ATotal: Integer; ASomentePendentes: Boolean): string;
function MensagemDeReenvio(const AResultado: TResultadoReenvio): TMensagemReenvio;

implementation

function TextoPendenciasStatus(ATotal: Integer): string;
begin
  if ATotal < 0 then
    ATotal := 0;
  Result := 'Pendências: ' + IntToStr(ATotal);
end;

function TextoChipPendencias(ATotal: Integer): string;
begin
  if ATotal <= 0 then
    Result := ''
  else if ATotal > 99 then
    Result := '99+'
  else
    Result := IntToStr(ATotal);
end;

function TextoSincVenda(ATemFilaPendente: Boolean): string;
begin
  if ATemFilaPendente then
    Result := TEXTO_SINC
  else
    Result := '';
end;

function AcoesDaVenda(const AStatus: string; ATemFilaPendente,
  ATemQuitacaoService: Boolean): TAcoesVenda;
var
  Pendente: Boolean;
begin
  Pendente := SameText(AStatus, 'Pendente');
  Result.EditarExcluir := Pendente and not ATemFilaPendente;
  // Sem selecao/status vazio nao visualiza; Pendente com fila abre so leitura.
  Result.Visualizar := (AStatus <> '') and not Result.EditarExcluir;
  Result.Confirmar := Result.EditarExcluir and ATemQuitacaoService;
  Result.Cancelar := Result.EditarExcluir and ATemQuitacaoService;
end;

function TextoTipoFila(const ATipo: string): string;
begin
  if SameText(ATipo, 'QUITACAO') then
    Result := 'Quitação'
  else if SameText(ATipo, 'CANCELAMENTO') then
    Result := 'Cancelamento'
  else if SameText(ATipo, 'EMAIL') then
    Result := 'E-mail'
  else
    Result := ATipo;
end;

function TextoSituacaoFila(const AStatus: string): string;
begin
  if SameText(AStatus, 'PENDENTE') then
    Result := 'Pendente'
  else if SameText(AStatus, 'CONCLUIDO') then
    Result := 'Concluído'
  else
    Result := AStatus;
end;

function PodeReenviarItem(const AStatus: string): Boolean;
begin
  Result := SameText(AStatus, 'PENDENTE');
end;

function SubtituloPendencias(ATotal: Integer; ASomentePendentes: Boolean): string;
begin
  if ASomentePendentes then
  begin
    if ATotal = 1 then
      Result := '1 item aguardando reenvio'
    else
      Result := Format('%d itens aguardando reenvio', [ATotal]);
  end
  else
  begin
    if ATotal = 1 then
      Result := '1 item'
    else
      Result := Format('%d itens', [ATotal]);
  end;
end;

function MensagemDeReenvio(const AResultado: TResultadoReenvio): TMensagemReenvio;
begin
  Result.Sucesso := AResultado.Concluiu;
  if AResultado.Concluiu then
    Result.Texto := 'Item concluído.'
  else if AResultado.Mensagem <> '' then
    Result.Texto := 'Ainda não foi possível: ' + AResultado.Mensagem
  else
    Result.Texto := 'Ainda não foi possível reenviar este item.';
end;

end.
