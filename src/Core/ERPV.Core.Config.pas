unit ERPV.Core.Config;

(*
  ERPV.Core.Config
  -----------------
  Le a configuracao da aplicacao a partir de um arquivo INI (System.IniFiles,
  biblioteca padrao - nunca framework de terceiros, TASK.md Secao 1
  "Bibliotecas").

  Referencias: RNF-03/04, ADR-007 (e-mail/segredos), ADR-008 (excecoes/log/
  config), docs/contrato-api-financeiro.md (formato da BaseUrl/ApiKey/
  timeout), docs/ambiente-licencas.md Secao 4 (achado do spike sobre
  THTTPClient usar milissegundos).

  Decisoes de implementacao (T09):
  - O INI guarda o timeout do Financeiro em SEGUNDOS (chave "TimeoutSegundos",
    padrao 10s, coerente com TASK.md Secao 1 "Integracao"). O THTTPClient
    (T34) espera as propriedades ConnectionTimeout/SendTimeout/ResponseTimeout
    em MILISSEGUNDOS (docs/ambiente-licencas.md Secao 4). Para nao depender de
    quem for consumir lembrar da conversao, esta unit ja expoe a propriedade
    calculada TimeoutMs (= TimeoutSegundos * 1000) em TConfiguracaoFinanceiro,
    alem do valor bruto em segundos. T34 deve usar TimeoutMs diretamente.
  - Segredos com variavel de ambiente opcional (prioridade sobre o INI),
    seguindo o padrao do ADR-007 (senha SMTP: ERPV_SMTP_PASSWORD) estendido,
    por analogia, ao ApiKey do Financeiro (ERPV_FINANCEIRO_APIKEY) e a senha
    do banco (ERPV_BANCO_SENHA). Os dois ultimos nomes de variavel nao estao
    literalmente definidos em ADR-007/008 (que so cobrem SMTP explicitamente);
    esta e uma extensao pequena e documentada aqui, seguindo o mesmo padrao
    ja aprovado (env tem prioridade, fallback pro INI), nao uma reinterpretacao
    do ADR. Se o Coordenador preferir nomes diferentes, e so ajustar as
    constantes abaixo.
  - Arquivo INI ausente, ou faltando secao/chave obrigatoria: a classe lanca
    EConfiguracao com mensagem amigavel, sem crash nao tratado. O composition
    root (T13) deve capturar EConfiguracao, mostrar a mensagem ao usuario e
    encerrar a aplicacao de forma controlada.
  - Atualizacao feita em T11: agora que ERPV.Core.Erros existe, EConfiguracao
    passa a herdar de EInfra (falha de configuracao e, na pratica, uma falha
    de infraestrutura) em vez de Exception puro. Mudanca de baixo risco: a
    API publica de EConfiguracao (construtor, mensagem) nao muda, so o
    ancestral - decisao ja prevista/documentada aqui em T09 para T11 ajustar.
  - Ajuste feito ao lado de T12/T13 (verificacao manual do usuario expos a
    inconsistencia): EConfiguracao passa a herdar de EInfraMensagemSegura
    (subclasse de EInfra, ERPV.Core.Erros) em vez de EInfra puro - a
    mensagem que esta unit monta (ValidarArquivo/ValidarSecoesObrigatorias/
    LerObrigatoria, acima) e escrita para orientar o usuario final e nao
    contem SQL/credencial, entao MensagemAmigavel agora mostra ela literal
    ao inves do texto generico usado para EInfra em geral.
*)

interface

uses
  System.SysUtils,
  System.IniFiles,
  ERPV.Core.Erros;

type
  /// <summary>Erro de configuracao: INI ausente, invalido ou faltando secao/
  /// chave obrigatoria. Herda de EInfraMensagemSegura (ERPV.Core.Erros,
  /// ajuste feito ao lado de T12/T13): e uma falha de infraestrutura, mas a
  /// mensagem do construtor (ValidarArquivo/ValidarSecoesObrigatorias/
  /// LerObrigatoria, acima) e escrita para o usuario final (orientacao de
  /// setup: "copie o arquivo .example...") e nao contem SQL/credencial -
  /// so caminho do proprio arquivo de configuracao, que e seguro de expor.
  /// MensagemAmigavel (ERPV.Core.Erros) mostra essa mensagem literal ao
  /// usuario por causa disso, ao inves do texto generico usado para EInfra
  /// em geral (ex.: falha de conexao ao banco, ERPV.Dados.Conexao).</summary>
  EConfiguracao = class(EInfraMensagemSegura);

  TConfiguracaoBanco = record
    Caminho: string;   // caminho/alias do banco Firebird (.FDB) ou host:caminho
    Usuario: string;
    Senha: string;     // resolvida: ERPV_BANCO_SENHA (env) tem prioridade sobre o INI
  end;

  TConfiguracaoFinanceiro = record
    BaseUrl: string;         // ex.: http://localhost:5000 (docs/contrato-api-financeiro.md)
    TimeoutSegundos: Integer; // valor "de negocio", como configurado no INI (padrao 10)
    ApiKey: string;          // vazio = nao envia X-Api-Key (DEC-07); resolvida via env/INI
    function TimeoutMs: Integer;
  end;

  TConfiguracaoSMTP = record
    Host: string;
    Porta: Integer;
    Usuario: string;
    Senha: string;   // resolvida: ERPV_SMTP_PASSWORD (env, ADR-007) tem prioridade sobre o INI
    UsaTLS: Boolean;
  end;

  TConfiguracaoRelatorio = record
    PastaPdfTemp: string;
  end;

  TConfiguracaoLog = record
    Pasta: string;
  end;

  /// <summary>Configuracao da aplicacao, lida de erpvendas.ini. Lanca
  /// EConfiguracao no construtor se o arquivo nao existir ou faltar secao/
  /// chave obrigatoria - nunca deixa a aplicacao seguir com configuracao
  /// incompleta.</summary>
  TConfiguracao = class
  private
    FCaminhoArquivo: string;
    FBanco: TConfiguracaoBanco;
    FFinanceiro: TConfiguracaoFinanceiro;
    FSMTP: TConfiguracaoSMTP;
    FRelatorio: TConfiguracaoRelatorio;
    FLog: TConfiguracaoLog;
    procedure ValidarArquivo(const ACaminho: string);
    procedure ValidarSecoesObrigatorias(AIni: TIniFile);
    function LerObrigatoria(AIni: TIniFile; const ASecao, AChave: string): string;
    function LerComVariavelDeAmbiente(AIni: TIniFile; const ASecao, AChave,
      ANomeVarAmbiente, APadrao: string): string;
    procedure Carregar(AIni: TIniFile);
  public
    /// <param name="ACaminhoIni">Se vazio, usa CaminhoPadrao (erpvendas.ini
    /// na pasta do executavel).</param>
    /// <exception cref="EConfiguracao">Arquivo ausente/invalido ou faltando
    /// secao/chave obrigatoria.</exception>
    constructor Create(const ACaminhoIni: string = '');

    /// <summary>Caminho padrao: erpvendas.ini na mesma pasta do executavel.</summary>
    class function CaminhoPadrao: string;

    property CaminhoArquivo: string read FCaminhoArquivo;
    property Banco: TConfiguracaoBanco read FBanco;
    property Financeiro: TConfiguracaoFinanceiro read FFinanceiro;
    property SMTP: TConfiguracaoSMTP read FSMTP;
    property Relatorio: TConfiguracaoRelatorio read FRelatorio;
    property Log: TConfiguracaoLog read FLog;
  end;

const
  // Nomes de variavel de ambiente para segredos (ver nota de decisao no
  // cabecalho). ERPV_SMTP_PASSWORD e o nome definido em ADR-007; os outros
  // dois seguem o mesmo padrao, por extensao documentada.
  ENV_BANCO_SENHA = 'ERPV_BANCO_SENHA';
  ENV_SMTP_SENHA = 'ERPV_SMTP_PASSWORD';
  ENV_FINANCEIRO_APIKEY = 'ERPV_FINANCEIRO_APIKEY';

  TIMEOUT_FINANCEIRO_PADRAO_SEGUNDOS = 10;
  SMTP_PORTA_PADRAO = 587;

implementation

{ TConfiguracaoFinanceiro }

function TConfiguracaoFinanceiro.TimeoutMs: Integer;
begin
  // Conversao documentada em docs/ambiente-licencas.md Secao 4: THTTPClient
  // (ConnectionTimeout/SendTimeout/ResponseTimeout) espera milissegundos.
  // Uso real fica para T34; aqui so garantimos que o valor certo esta pronto.
  Result := TimeoutSegundos * 1000;
end;

{ TConfiguracao }

class function TConfiguracao.CaminhoPadrao: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'erpvendas.ini';
end;

constructor TConfiguracao.Create(const ACaminhoIni: string = '');
var
  Ini: TIniFile;
begin
  inherited Create;

  if ACaminhoIni <> '' then
    FCaminhoArquivo := ACaminhoIni
  else
    FCaminhoArquivo := CaminhoPadrao;

  ValidarArquivo(FCaminhoArquivo);

  Ini := TIniFile.Create(FCaminhoArquivo);
  try
    ValidarSecoesObrigatorias(Ini);
    Carregar(Ini);
  finally
    Ini.Free;
  end;
end;

procedure TConfiguracao.ValidarArquivo(const ACaminho: string);
begin
  if not FileExists(ACaminho) then
    raise EConfiguracao.CreateFmt(
      'Arquivo de configuracao nao encontrado: "%s". Copie ' +
      'config\erpvendas.ini.example para essa pasta, ajuste os valores ' +
      '(conexao com o banco, URL do Financeiro, SMTP) e inicie o sistema ' +
      'novamente.', [ACaminho]);
end;

procedure TConfiguracao.ValidarSecoesObrigatorias(AIni: TIniFile);
const
  SECOES_OBRIGATORIAS: array[0..4] of string = ('Banco', 'Financeiro', 'SMTP', 'Relatorio', 'Log');
var
  i: Integer;
begin
  for i := Low(SECOES_OBRIGATORIAS) to High(SECOES_OBRIGATORIAS) do
    if not AIni.SectionExists(SECOES_OBRIGATORIAS[i]) then
      raise EConfiguracao.CreateFmt(
        'Configuracao invalida em "%s": secao obrigatoria "[%s]" nao ' +
        'encontrada. Verifique o arquivo comparando com ' +
        'config\erpvendas.ini.example.', [FCaminhoArquivo, SECOES_OBRIGATORIAS[i]]);
end;

function TConfiguracao.LerObrigatoria(AIni: TIniFile; const ASecao, AChave: string): string;
begin
  Result := Trim(AIni.ReadString(ASecao, AChave, ''));
  if Result = '' then
    raise EConfiguracao.CreateFmt(
      'Configuracao invalida em "%s": chave "%s" ausente ou vazia na secao ' +
      '"[%s]". Verifique o arquivo comparando com ' +
      'config\erpvendas.ini.example.', [FCaminhoArquivo, AChave, ASecao]);
end;

function TConfiguracao.LerComVariavelDeAmbiente(AIni: TIniFile; const ASecao,
  AChave, ANomeVarAmbiente, APadrao: string): string;
begin
  // Variavel de ambiente tem prioridade sobre o INI (ADR-007/008: segredo
  // nao deve ficar em texto puro no repositorio/arquivo quando evitavel).
  Result := GetEnvironmentVariable(ANomeVarAmbiente);
  if Result <> '' then
    Exit;
  Result := AIni.ReadString(ASecao, AChave, APadrao);
end;

procedure TConfiguracao.Carregar(AIni: TIniFile);
begin
  // [Banco] - conexao Firebird (ADR-002). Senha nunca obrigatoria no INI: se
  // a variavel de ambiente estiver definida, ela e usada; senao cai no valor
  // (possivelmente vazio) do INI.
  FBanco.Caminho := LerObrigatoria(AIni, 'Banco', 'Caminho');
  FBanco.Usuario := LerObrigatoria(AIni, 'Banco', 'Usuario');
  FBanco.Senha := LerComVariavelDeAmbiente(AIni, 'Banco', 'Senha', ENV_BANCO_SENHA, '');

  // [Financeiro] - integracao REST (ADR-004, contrato-api-financeiro.md).
  FFinanceiro.BaseUrl := LerObrigatoria(AIni, 'Financeiro', 'BaseUrl');
  FFinanceiro.TimeoutSegundos := AIni.ReadInteger('Financeiro', 'TimeoutSegundos',
    TIMEOUT_FINANCEIRO_PADRAO_SEGUNDOS);
  if FFinanceiro.TimeoutSegundos <= 0 then
    FFinanceiro.TimeoutSegundos := TIMEOUT_FINANCEIRO_PADRAO_SEGUNDOS;
  // ApiKey e opcional por definicao (DEC-07): vazio = nao envia X-Api-Key.
  FFinanceiro.ApiKey := LerComVariavelDeAmbiente(AIni, 'Financeiro', 'ApiKey',
    ENV_FINANCEIRO_APIKEY, '');

  // [SMTP] - envio de e-mail (ADR-007).
  FSMTP.Host := LerObrigatoria(AIni, 'SMTP', 'Host');
  FSMTP.Porta := AIni.ReadInteger('SMTP', 'Porta', SMTP_PORTA_PADRAO);
  FSMTP.Usuario := LerObrigatoria(AIni, 'SMTP', 'Usuario');
  FSMTP.Senha := LerComVariavelDeAmbiente(AIni, 'SMTP', 'Senha', ENV_SMTP_SENHA, '');
  FSMTP.UsaTLS := AIni.ReadBool('SMTP', 'UsaTLS', True);

  // [Relatorio] - pasta de PDF temporario (T47).
  FRelatorio.PastaPdfTemp := LerObrigatoria(AIni, 'Relatorio', 'PastaPdfTemp');

  // [Log] - pasta de log em arquivo (T10, ADR-008).
  FLog.Pasta := LerObrigatoria(AIni, 'Log', 'Pasta');
end;

end.
