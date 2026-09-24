unit ERPV.App.Root;

(*
  T13 (Lote 2) - Composition root da aplicacao (ADR-001).

  Unica unit autorizada a instanciar diretamente classes concretas de
  Dados/Integracao/Core (TConfiguracao, TLogger, TTratadorDeExcecoes,
  TConexao, os repositorios, o cliente financeiro, o relatorio, o
  EmailSender e os servicos concretos). Nenhuma outra unit de Negocio/UI deve importar
  ERPV.Dados.*/ERPV.Core.Config/etc. diretamente - elas devem receber essas
  dependencias ja prontas via injecao por construtor, a partir daqui
  (ADR-001, "DI manual por construtor").

  ==========================================================================
  SEQUENCIA DE MONTAGEM (seguindo o roteiro ja documentado no cabecalho de
  ERPV.Dados.Conexao, T12)
  ==========================================================================
  1. TConfiguracao.Create           - le erpvendas.ini (T09). Pode lancar
     EConfiguracao (que herda de EInfra, T11) se o arquivo estiver ausente
     ou invalido.
  2. TLogger.Create(Config.Log.Pasta) - log em arquivo por dia (T10).
  3. TTratadorDeExcecoes.Create(Logger) - handler central de excecao nao
     tratada (T11), conectado em Application.OnException logo em seguida.
  4. TConexao.Create(Config, Logger)  - conecta ao Firebird (T12) e ja
     lanca EInfra em caso de falha (banco offline, credencial invalida
     etc.).

  Qualquer falha nessa cadeia (EConfiguracao ou EInfra) e capturada por
  TentarIniciarAplicacao (funcao de entrada usada pelo .dpr): mostra
  MensagemAmigavel(E) ao usuario via MessageDlg e devolve False, sem criar
  nenhum form - quem chama (.dpr) encerra a aplicacao de forma controlada
  nesse caso, sem crash cru. Isso e aceitavel aqui (e so aqui, junto com
  ERPV.Core.Erros) porque este e o composition root da aplicacao: tocar
  Vcl.Dialogs/Vcl.Forms e award esperado, nao uma violacao da regra "Core
  nao depende de Vcl".

  Se a construcao falhar no meio (ex.: TConexao.Create lanca EInfra depois
  de Config/Logger/Tratador ja criados), o proprio runtime do Delphi chama
  automaticamente TRootAplicacao.Destroy sobre o objeto parcialmente
  construido antes de propagar a excecao (comportamento padrao da
  linguagem para excecao dentro de construtor) - por isso Destroy so
  precisa dar Free em cada campo (TObject.Free e seguro com nil), sem
  logica extra de "limpeza parcial".

  ==========================================================================
  MONTADO HOJE (apos a Conexao, nesta ordem)
  ==========================================================================
  Repositorios: Venda, Cliente, Produto, Fila (todos com Conexao + Logger).
  Servicos: ClienteService (Cliente+Venda repos), ProdutoService
  (Produto+Venda repos), VendaService (Venda/Cliente/Produto/Fila repos).
  Integracao/Relatorio: Financeiro (TFinanceiroClient, config [Financeiro]
  + Logger), RelatorioPedido (pasta PDF temp + VendaRepository + Logger),
  EmailSender (config SMTP + Logger + Remetente).
  QuitacaoService: Venda repo, Financeiro, Fila repo, Cliente repo,
  Relatorio, EmailSender e Logger.
  FilaService: mesmas dependencias da Quitacao + o proprio QuitacaoService
  e Logger.
  Destroy libera na ordem inversa, antes de FConexao.

  Para novos repositorios/servicos, o padrao a seguir e:
    - Um novo campo privado (ex.: FClienteRepository: IClienteRepository)
      e a property publica correspondente.
    - Instanciado no construtor, logo apos FConexao, recebendo FConexao e
      FLogger (ou outro repositorio/servico ja montado) por construtor -
      nunca instanciando Config/Logger/Conexao de novo.
    - Liberado no destructor, na ordem inversa da criacao, antes de
      FConexao.
  Nao criar campos vazios/placeholder para classes que ainda nao existem.

  ==========================================================================
  ROTEIRO DE VERIFICACAO MANUAL NA IDE (sem testes automatizados, DEC-14)
  ==========================================================================
  Pre-requisitos: mesmos de T12 (banco criado por T03 acessivel,
  erpvendas.ini valido na pasta do executavel - copiar
  config\erpvendas.ini.example e ajustar).

  1. CENARIO FELIZ: compilar e rodar ERPVendas.dpr com INI valido apontando
     para o banco de T03. Esperado: nenhuma mensagem de erro, o FormMain
     (T07) abre normalmente. Abrir o log do dia (pasta [Log] do INI) e
     confirmar que nao ha nenhuma linha ERRO relativa a inicializacao.

  2. CENARIO INI AUSENTE/INVALIDO: renomear/mover erpvendas.ini (ou apagar
     uma secao obrigatoria) e rodar de novo. Esperado: MessageDlg mostra a
     mensagem de EConfiguracao (ex.: "Arquivo de configuracao nao
     encontrado..."), a aplicacao encerra sem abrir o FormMain e sem
     crash/stack trace da IDE.

  3. CENARIO BANCO OFFLINE/SENHA ERRADA (mesmo cenario de T12, agora via
     o .dpr real): parar o servico do Firebird ou usar senha invalida no
     INI e rodar de novo. Esperado: MessageDlg mostra a mensagem amigavel
     fixa de EInfra ("Nao foi possivel conectar ao banco de dados...
     "), sem SQL/host/credencial. Aplicacao encerra sem abrir o FormMain.
     Se o INI ja era valido (logger foi criado antes da falha), o log do
     dia deve conter a mensagem tecnica completa do FireDAC em ERRO
     (mesmo comportamento ja verificado isoladamente em T12).

  4. CENARIO EXCECAO NAO TRATADA DEPOIS DE INICIADO: com o app ja aberto
     (cenario 1), repetir o teste manual dos 3 botoes ja descrito no
     cabecalho de T11 (ou reintroduzi-los temporariamente num form de
     teste) para confirmar que Application.OnException continua apontando
     para o TTratadorDeExcecoes montado por este root.

  Compilacao/execucao real pendente de confirmacao do usuario na IDE (ver
  nota no TASK.md, Secao 3, linhas T12/T13): o ambiente de automacao nao
  compila projeto Delphi Community Edition via linha de comando.
*)

interface

uses
  System.SysUtils,
  Vcl.Forms,
  Vcl.Dialogs,
  ERPV.Core.Config,
  ERPV.Core.Log,
  ERPV.Core.Erros,
  ERPV.Dados.Conexao,
  ERPV.Dados.VendaRepository,
  ERPV.Dominio.Contratos.IVendaRepository,
  ERPV.Dados.ClienteRepository,
  ERPV.Dominio.Contratos.IClienteRepository,
  ERPV.Dados.ProdutoRepository,
  ERPV.Dominio.Contratos.IProdutoRepository,
  ERPV.Dados.FilaRepository,
  ERPV.Dominio.Contratos.IFilaRepository,
  ERPV.Negocio.ClienteService,
  ERPV.Negocio.ProdutoService,
  ERPV.Negocio.VendaService,
  ERPV.Dominio.Contratos.IFinanceiroGateway,
  ERPV.Integracao.FinanceiroClient,
  ERPV.Negocio.QuitacaoService,
  ERPV.Negocio.FilaService,
  ERPV.Dominio.Contratos.IRelatorioPedido,
  ERPV.Relatorios.RelatorioPedido,
  ERPV.Dominio.Contratos.IEmailSender,
  ERPV.Integracao.EmailSender;

type
  /// <summary>
  /// Composition root (ADR-001): monta e mantem vivas, durante o ciclo de
  /// vida do app, as instancias de infraestrutura (Config/Log/Tratador de
  /// excecoes/Conexao) e os repositorios, gateways e servicos de negocio
  /// concretos ja montados - todos injetados por construtor nas
  /// classes que os consomem. Nenhuma outra unit deve instanciar essas
  /// classes concretas diretamente.
  /// </summary>
  TRootAplicacao = class
  private
    FConfiguracao: TConfiguracao;
    FLogger: TLogger;
    FTratador: TTratadorDeExcecoes;
    FConexao: TConexao;
    FVendaRepository: IVendaRepository;
    FClienteRepository: IClienteRepository;
    FClienteService: TClienteService;
    FProdutoRepository: IProdutoRepository;
    FProdutoService: TProdutoService;
    FVendaService: TVendaService;
    FFilaRepository: IFilaRepository;
    FFinanceiro: IFinanceiroGateway;
    FQuitacaoService: TQuitacaoService;
    FFilaService: TFilaService;
    FRelatorioPedido: IRelatorioPedido;
    FEmailSender: IEmailSender;
  public
    /// <exception cref="EConfiguracao">INI ausente ou invalido (T09).</exception>
    /// <exception cref="EInfra">Falha ao conectar ao banco (T12).</exception>
    constructor Create;
    destructor Destroy; override;

    property Configuracao: TConfiguracao read FConfiguracao;
    property Logger: TLogger read FLogger;
    property Tratador: TTratadorDeExcecoes read FTratador;
    property Conexao: TConexao read FConexao;
    property VendaRepository: IVendaRepository read FVendaRepository;
    property ClienteRepository: IClienteRepository read FClienteRepository;
    property ClienteService: TClienteService read FClienteService;
    property ProdutoRepository: IProdutoRepository read FProdutoRepository;
    property ProdutoService: TProdutoService read FProdutoService;
    property VendaService: TVendaService read FVendaService;
    property FilaRepository: IFilaRepository read FFilaRepository;
    property Financeiro: IFinanceiroGateway read FFinanceiro;
    property QuitacaoService: TQuitacaoService read FQuitacaoService;
    property FilaService: TFilaService read FFilaService;
    property RelatorioPedido: IRelatorioPedido read FRelatorioPedido;
    property EmailSender: IEmailSender read FEmailSender;

    // Ja montados (T17 ClienteRepository, T21 ProdutoRepository,
    // T25 VendaRepository, T37 FilaRepository, servicos de negocio etc.).
    // Novo item: campo + property aqui, instanciado no construtor logo apos
    // FConexao e liberado no destructor antes de FConexao. Ver nota no
    // cabecalho desta unit.
  end;

  /// <summary>
  /// Ponto de entrada do composition root para o .dpr: tenta montar
  /// TRootAplicacao (Config -> Log -> Tratador de excecoes -> Conexao).
  /// Se qualquer etapa da cadeia falhar (EConfiguracao/EInfra), mostra a
  /// mensagem amigavel (ERPV.Core.Erros.MensagemAmigavel) ao usuario e
  /// devolve False (ARoot fica nil) - quem chamar (.dpr) deve entao
  /// encerrar a aplicacao sem criar nenhum form, sem crash cru. Nunca
  /// deixa uma excecao de configuracao/infra propagar crua para o topo do
  /// programa.
  /// </summary>
  function TentarIniciarAplicacao(out ARoot: TRootAplicacao): Boolean;

implementation

{ TRootAplicacao }

constructor TRootAplicacao.Create;
begin
  inherited Create;

  FConfiguracao := TConfiguracao.Create;
  FLogger := TLogger.Create(FConfiguracao.Log.Pasta);

  FTratador := TTratadorDeExcecoes.Create(FLogger);
  Application.OnException := FTratador.AoTratarExcecao;

  FConexao := TConexao.Create(FConfiguracao, FLogger);

  FVendaRepository := TVendaRepository.Create(FConexao, FLogger); // T25
  FClienteRepository := TClienteRepository.Create(FConexao, FLogger); // T17
  FClienteService := TClienteService.Create(FClienteRepository, FVendaRepository); // T18
  FProdutoRepository := TProdutoRepository.Create(FConexao, FLogger); // T21
  FProdutoService := TProdutoService.Create(FProdutoRepository, FVendaRepository); // T22
  FFilaRepository := TFilaRepository.Create(FConexao, FLogger); // T37
  FVendaService := TVendaService.Create(FVendaRepository, FClienteRepository,
    FProdutoRepository, FFilaRepository); // T27 + T53 (bloqueio por fila)

  FFinanceiro := TFinanceiroClient.Create(FConfiguracao.Financeiro.BaseUrl,
    FConfiguracao.Financeiro.TimeoutMs, FConfiguracao.Financeiro.ApiKey, FLogger); // T34-T36
  FRelatorioPedido := TRelatorioPedido.Create(FConfiguracao.Relatorio.PastaPdfTemp,
    FVendaRepository, FLogger); // T47
  FEmailSender := TEmailSender.Create(FConfiguracao.SMTP, FLogger,
    FConfiguracao.SMTP.Remetente); // T48
  FQuitacaoService := TQuitacaoService.Create(FVendaRepository, FFinanceiro,
    FFilaRepository, FClienteRepository, FRelatorioPedido, FEmailSender, FLogger); // T43/T49, RF12-01

  FFilaService := TFilaService.Create(FVendaRepository, FFinanceiro,
    FFilaRepository, FClienteRepository, FRelatorioPedido, FEmailSender, FQuitacaoService, FLogger); // T50/T51/T52, RF13-02/05

  // Novos itens de composicao entram aqui.
end;

destructor TRootAplicacao.Destroy;
begin
  // Ordem inversa da criacao. Remove o handler antes de liberar o
  // Tratador/Logger para nao deixar Application.OnException apontando
  // para um metodo de objeto ja destruido caso alguma excecao tardia
  // dispare durante o encerramento do app.
  if Assigned(Application) then
    Application.OnException := nil;

  FEmailSender := nil; // T48
  FRelatorioPedido := nil; // T47
  FFilaService.Free; // T50/T52
  FQuitacaoService.Free; // T43, antes dos repositorios/gateway
  FFinanceiro := nil; // T34
  FVendaService.Free; // T27, antes dos repositorios
  FVendaRepository := nil; // T25, antes de FConexao
  FFilaRepository := nil; // T37, antes de FConexao
  FProdutoService.Free; // T22, antes do repositorio
  FProdutoRepository := nil; // T21, antes de FConexao
  FClienteService.Free; // T18, antes do repositorio
  FClienteRepository := nil; // antes de FConexao (T17)
  FConexao.Free;
  FTratador.Free;
  FLogger.Free;
  FConfiguracao.Free;
  inherited Destroy;
end;

function TentarIniciarAplicacao(out ARoot: TRootAplicacao): Boolean;
begin
  ARoot := nil;
  try
    ARoot := TRootAplicacao.Create;
    Result := True;
  except
    on E: EInfra do
    begin
      // Cobre EConfiguracao (herda de EInfra, T11) e EInfra levantada por
      // TConexao (T12). Mensagem amigavel ao usuario (ADR-008); detalhe
      // tecnico completo ja foi gravado no log dentro de TConexao quando o
      // logger ja existia. Se a falha ocorreu antes do logger existir
      // (ex.: INI ausente/invalido), so ha a mensagem amigavel mesmo - nao
      // ha onde logar ainda.
      MessageDlg(MensagemAmigavel(E), mtError, [mbOK], 0);
      Result := False;
    end;
  end;
end;

end.
