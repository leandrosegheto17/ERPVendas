unit ERPV.Core.Log;

{
  T10 (Lote 2) — Log em arquivo por dia, com níveis e mascaramento
  automático de CPF/CNPJ/e-mail (ADR-008, RF-24, SDD §7).

  Dependência com T09 (ERPV.Core.Config) tratada como "leve" (ver TASK.md
  Seção 3, nota de concorrência do Lote 2): esta unit NÃO importa
  ERPV.Core.Config. Quem instancia TLogger (o composition root, T13)
  é responsável por ler a pasta de log do INI e passá-la aqui como string
  simples. Isso evita conflito de edição concorrente com a instância que
  está implementando T09 nesta mesma rodada.

  Formato do nome de arquivo: <pasta>\erpvendas-AAAAMMDD.log (ADR-008),
  texto UTF-8, modo append.

  Níveis (nomes conforme ADR-008): INFO, AVISO (WARN), ERRO.

  ==========================================================================
  REGRA DE OURO DESTA UNIT — NUNCA GRAVAR DADO SENSÍVEL EM TEXTO CLARO
  ==========================================================================
  - Toda mensagem passada a Info/Aviso/Erro passa OBRIGATORIAMENTE pela
    função de mascaramento (MascararSensiveis) antes de ir para o arquivo.
    Não existe um método "grava string crua sem mascarar" público nesta
    unit — isso é proposital, para que quem chama o log não consiga
    acidentalmente vazar dado sensível.
  - CPF (11 dígitos) e CNPJ (14 dígitos), formatados ou só dígitos, são
    mascarados preservando os grupos do meio e ocultando as pontas (mesmo
    padrão do exemplo do ADR-008: "***.456.789-**").
  - E-mail é mascarado preservando o primeiro caractere do usuário e o
    domínio inteiro (ex.: "usuario@dominio.com" -> "u***@dominio.com").
  - Além disso, como camada extra de proteção (não exigida como mínimo,
    mas mais robusta): qualquer trecho no padrão "chave=valor" ou
    "chave: valor" cuja chave pareça senha/apikey/token (senha, password,
    apikey, api_key, token, secret) tem o VALOR substituído por "******",
    mesmo que o chamador tenha cometido o erro de incluir isso na
    mensagem. Ainda assim: NUNCA chame o log passando senha, ApiKey ou
    corpo completo de e-mail — a mascaragem acima é uma rede de segurança,
    não uma licença para logar esses dados.
  - Falha ao gravar o log NUNCA lança exceção (ADR-008): é engolida
    silenciosamente (best effort), para não derrubar o app por causa do
    log.

  ==========================================================================
  COMO VERIFICAR MANUALMENTE NA IDE (sem testes automatizados, DEC-14)
  ==========================================================================
  1. Criar um projeto/form de teste temporário (ou usar o hello world de
     T01) com:

       uses ERPV.Core.Log;
       var
         Logger: TLogger;
       begin
         Logger := TLogger.Create('C:\Temp\logs-teste');
         try
           Logger.Info('Cliente cadastrado, CPF 12345678909');
           Logger.Info('Cliente PJ, CNPJ 11222333000181');
           Logger.Info('Contato: usuario@dominio.com');
           Logger.Aviso('Falha ao enviar e-mail, senha=Abc123 apikey=XYZ');
           Logger.Erro('Erro ao conectar', Exception.Create('SQL: SELECT * FROM X'));
         finally
           Logger.Free;
         end;
       end;

  2. Abrir `C:\Temp\logs-teste\erpvendas-AAAAMMDD.log` (data de hoje) e
     conferir:
     - CPF aparece como "***.456.789-**" (nunca "12345678909" cru).
     - CNPJ aparece como "**.222.333/0001-**" (nunca cru).
     - E-mail aparece como "u***@dominio.com" (nunca cru).
     - A linha com "senha=" mostra "senha=******" (nunca "Abc123" cru).
     - Cada linha tem timestamp, nível (INFO/AVISO/ERRO) e mensagem.
  3. Repetir no dia seguinte (ou mudando a data do Windows, só para o
     teste) e confirmar que um novo arquivo `erpvendas-<outra-data>.log`
     é criado (arquivo por dia).
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.RegularExpressions,
  System.SyncObjs;

type
  /// <summary>Níveis de log suportados (ADR-008: INFO/AVISO/ERRO).</summary>
  TNivelLog = (nlInfo, nlAviso, nlErro);

  /// <summary>
  /// Logger em arquivo por dia, com mascaramento automático de dados
  /// sensíveis (CPF/CNPJ/e-mail) e redação extra de senha/ApiKey/token.
  /// Uma instância por pasta de log; thread único (app não usa
  /// TTask/TThread no fluxo de integração, DEC-14), mas a gravação é
  /// protegida por seção crítica por precaução/robustez.
  /// </summary>
  TLogger = class
  private
    FPastaLog: string;
    FLock: TCriticalSection;
    function NomeArquivoDoDia: string;
    procedure GravarLinha(ANivel: TNivelLog; const AMensagem: string);
    function NomeNivel(ANivel: TNivelLog): string;
  public
    /// <param name="APastaLog">
    /// Pasta onde os arquivos de log diário são gravados. Passada como
    /// string simples pelo composition root (T13), que é quem lê o valor
    /// do INI via ERPV.Core.Config — esta unit não depende de Config
    /// diretamente (ver nota de dependência leve no topo do arquivo).
    /// </param>
    constructor Create(const APastaLog: string);
    destructor Destroy; override;

    /// <summary>Registra mensagem de nível informativo.</summary>
    procedure Info(const AMensagem: string);
    /// <summary>Registra mensagem de nível de aviso (situação recuperável).</summary>
    procedure Aviso(const AMensagem: string);
    /// <summary>
    /// Registra mensagem de erro. Se AExcecao for informada, sua classe e
    /// mensagem são anexadas (também passando pelo mascaramento) — nunca
    /// anexar aqui senha/ApiKey/corpo de e-mail.
    /// </summary>
    procedure Erro(const AMensagem: string; AExcecao: Exception = nil);

    /// <summary>
    /// Função pura de mascaramento, exposta como class function para
    /// permitir verificação/uso isolado (ex.: num teste manual ou futuro
    /// teste automatizado) sem precisar instanciar o logger nem tocar em
    /// disco. É a mesma função usada internamente por Info/Aviso/Erro.
    /// </summary>
    class function MascararSensiveis(const ATexto: string): string;
  end;

implementation

uses
  System.IOUtils;

{ TLogger }

constructor TLogger.Create(const APastaLog: string);
begin
  inherited Create;
  if Trim(APastaLog) = '' then
    raise EArgumentException.Create('TLogger.Create: pasta de log não pode ser vazia.');
  FPastaLog := APastaLog;
  FLock := TCriticalSection.Create;
  ForceDirectories(FPastaLog);
end;

destructor TLogger.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

function TLogger.NomeArquivoDoDia: string;
begin
  Result := TPath.Combine(FPastaLog, Format('erpvendas-%s.log', [FormatDateTime('yyyymmdd', Now)]));
end;

function TLogger.NomeNivel(ANivel: TNivelLog): string;
begin
  case ANivel of
    nlInfo:  Result := 'INFO';
    nlAviso: Result := 'AVISO';
    nlErro:  Result := 'ERRO';
  else
    Result := 'INFO';
  end;
end;

class function TLogger.MascararSensiveis(const ATexto: string): string;
var
  LTexto: string;
begin
  LTexto := ATexto;

  // 1) CNPJ formatado: 12.345.678/0001-90 -> **.345.678/0001-**
  LTexto := TRegEx.Replace(LTexto,
    '(\d{2})\.(\d{3})\.(\d{3})/(\d{4})-(\d{2})',
    '**.$2.$3/$4-**');

  // 2) CNPJ só dígitos (14 dígitos, palavra inteira): 12345678000190 -> **.345.678/0001-**
  LTexto := TRegEx.Replace(LTexto,
    '\b(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})\b',
    '**.$2.$3/$4-**');

  // 3) CPF formatado: 123.456.789-09 -> ***.456.789-**
  LTexto := TRegEx.Replace(LTexto,
    '(\d{3})\.(\d{3})\.(\d{3})-(\d{2})',
    '***.$2.$3-**');

  // 4) CPF só dígitos (11 dígitos, palavra inteira): 12345678909 -> ***.456.789-**
  LTexto := TRegEx.Replace(LTexto,
    '\b(\d{3})(\d{3})(\d{3})(\d{2})\b',
    '***.$2.$3-**');

  // 5) E-mail: usuario@dominio.com -> u***@dominio.com
  LTexto := TRegEx.Replace(LTexto,
    '\b([A-Za-z0-9._%+\-])[A-Za-z0-9._%+\-]*(@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})\b',
    '$1***$2');

  // 6) Rede de segurança extra: chave=valor ou chave: valor de
  //    senha/password/apikey/api_key/token/secret -> valor vira ******
  //    (mesmo que o chamador tenha cometido o erro de logar isso).
  LTexto := TRegEx.Replace(LTexto,
    '(?i)\b(senha|password|apikey|api_key|token|secret)\b\s*[:=]\s*\S+',
    '$1=******');

  Result := LTexto;
end;

procedure TLogger.GravarLinha(ANivel: TNivelLog; const AMensagem: string);
var
  LLinha: string;
  LArquivo: string;
  LStream: TStreamWriter;
  LMensagemMascarada: string;
begin
  // ADR-008: falha ao gravar log nunca lança exceção (best effort).
  try
    FLock.Enter;
    try
      LMensagemMascarada := MascararSensiveis(AMensagem);
      LLinha := Format('%s [%s] %s',
        [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), NomeNivel(ANivel), LMensagemMascarada]);

      LArquivo := NomeArquivoDoDia;
      ForceDirectories(ExtractFilePath(LArquivo));

      LStream := TStreamWriter.Create(LArquivo, True, TEncoding.UTF8);
      try
        LStream.WriteLine(LLinha);
      finally
        LStream.Free;
      end;
    finally
      FLock.Leave;
    end;
  except
    // Engolir propositalmente: log nunca pode derrubar a aplicação.
  end;
end;

procedure TLogger.Info(const AMensagem: string);
begin
  GravarLinha(nlInfo, AMensagem);
end;

procedure TLogger.Aviso(const AMensagem: string);
begin
  GravarLinha(nlAviso, AMensagem);
end;

procedure TLogger.Erro(const AMensagem: string; AExcecao: Exception = nil);
var
  LMensagemCompleta: string;
begin
  LMensagemCompleta := AMensagem;
  if Assigned(AExcecao) then
    LMensagemCompleta := LMensagemCompleta + ' | ' + AExcecao.ClassName + ': ' + AExcecao.Message;
  GravarLinha(nlErro, LMensagemCompleta);
end;

end.
