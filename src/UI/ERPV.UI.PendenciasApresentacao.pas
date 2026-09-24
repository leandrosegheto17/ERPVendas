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

const
  MSG_PENDENCIAS_VAZIO = 'Nenhuma pendência.';

function TextoTipoFila(const ATipo: string): string;
function TextoSituacaoFila(const AStatus: string): string;
function SubtituloPendencias(ATotal: Integer; ASomentePendentes: Boolean): string;
function MensagemDeReenvio(const AResultado: TResultadoReenvio): TMensagemReenvio;

implementation

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
