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
    /// <summary>True quando concluiu com ressalva (e-mail nao saiu).
    /// So relevante com Sucesso = True; a tela usa tom de aviso.</summary>
    Aviso: Boolean;
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
/// <summary>RF14-03: True se ULTIMO_ERRO e o 401 de configuracao da chave
/// (texto fixo do FinanceiroClient, D3), nao uma recusa de negocio.</summary>
function ErroEhConfiguracaoApiKey(const AUltimoErro: string): Boolean;
/// <summary>RF14-03: texto da coluna "Ultimo erro"; 401 de chave recebe o
/// prefixo "Configuração: " para distinguir de falha/recusa de negocio.</summary>
function TextoUltimoErro(const AUltimoErro: string): string;
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

function ErroEhConfiguracaoApiKey(const AUltimoErro: string): Boolean;
begin
  Result := Pos('X-Api-Key', AUltimoErro) > 0;
end;

function TextoUltimoErro(const AUltimoErro: string): string;
begin
  if ErroEhConfiguracaoApiKey(AUltimoErro) then
    Result := 'Configuração: ' + AUltimoErro
  else
    Result := AUltimoErro;
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
var
  Msg: string;
begin
  Result.Sucesso := AResultado.Concluiu;
  Result.Aviso := False;
  if AResultado.Concluiu then
  begin
    if AResultado.Mensagem <> '' then
    begin
      Result.Texto := AResultado.Mensagem;
      // Regra por substring (fragil: acompanha os textos de TFilaService.ConcluirLocal).
      Msg := LowerCase(AResultado.Mensagem);
      Result.Aviso := (Pos('e-mail pendente', Msg) > 0) or
        (Pos('não foi possível', Msg) > 0) or (Pos('nao foi possivel', Msg) > 0);
    end
    else
      Result.Texto := 'Item concluído.';
  end
  else if AResultado.Mensagem <> '' then
    Result.Texto := 'Ainda não foi possível: ' + AResultado.Mensagem
  else
    Result.Texto := 'Ainda não foi possível reenviar este item.';
end;

end.
