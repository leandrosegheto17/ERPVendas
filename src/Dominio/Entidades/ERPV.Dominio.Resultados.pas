unit ERPV.Dominio.Resultados;

{
  Resultados tipados do Domínio (T08, Lote 2; TASK.md Seção 1
  "Integração"). Usados no lugar de exceção para falha esperada de
  integração externa (Financeiro/e-mail) — exceção continua reservada para
  o inesperado (ADR-008, ERPV.Core.Erros, T11).

  Unit pura, sem Vcl/FireDAC/System.Net/Id* (ADR-001/010): não referencia
  THTTPClient/TIdSMTP, só descreve o "formato do resultado" que
  IFinanceiroGateway/IEmailSender devolvem. Sem biblioteca de "Result type"
  de terceiros (proibido em TASK.md Seção 1 "Bibliotecas") — record +
  enum é a opção idiomática em Object Pascal sem framework externo.
}

interface

uses
  System.SysUtils,
  ERPV.Dominio.Enums;

type
  /// <summary>Categoria do resultado de uma chamada ao Financeiro
  /// (docs/contrato-api-financeiro.md §1.5): Sucesso (200), Recusado
  /// (4xx — não reenfileira, RN-08), Indisponivel (5xx/timeout/erro de
  /// rede — reenfileira, RN-08), RespostaInvalida (200 com corpo
  /// não-parseável ou campo obrigatório ausente / status fora do enum).</summary>
  TCategoriaResultadoFinanceiro = (rfSucesso, rfRecusado, rfIndisponivel, rfRespostaInvalida);

  /// <summary>Resultado tipado de IFinanceiroGateway. Um único formato
  /// serve às 3 rotas (quitação/cancelamento/GET status); cada operação só
  /// preenche os campos que fazem sentido para ela (ex.: DataQuitacao só
  /// na quitação bem-sucedida).</summary>
  TResultadoFinanceiro = record
    Categoria: TCategoriaResultadoFinanceiro;
    /// <summary>Código HTTP retornado, quando houve resposta (0 quando
    /// não aplicável — timeout/erro de rede antes de qualquer resposta).</summary>
    CodigoHttp: Integer;
    /// <summary>Mensagem amigável (corpo de erro do Financeiro quando
    /// existir, senão fallback "... (código HTTP xxx)" — ADR-004).</summary>
    Mensagem: string;
    /// <summary>Status devolvido pelo Financeiro quando Categoria =
    /// rfSucesso (quitação/cancelamento/GET status).</summary>
    Status: TStatusVenda;
    /// <summary>Preenchido só no sucesso da quitação.</summary>
    DataQuitacao: TDateTime;
    class function Sucesso(AStatus: TStatusVenda; ADataQuitacao: TDateTime = 0): TResultadoFinanceiro; static;
    class function Recusado(ACodigoHttp: Integer; const AMensagem: string): TResultadoFinanceiro; static;
    class function Indisponivel(ACodigoHttp: Integer; const AMensagem: string): TResultadoFinanceiro; static;
    class function RespostaInvalida(const AMensagem: string): TResultadoFinanceiro; static;
    function EhSucesso: Boolean; inline;
  end;

  /// <summary>Resultado tipado de IEmailSender (T48): sem exceção para
  /// falha esperada de SMTP (senha errada, host indisponível etc.) —
  /// TASK.md Seção 1 "Integração".</summary>
  TResultadoEnvioEmail = record
    Sucesso: Boolean;
    MensagemErro: string;
    class function Ok: TResultadoEnvioEmail; static;
    class function Falha(const AMensagemErro: string): TResultadoEnvioEmail; static;
  end;

implementation

class function TResultadoFinanceiro.Sucesso(AStatus: TStatusVenda; ADataQuitacao: TDateTime): TResultadoFinanceiro;
begin
  Result.Categoria := rfSucesso;
  Result.CodigoHttp := 200;
  Result.Mensagem := '';
  Result.Status := AStatus;
  Result.DataQuitacao := ADataQuitacao;
end;

class function TResultadoFinanceiro.Recusado(ACodigoHttp: Integer; const AMensagem: string): TResultadoFinanceiro;
begin
  Result.Categoria := rfRecusado;
  Result.CodigoHttp := ACodigoHttp;
  Result.Mensagem := AMensagem;
  Result.Status := svPendente;
  Result.DataQuitacao := 0;
end;

class function TResultadoFinanceiro.Indisponivel(ACodigoHttp: Integer; const AMensagem: string): TResultadoFinanceiro;
begin
  Result.Categoria := rfIndisponivel;
  Result.CodigoHttp := ACodigoHttp;
  Result.Mensagem := AMensagem;
  Result.Status := svPendente;
  Result.DataQuitacao := 0;
end;

class function TResultadoFinanceiro.RespostaInvalida(const AMensagem: string): TResultadoFinanceiro;
begin
  Result.Categoria := rfRespostaInvalida;
  Result.CodigoHttp := 0;
  Result.Mensagem := AMensagem;
  Result.Status := svPendente;
  Result.DataQuitacao := 0;
end;

function TResultadoFinanceiro.EhSucesso: Boolean;
begin
  Result := Categoria = rfSucesso;
end;

class function TResultadoEnvioEmail.Ok: TResultadoEnvioEmail;
begin
  Result.Sucesso := True;
  Result.MensagemErro := '';
end;

class function TResultadoEnvioEmail.Falha(const AMensagemErro: string): TResultadoEnvioEmail;
begin
  Result.Sucesso := False;
  Result.MensagemErro := AMensagemErro;
end;

end.
