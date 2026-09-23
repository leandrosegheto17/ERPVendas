unit ERPV.Core.Erros;

{
  T11 (Lote 2) - Hierarquia de excecoes, tradutor de mensagem amigavel e
  handler central de Application.OnException (ADR-008, RF-24).

  ==========================================================================
  HIERARQUIA (ADR-008: "Hierarquia EErpVendas > EValidacao (campo +
  mensagem), ERegraNegocio, EIntegracao, EInfra")
  ==========================================================================
  - EErpVendas: raiz comum de todas as excecoes de negocio/infra do
    ERPVendas. Nao e lancada diretamente, so serve de base para is-a-EErpVendas
    em codigo generico (ex.: "capturar qualquer excecao conhecida do
    dominio, deixando passar excecoes de terceiros/framework para o
    Application.OnException").
  - EValidacao: erro de validacao de entrada (campo obrigatorio, formato
    invalido, faixa de valor, etc.). Mensagem e para o usuario, mostrada
    literal (E.Message). Suporta opcionalmente o nome do campo que falhou
    (propriedade Campo, via construtor CreateCampo) para telas que queiram
    destacar o campo inline; quem nao precisar disso usa o Create(AMessage)
    herdado normalmente de Exception, sem preencher Campo.
  - ERegraNegocio: violacao de regra de negocio (ex.: "cliente inadimplente
    nao pode comprar a prazo"). Mesma ideia de EValidacao: mensagem literal
    ao usuario.
  - EIntegracao: falha de integracao externa (HTTP do Financeiro, SMTP).
    Mensagem tecnica (E.Message) NUNCA vai direto ao usuario - pode conter
    URL, corpo de resposta, timeout etc. Usar MensagemAmigavel() para obter
    o texto a exibir.
  - EInfra: falha de infraestrutura (banco Firebird, arquivo, configuracao).
    Mesma ideia de EIntegracao: mensagem tecnica so no log.
  - EInfraMensagemSegura (subclasse de EInfra, adicionada ao lado de T12/T13):
    para o caso especifico de uma falha de infraestrutura cuja mensagem do
    construtor ja foi escrita para o usuario e comprovadamente nao contem
    SQL/credencial (ex.: EConfiguracao, abaixo). MensagemAmigavel mostra
    essa mensagem literal, nao a generica de EInfra.

  Nota sobre EConfiguracao (T09, ERPV.Core.Config.pas): a unit de Config foi
  escrita antes desta hierarquia existir e deixou EConfiguracao herdando de
  Exception puro, com nota explicita pedindo para T11 revisar. Decisao
  tomada aqui: EConfiguracao passa a herdar de EInfra (falha de
  configuracao e, na pratica, uma falha de infraestrutura - arquivo INI
  ausente/invalido). Mudanca de baixo risco (so troca o ancestral, nenhuma
  API publica de EConfiguracao muda) feita diretamente em
  ERPV.Core.Config.pas como parte desta tarefa. Ajuste posterior (T12/T13):
  EConfiguracao passou a herdar de EInfraMensagemSegura em vez de EInfra
  puro - ver nota acima e em ERPV.Core.Config.pas.

  ==========================================================================
  TRADUTOR DE MENSAGEM AMIGAVEL (MensagemAmigavel)
  ==========================================================================
  Regra (ADR-008 + criterio de aceite de T11, ajustada ao lado de T12/T13):
  - EValidacao / ERegraNegocio / EInfraMensagemSegura -> devolve E.Message
    literal (a mensagem ja foi escrita pensando no usuario final; para
    EInfraMensagemSegura, com a garantia adicional de nao conter dado
    sensivel, ver classe acima).
  - EIntegracao / EInfra (demais casos) -> devolve mensagem generica
    amigavel fixa, NUNCA o E.Message original (que pode ter SQL, caminho de
    arquivo, URL, corpo de resposta HTTP etc. - isso so vai para o log).
  - Qualquer outra excecao nao mapeada (EAccessViolation, excecoes de
    biblioteca de terceiros, bugs nao previstos) -> mensagem fixa exigida
    pelo criterio de aceite: "Ocorreu um erro inesperado. Os detalhes foram
    gravados no log."

  ==========================================================================
  HANDLER Application.OnException (TTratadorDeExcecoes)
  ==========================================================================
  Esta unit E A EXCECAO da regra "Core nao depende de Vcl": Application.
  OnException e MessageDlg sao, por definicao, APIs de UI (Vcl.Forms /
  Vcl.Dialogs). Nao ha como implementar o handler central de excecao sem
  tocar Vcl. Todas as outras units de Dominio/Core (ERPV.Core.Log,
  ERPV.Core.Config, Dominio.*) continuam proibidas de importar Vcl.* - essa
  excecao vale só para ERPV.Core.Erros.

  TTratadorDeExcecoes recebe um TLogger (ERPV.Core.Log, T10) por construtor
  - esta unit NUNCA instancia TLogger sozinha. O composition root (T13) e
  quem cria o TLogger (com a pasta lida do INI via ERPV.Core.Config) e
  conecta assim:

    Tratador := TTratadorDeExcecoes.Create(Logger);
    Application.OnException := Tratador.AoTratarExcecao;

  (o composition root tambem e responsavel por manter Tratador vivo
  enquanto a aplicacao roda, ex.: como campo de uma classe raiz, e libera-lo
  no encerramento).

  ==========================================================================
  ROTEIRO DE VERIFICACAO MANUAL NA IDE (sem testes automatizados, DEC-14)
  ==========================================================================
  1. No form principal (ou form de teste temporario), montar manualmente
     (sem esperar T13 pronto) so para o teste:

       uses ERPV.Core.Erros, ERPV.Core.Log, Vcl.Forms;
       var
         Logger: TLogger;
         Tratador: TTratadorDeExcecoes;
       begin
         Logger := TLogger.Create('C:\Temp\logs-teste');
         Tratador := TTratadorDeExcecoes.Create(Logger);
         Application.OnException := Tratador.AoTratarExcecao;
       end;

  2. Adicionar 3 botoes temporarios (removidos depois do teste manual):
     a) Botao 1: raise EValidacao.Create('Descricao do produto e obrigatoria.');
        Esperado: MessageDlg mostra literalmente "Descricao do produto e
        obrigatoria." (mtError). Log recebe uma linha ERRO com
        "EValidacao: Descricao do produto e obrigatoria.".
     b) Botao 2: raise EInfra.Create('Falha ao conectar: SQL SELECT * FROM CLIENTE, host=10.0.0.5');
        Esperado: MessageDlg mostra "Nao foi possivel completar a operacao.
        Tente novamente." (NUNCA o texto do SQL/host). Log recebe a
        mensagem tecnica completa (com o SQL e host) em ERRO.
     c) Botao 3: raise Exception.Create('erro generico nao mapeado');
        Esperado: MessageDlg mostra "Ocorreu um erro inesperado. Os
        detalhes foram gravados no log." (texto literal do criterio de
        aceite). Log recebe "Exception: erro generico nao mapeado".
  3. Abrir o arquivo `C:\Temp\logs-teste\erpvendas-AAAAMMDD.log` e conferir
     que a mensagem tecnica completa (classe + mensagem original) esta
     presente em todos os 3 casos, mesmo quando o MessageDlg mostrou uma
     mensagem generica.

  Verificado na pratica pelo usuario em 2026-09-22: os 3 botoes mostraram
  exatamente as mensagens esperadas, e o log gravou a mensagem tecnica
  completa (incluindo o SQL/host do cenario EInfra) nos 3 casos.

  ==========================================================================
  BUG REAL ENCONTRADO E CORRIGIDO NA COMPILACAO
  ==========================================================================
  A ordem original desta unit tinha `TTratadorDeExcecoes` declarada POR
  ULTIMO no bloco `type`, depois da declaracao solta de
  `function MensagemAmigavel(E: Exception): string;` (uma funcao, nao um
  tipo, no meio do bloco `type`). O dcc32 desta instalacao nao aceitou essa
  ordem: gerou uma cascata de erros a partir da declaracao de
  `TTratadorDeExcecoes` ("E2070 Unknown directive", depois uma serie de
  erros em cadeia por todo o resto do arquivo). A correcao foi mover a
  classe `TTratadorDeExcecoes` para logo apos `type`, antes de
  `EErpVendas`/`EValidacao`/etc. - ordem que compila limpo. Registrado aqui
  como licao para as proximas units: evitar misturar declaracao de funcao
  solta no meio de um bloco `type` que tambem declara classes; se precisar,
  colocar a funcao por ultimo ou, mais seguro, so depois que o bloco `type`
  terminar (nova secao antes do `implementation`).
}

interface

uses
  System.SysUtils,
  ERPV.Core.Log;

type

  /// <summary>Handler central de excecao nao tratada, para ser atribuido a
  /// Application.OnException pelo composition root (T13). Grava o detalhe
  /// tecnico completo no log e mostra ao usuario apenas a mensagem
  /// amigavel (MensagemAmigavel). Unica classe do Core autorizada a
  /// depender de Vcl (Vcl.Dialogs), ver nota no cabecalho da unit.</summary>
  TTratadorDeExcecoes = class
  private
    FLogger: TLogger;
  public
    /// <param name="ALogger">Instancia ja criada pelo composition root
    /// (T13); esta classe nunca cria seu proprio TLogger.</param>
    constructor Create(ALogger: TLogger);

    /// <summary>Assinatura compativel com TExceptionEvent
    /// (Application.OnException := Tratador.AoTratarExcecao).</summary>
    procedure AoTratarExcecao(Sender: TObject; E: Exception);
  end;

  /// <summary>Raiz comum da hierarquia de excecoes do ERPVendas
  /// (ADR-008). Nao lancada diretamente.</summary>
  EErpVendas = class(Exception);

  /// <summary>Erro de validacao de entrada. Mensagem e exibida literal ao
  /// usuario. Campo opcional identifica qual campo falhou.</summary>
  EValidacao = class(EErpVendas)
  private
    FCampo: string;
  public
    /// <summary>Cria a excecao associando o nome do campo que falhou.
    /// Quando o campo nao for relevante, use o Create(AMessage) herdado de
    /// Exception normalmente.</summary>
    constructor CreateCampo(const ACampo, AMessage: string);
    /// <summary>Nome do campo que falhou na validacao, quando informado
    /// via CreateCampo; vazio se a excecao foi criada com o Create simples
    /// herdado de Exception.</summary>
    property Campo: string read FCampo;
  end;

  /// <summary>Violacao de regra de negocio. Mensagem e exibida literal ao
  /// usuario (mesma ideia de EValidacao).</summary>
  ERegraNegocio = class(EErpVendas);

  /// <summary>Falha de integracao externa (HTTP/SMTP). Mensagem tecnica
  /// (E.Message) nunca vai direto ao usuario - usar MensagemAmigavel.</summary>
  EIntegracao = class(EErpVendas);

  /// <summary>Falha de infraestrutura (banco, arquivo, configuracao).
  /// Mesma ideia de EIntegracao: mensagem tecnica so no log.</summary>
  EInfra = class(EErpVendas);

  /// <summary>Subclasse de EInfra para o caso especifico em que a propria
  /// mensagem do construtor ja foi escrita para ser lida pelo usuario final
  /// (orientacao de configuracao/setup, ex.: "copie o arquivo .example e
  /// ajuste") e comprovadamente NAO contem SQL/caminho de dado sensivel/
  /// credencial - so caminho do proprio arquivo de configuracao e instrucao
  /// de uso, que sao seguros de expor. Quem lancar uma excecao dessa
  /// subclasse esta afirmando essa garantia; MensagemAmigavel mostra
  /// E.Message literal para ela, ao inves da mensagem generica usada para
  /// EInfra/EIntegracao em geral. Uso previsto: EConfiguracao
  /// (ERPV.Core.Config, T09) - arquivo INI ausente/invalido nao e dado
  /// sensivel, e a mensagem especifica orienta o usuario a resolver
  /// sozinho.</summary>
  EInfraMensagemSegura = class(EInfra);

  /// <summary>Traduz uma excecao qualquer na mensagem a ser exibida ao
  /// usuario, nunca incluindo SQL/caminho/stack/credencial (ADR-008).
  /// EValidacao/ERegraNegocio: mensagem literal. EInfraMensagemSegura:
  /// mensagem literal (comprovadamente sem dado sensivel, ver classe).
  /// EIntegracao/EInfra (demais casos): mensagem generica fixa. Qualquer
  /// outra excecao: mensagem fixa de erro inesperado (texto literal do
  /// criterio de aceite de T11).</summary>
  function MensagemAmigavel(E: Exception): string;


implementation

uses
  Vcl.Dialogs;

{ EValidacao }

constructor EValidacao.CreateCampo(const ACampo, AMessage: string);
begin
  inherited Create(AMessage);
  FCampo := ACampo;
end;

{ Tradutor de mensagem amigavel }

function MensagemAmigavel(E: Exception): string;
const
  MSG_INTEGRACAO_INFRA = 'Não foi possível completar a operação. Tente novamente.';
  MSG_ERRO_INESPERADO = 'Ocorreu um erro inesperado. Os detalhes foram gravados no log.';
begin
  if not Assigned(E) then
    Exit(MSG_ERRO_INESPERADO);

  if (E is EValidacao) or (E is ERegraNegocio) or (E is EInfraMensagemSegura) then
    // EInfraMensagemSegura checada antes de EInfra: subclasse mais especifica,
    // com a garantia de que E.Message nao contem dado sensivel (ver classe).
    Result := E.Message
  else if (E is EIntegracao) or (E is EInfra) then
    Result := MSG_INTEGRACAO_INFRA
  else
    Result := MSG_ERRO_INESPERADO;
end;

{ TTratadorDeExcecoes }

constructor TTratadorDeExcecoes.Create(ALogger: TLogger);
begin
  inherited Create;
  if not Assigned(ALogger) then
    raise EArgumentException.Create('TTratadorDeExcecoes.Create: logger nao pode ser nil.');
  FLogger := ALogger;
end;

procedure TTratadorDeExcecoes.AoTratarExcecao(Sender: TObject; E: Exception);
var
  LMensagemUsuario: string;
begin
  LMensagemUsuario := MensagemAmigavel(E);

  // Detalhe tecnico completo (classe + mensagem original) sempre vai para
  // o log, mesmo quando o usuario ve uma mensagem generica (ADR-008).
  FLogger.Erro('Excecao nao tratada capturada por Application.OnException', E);

  MessageDlg(LMensagemUsuario, mtError, [mbOK], 0);
end;

end.
