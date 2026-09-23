unit ERPV.Dados.Conexao;

{
  T12 (Lote 2) - Conexao FireDAC/Firebird via INI, helper de transacao e
  mapeamento de falha de banco para EInfra (ADR-002, RF-25).

  Depende de (ja implementadas, Concluidas): T03 (db/01_schema.sql,
  ERPVENDAS.FDB), T09 (ERPV.Core.Config - le [Banco] do INI), T11
  (ERPV.Core.Erros - hierarquia de excecoes / EInfra).

  ==========================================================================
  RESPONSABILIDADE DESTA UNIT
  ==========================================================================
  - Encapsular um TFDConnection configurado para Firebird 3 (driver FB via
    FireDAC.Phys.FB) a partir de TConfiguracaoBanco (ERPV.Core.Config,
    secao [Banco] do INI: Caminho/Usuario/Senha).
  - Expor a conexao (property Connection) para os repositorios FireDAC das
    proximas tarefas (T17 ClienteRepository, T21 ProdutoRepository, T25
    VendaRepository, T37 FilaRepository etc.) consumirem via DI por
    construtor - esta unit NAO decide quando abrir transacao de negocio,
    so oferece o mecanismo (IniciarTransacao/Confirmar/Desfazer).
  - Traduzir QUALQUER falha do FireDAC/Firebird (banco offline, senha
    errada, arquivo .FDB inexistente, timeout, falha de commit/rollback)
    em EInfra (ERPV.Core.Erros), com mensagem amigavel para o usuario
    (sem SQL, sem caminho de arquivo, sem credencial) e o detalhe tecnico
    completo (mensagem original do FireDAC, incluindo Database/host/erro
    nativo) gravado no log via TLogger recebido no construtor.

  ==========================================================================
  DI MANUAL POR CONSTRUTOR (composition root e T13, ainda nao existe)
  ==========================================================================
  TConexao.Create recebe TConfiguracao (T09) e TLogger (T10) JA PRONTOS -
  esta unit nunca instancia nenhum dos dois sozinha. Quem monta isso e o
  composition root (T13, src/App/ERPV.App.Root), que tambem e responsavel
  por manter TConexao viva durante a vida da aplicacao e libera-la (Free)
  no encerramento, e por decidir o que fazer quando o construtor levantar
  EInfra (mostrar mensagem amigavel e encerrar a aplicacao de forma
  controlada, mesmo padrao usado para EConfiguracao).

  Exemplo de uso esperado no composition root (T13), so para referencia -
  NAO implementado aqui:

    Config := TConfiguracao.Create;
    Logger := TLogger.Create(Config.Log.Pasta);
    try
      Conexao := TConexao.Create(Config, Logger);
    except
      on E: EInfra do
      begin
        MessageDlg(MensagemAmigavel(E), mtError, [mbOK], 0);
        Application.Terminate;
        Exit;
      end;
    end;
    // ClienteRepo := TClienteRepository.Create(Conexao, Logger); (T17)

  ==========================================================================
  DECISOES DE IMPLEMENTACAO
  ==========================================================================
  - Modo de conexao (ADR-002: "Connection: modo embedded/servidor via INI"):
    TConfiguracaoBanco (T09) so expoe "Caminho" (caminho/alias do .FDB),
    sem campos separados de host/porta - a mesma chave "Caminho" serve
    tanto para caminho local (conexao embedded, fbclient.dll local - modo
    de deploy descrito no SDD, Secao de empacotamento) quanto para um
    alias/"host:caminho" caso o ambiente use Firebird como servico
    (Classic/SuperServer). O parametro "Database" do FireDAC aceita os dois
    formatos (Firebird resolve embedded vs. rede pela propria string de
    conexao / presenca de servidor). Nao criamos aqui um campo adicional de
    Servidor/Porta no INI - se isso vier a ser necessario, e ajuste pequeno
    em TConfiguracaoBanco (T09) e nesta unit, sinalizado ao Coordenador se
    o UX/infra exigir suporte explicito a servidor remoto.
  - "CharacterSet=UTF8" fixo nos parametros de conexao, coerente com
    "Firebird 3.0, charset UTF8" (ADR-002 / SDD).
  - LoginPrompt sempre False: usuario/senha vem exclusivamente do INI (ou
    da variavel de ambiente ERPV_BANCO_SENHA, ja resolvida por
    ERPV.Core.Config) - a aplicacao nunca deve exibir o dialogo padrao do
    FireDAC pedindo credencial.
  - O construtor JA TENTA CONECTAR (chama Conectar internamente). Isso
    cumpre o criterio de aceite direto - "App conecta ao banco criado por
    T03" fica garantido assim que o composition root instanciar TConexao
    com sucesso; "banco offline ou senha errada => mensagem amigavel" fica
    garantido porque qualquer falha aqui vira EInfra antes de propagar.
  - Helper de transacao (IniciarTransacao/Confirmar/Desfazer): nomes em
    portugues, semantica de StartTransaction/Commit/Rollback do
    TFDConnection. Quem usa (repositorios) e responsavel por envolver a
    sequencia de comandos SQL num try/except e chamar Desfazer no except -
    esta unit so oferece o mecanismo, nao decide a extensao logica da
    transacao (isso e responsabilidade de quem grava, ex.: T25
    VendaRepository: mestre+itens na mesma transacao).
  - Desfazer (rollback) NUNCA relanca excecao: se o proprio rollback falhar
    (ex.: conexao ja caiu), o erro e apenas logado (best effort), para nao
    mascarar a excecao original que motivou o rollback no bloco except de
    quem chamou.
  - SQL nunca e concatenado nesta unit (nao ha SQL aqui - so conexao e
    controle de transacao; os repositorios das proximas tarefas e que
    devem usar TFDQuery com parametros, nunca concatenacao).

  ==========================================================================
  ROTEIRO DE VERIFICACAO MANUAL NA IDE (sem testes automatizados, DEC-14)
  ==========================================================================
  Pre-requisitos: banco criado por T03 (db/01_schema.sql executado num
  ERPVENDAS.FDB local, Firebird 3 instalado ou fbclient.dll na pasta do
  executavel), erpvendas.ini com a secao [Banco] apontando para esse
  arquivo (copiar config\erpvendas.ini.example e ajustar Caminho/
  Usuario/Senha para os dados reais do ambiente).

  1. Criar um form/projeto de teste temporario (ou reaproveitar o hello
     world de T07) com:

       uses ERPV.Core.Config, ERPV.Core.Log, ERPV.Core.Erros,
         ERPV.Dados.Conexao, FireDAC.Comp.Client, Vcl.Dialogs;
       var
         Config: TConfiguracao;
         Logger: TLogger;
         Conexao: TConexao;
       begin
         Config := TConfiguracao.Create;
         Logger := TLogger.Create(Config.Log.Pasta);
         try
           Conexao := TConexao.Create(Config, Logger);
           try
             ShowMessage('Conectado! InTransaction inicial: ' +
               BoolToStr(Conexao.EmTransacao, True));

             // Teste do helper de transacao com uma consulta simples:
             Conexao.IniciarTransacao;
             try
               Conexao.Connection.ExecSQL('SELECT 1 FROM RDB$DATABASE');
               Conexao.Confirmar;
               ShowMessage('Transacao de teste OK (iniciar + confirmar).');
             except
               on E: Exception do
               begin
                 Conexao.Desfazer;
                 raise;
               end;
             end;
           finally
             Conexao.Free;
           end;
         except
           on E: EInfra do
             ShowMessage('Falha amigavel (esperado se banco/senha errados): ' + E.Message);
         end;
       finally
         Logger.Free;
         Config.Free;
       end;

  2. CENARIO FELIZ - banco criado por T03 acessivel, INI correto:
     Esperado: "Conectado!" e depois "Transacao de teste OK" aparecem.
     Nenhuma linha ERRO no log do dia.

  3. CENARIO BANCO OFFLINE - parar o servico do Firebird (ou apontar
     Caminho do INI para um host/arquivo inexistente) e rodar de novo:
     Esperado: ShowMessage mostra so a mensagem amigavel fixa (ex.: "Nao
     foi possivel conectar ao banco de dados. Verifique se o servico esta
     ativo e tente novamente."), SEM caminho de arquivo, SEM host, SEM SQL.
     Abrir o log do dia (pasta [Log] do INI) e confirmar que a mensagem
     tecnica completa do FireDAC (classe da excecao + mensagem original,
     incluindo o Database/host de fato usado) foi gravada em ERRO.

  4. CENARIO SENHA ERRADA - alterar Senha em [Banco] do INI para um valor
     invalido e rodar de novo: mesmo resultado do item 3 (mensagem
     amigavel generica na tela, detalhe tecnico completo so no log).

  5. Repetir os itens 3/4 conferindo que a mensagem exibida ao usuario
     NUNCA muda de conteudo entre os dois cenarios (nao vaza detalhe que
     permita distinguir "banco offline" de "senha errada" - informacao
     sensivel fica so no log).

  Compilacao/execucao real pendente de confirmacao do usuario na IDE
  (ver nota no TASK.md, Secao 3, linha T12): o ambiente de automacao nao
  compila projeto Delphi Community Edition via linha de comando.
}

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.FB,
  FireDAC.Phys.FBDef,
  FireDAC.Comp.Client,
  ERPV.Core.Config,
  ERPV.Core.Log,
  ERPV.Core.Erros;

type
  /// <summary>
  /// Conexao FireDAC/Firebird 3 (ADR-002) montada a partir de TConfiguracao
  /// (secao [Banco]) e helper de transacao explicita. Qualquer falha do
  /// FireDAC/Firebird (conectar, iniciar/confirmar/desfazer transacao) e
  /// mapeada para EInfra (ERPV.Core.Erros): mensagem amigavel exposta,
  /// detalhe tecnico completo gravado via TLogger. Instanciada uma unica
  /// vez pelo composition root (T13) e injetada por construtor nos
  /// repositorios das proximas tarefas (T17, T21, T25, T37...).
  /// </summary>
  TConexao = class
  private
    FConfiguracao: TConfiguracao;
    FLogger: TLogger;
    FConnection: TFDConnection;
    FDriverFB: TFDPhysFBDriverLink;
    procedure ConfigurarConnection;
    function GetEmTransacao: Boolean;
  public
    /// <param name="AConfiguracao">Ja carregada (ERPV.Core.Config, T09);
    /// esta classe nao instancia TConfiguracao sozinha.</param>
    /// <param name="ALogger">Ja criado (ERPV.Core.Log, T10); esta classe
    /// nao instancia TLogger sozinha.</param>
    /// <exception cref="EInfra">Falha ao conectar ao banco (offline,
    /// credencial invalida, arquivo/alias inexistente etc.) - mensagem
    /// amigavel, detalhe tecnico completo no log.</exception>
    constructor Create(AConfiguracao: TConfiguracao; ALogger: TLogger);
    destructor Destroy; override;

    /// <summary>Abre a conexao se ainda nao estiver aberta. Ja chamada
    /// pelo construtor; exposta tambem para permitir reconectar depois de
    /// uma falha tratada (ex.: usuario corrigiu o banco offline e tentou
    /// de novo), sem precisar recriar TConexao.</summary>
    /// <exception cref="EInfra">Mesmo mapeamento do construtor.</exception>
    procedure Conectar;

    /// <summary>Fecha a conexao, se aberta. Nunca lanca excecao (best
    /// effort); falha ao desconectar so e registrada no log.</summary>
    procedure Desconectar;

    /// <summary>Inicia uma transacao explicita (ADR-002: "transacoes
    /// explicitas StartTransaction/Commit/Rollback em toda operacao
    /// multi-tabela"). Reconecta automaticamente se a conexao tiver caido.
    /// Nao faz nada se ja houver uma transacao em andamento (idempotente),
    /// para permitir chamadas aninhadas simples sem erro do FireDAC.
    /// </summary>
    /// <exception cref="EInfra">Falha ao (re)conectar ou iniciar a
    /// transacao.</exception>
    procedure IniciarTransacao;

    /// <summary>Confirma (COMMIT) a transacao em andamento. Nao faz nada
    /// se nao houver transacao aberta.</summary>
    /// <exception cref="EInfra">Falha ao confirmar - o chamador deve
    /// considerar a operacao NAO persistida.</exception>
    procedure Confirmar;

    /// <summary>Desfaz (ROLLBACK) a transacao em andamento. Nao faz nada
    /// se nao houver transacao aberta. NUNCA lanca excecao (best effort;
    /// evita mascarar a excecao original que motivou o rollback no
    /// except de quem chamou) - falha ao desfazer so e registrada no
    /// log.</summary>
    procedure Desfazer;

    /// <summary>Conexao FireDAC pronta para uso pelos repositorios
    /// (TFDQuery.Connection := Conexao.Connection). Nunca deve ser
    /// exposta em componente de UI/form (regra deste lote: sem
    /// TFDQuery/TFDConnection em form).</summary>
    property Connection: TFDConnection read FConnection;

    /// <summary>True se ha uma transacao explicita em andamento.</summary>
    property EmTransacao: Boolean read GetEmTransacao;
  end;

implementation

const
  MSG_FALHA_CONEXAO =
    'Não foi possível conectar ao banco de dados. Verifique se o serviço ' +
    'está ativo e tente novamente.';
  MSG_FALHA_TRANSACAO =
    'Não foi possível completar a operação no banco de dados. Tente novamente.';

{ TConexao }

constructor TConexao.Create(AConfiguracao: TConfiguracao; ALogger: TLogger);
begin
  inherited Create;

  if not Assigned(AConfiguracao) then
    raise EArgumentException.Create('TConexao.Create: configuracao nao pode ser nil.');
  if not Assigned(ALogger) then
    raise EArgumentException.Create('TConexao.Create: logger nao pode ser nil.');

  FConfiguracao := AConfiguracao;
  FLogger := ALogger;

  FDriverFB := TFDPhysFBDriverLink.Create(nil);

  FConnection := TFDConnection.Create(nil);
  ConfigurarConnection;

  // Ja tenta conectar aqui: garante o criterio de aceite ("App conecta ao
  // banco criado por T03") assim que o composition root (T13) instanciar
  // esta classe com sucesso, e ja mapeia falha (offline/senha errada)
  // para EInfra antes de propagar para quem chamou.
  Conectar;
end;

destructor TConexao.Destroy;
begin
  Desconectar;
  FConnection.Free;
  FDriverFB.Free;
  inherited Destroy;
end;

procedure TConexao.ConfigurarConnection;
begin
  FConnection.LoginPrompt := False;
  FConnection.Params.Clear;
  FConnection.Params.Add('DriverID=FB');
  FConnection.Params.Add('Database=' + FConfiguracao.Banco.Caminho);
  FConnection.Params.Add('User_Name=' + FConfiguracao.Banco.Usuario);
  FConnection.Params.Add('Password=' + FConfiguracao.Banco.Senha);
  FConnection.Params.Add('CharacterSet=UTF8');
end;

function TConexao.GetEmTransacao: Boolean;
begin
  Result := FConnection.InTransaction;
end;

procedure TConexao.Conectar;
begin
  if FConnection.Connected then
    Exit;
  try
    FConnection.Connected := True;
  except
    on E: Exception do
    begin
      // Detalhe tecnico completo (classe + mensagem original do FireDAC,
      // que pode incluir Database/host/usuario) so vai para o log - NUNCA
      // para o usuario (ADR-008).
      FLogger.Erro('Falha ao conectar ao banco de dados (ERPV.Dados.Conexao)', E);
      raise EInfra.Create(MSG_FALHA_CONEXAO);
    end;
  end;
end;

procedure TConexao.Desconectar;
begin
  try
    if FConnection.Connected then
      FConnection.Connected := False;
  except
    on E: Exception do
      // Best effort: desconectar nunca deve propagar excecao (ex.: no
      // Destroy). So registra no log.
      FLogger.Erro('Falha ao desconectar do banco de dados (ERPV.Dados.Conexao)', E);
  end;
end;

procedure TConexao.IniciarTransacao;
begin
  if FConnection.InTransaction then
    Exit;
  try
    Conectar;
    FConnection.StartTransaction;
  except
    on E: EInfra do
      raise; // ja mapeada e logada dentro de Conectar
    on E: Exception do
    begin
      FLogger.Erro('Falha ao iniciar transacao no banco de dados (ERPV.Dados.Conexao)', E);
      raise EInfra.Create(MSG_FALHA_TRANSACAO);
    end;
  end;
end;

procedure TConexao.Confirmar;
begin
  if not FConnection.InTransaction then
    Exit;
  try
    FConnection.Commit;
  except
    on E: Exception do
    begin
      FLogger.Erro('Falha ao confirmar (commit) transacao no banco de dados (ERPV.Dados.Conexao)', E);
      raise EInfra.Create(MSG_FALHA_TRANSACAO);
    end;
  end;
end;

procedure TConexao.Desfazer;
begin
  if not FConnection.InTransaction then
    Exit;
  try
    FConnection.Rollback;
  except
    on E: Exception do
      // Nunca relanca: evitar mascarar a excecao original que motivou o
      // rollback no bloco except de quem chamou (ex.: um repositorio).
      FLogger.Erro('Falha ao desfazer (rollback) transacao no banco de dados (ERPV.Dados.Conexao)', E);
  end;
end;

end.
