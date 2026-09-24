unit ERPV.Dados.FilaRepository;

{
  T37 (Lote 9) - Implementacao FireDAC de IFilaRepository (ADR-005/010).

  Convencoes iguais a Cliente/ProdutoRepository: SQL parametrizado,
  transacao explicita curta nas escritas (so iniciada aqui se o chamador
  nao abriu uma), falha FireDAC => EInfra amigavel (sem SQL) + log,
  Listar devolve TFDQuery somente leitura (quem chama libera antes de
  TConexao).

  Regras:
  - Enfileirar: se existe PENDENTE para (VENDA_ID, TIPO), incrementa
    TENTATIVAS e grava ULTIMO_ERRO; senao insere PENDENTE com
    TENTATIVAS = 1 (a 2a chamada resulta em 1 linha, tentativas 2).
  - MarcarConcluido: STATUS = CONCLUIDO, CONCLUIDO_EM = CURRENT_TIMESTAMP.
  - RegistrarFalha: mantem PENDENTE, TENTATIVAS + 1, ULTIMO_ERRO.
  - ULTIMO_ERRO truncado em 500 caracteres (VARCHAR(500)).
  - Nao ha indice unico parcial no schema: a unicidade PENDENTE por
    venda+tipo e garantida aqui (app monousuario desktop, ADR-005).

  ROTEIRO MANUAL NA IDE (DEC-14): com uma venda existente, Enfileirar(v,
  tfQuitacao,'x') 2x => SELECT mostra 1 linha, TENTATIVAS=2. Erro com 600
  chars => ULTIMO_ERRO com 500. ExistePendenciaPorVenda = True;
  ContarPendencias = 1; RegistrarFalha => TENTATIVAS=3; MarcarConcluido =>
  STATUS CONCLUIDO, CONCLUIDO_EM preenchido, Contar = 0, Existe = False,
  Listar(True) vazio e Listar(False) com a linha. Compilacao pendente.
}

interface

uses
  System.SysUtils,
  Data.DB,
  FireDAC.Stan.Error,
  FireDAC.Comp.Client,
  ERPV.Core.Log,
  ERPV.Core.Erros,
  ERPV.Dados.Conexao,
  ERPV.Dominio.Enums,
  ERPV.Dominio.Contratos.IFilaRepository;

type
  TFilaRepository = class(TInterfacedObject, IFilaRepository)
  private
    FConexao: TConexao;
    FLogger: TLogger;
    function NovaQuery: TFDQuery;
    procedure TratarFalha(const AOperacao: string; E: Exception);
  public
    constructor Create(AConexao: TConexao; ALogger: TLogger);

    procedure Enfileirar(AVendaId: Integer; ATipo: TTipoFila; const AErro: string = '');
    function Listar(ASomentePendentes: Boolean): TDataSet;
    procedure MarcarConcluido(AId: Integer);
    procedure RegistrarFalha(AId: Integer; const AErro: string);
    function ContarPendencias: Integer;
    function ExistePendenciaPorVenda(AVendaId: Integer; ATipo: TTipoFila): Boolean;
  end;

implementation

const
  MAX_ERRO = 500;
  MSG_FALHA_GRAVAR = 'Não foi possível gravar na fila de pendências. Tente novamente.';
  MSG_FALHA_CONSULTAR = 'Não foi possível consultar a fila de pendências. Tente novamente.';
  MSG_NAO_ENCONTRADO = 'Item da fila não encontrado.';

  SQL_BUSCAR_PENDENTE =
    'SELECT ID FROM FILA_INTEGRACAO ' +
    'WHERE VENDA_ID = :VENDA_ID AND TIPO = :TIPO AND STATUS = ''PENDENTE''';
  SQL_INCREMENTAR =
    'UPDATE FILA_INTEGRACAO SET TENTATIVAS = TENTATIVAS + 1, ' +
    'ULTIMO_ERRO = :ERRO WHERE ID = :ID';
  SQL_INSERIR =
    'INSERT INTO FILA_INTEGRACAO (VENDA_ID, TIPO, STATUS, TENTATIVAS, ULTIMO_ERRO) ' +
    'VALUES (:VENDA_ID, :TIPO, ''PENDENTE'', 1, :ERRO)';
  SQL_CONCLUIR =
    'UPDATE FILA_INTEGRACAO SET STATUS = ''CONCLUIDO'', ' +
    'CONCLUIDO_EM = CURRENT_TIMESTAMP WHERE ID = :ID';
  SQL_LISTAR_BASE =
    'SELECT ID, VENDA_ID, TIPO, STATUS, TENTATIVAS, ULTIMO_ERRO, ' +
    'PROXIMA_TENTATIVA, CRIADO_EM, CONCLUIDO_EM FROM FILA_INTEGRACAO ';
  SQL_LISTAR_PENDENTES = 'WHERE STATUS = ''PENDENTE'' ';
  SQL_LISTAR_ORDEM = 'ORDER BY CRIADO_EM, ID';
  SQL_CONTAR = 'SELECT COUNT(*) AS TOTAL FROM FILA_INTEGRACAO WHERE STATUS = ''PENDENTE''';

function TruncarErro(const AErro: string): string;
begin
  Result := Copy(AErro, 1, MAX_ERRO);
end;

{ TFilaRepository }

constructor TFilaRepository.Create(AConexao: TConexao; ALogger: TLogger);
begin
  inherited Create;
  if not Assigned(AConexao) then
    raise EArgumentException.Create('TFilaRepository.Create: conexao nao pode ser nil.');
  if not Assigned(ALogger) then
    raise EArgumentException.Create('TFilaRepository.Create: logger nao pode ser nil.');
  FConexao := AConexao;
  FLogger := ALogger;
end;

function TFilaRepository.NovaQuery: TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := FConexao.Connection;
end;

procedure TFilaRepository.TratarFalha(const AOperacao: string; E: Exception);
var
  Mensagem: string;
begin
  FLogger.Erro('Falha no FilaRepository: ' + AOperacao, E);
  if (AOperacao = 'listar') or (AOperacao = 'contar') or (AOperacao = 'existe') then
    Mensagem := MSG_FALHA_CONSULTAR
  else
    Mensagem := MSG_FALHA_GRAVAR;
  raise EInfra.Create(Mensagem);
end;

procedure TFilaRepository.Enfileirar(AVendaId: Integer; ATipo: TTipoFila;
  const AErro: string);
var
  Q: TFDQuery;
  Iniciou: Boolean;
  IdExistente: Integer;
begin
  Iniciou := False;
  Q := NovaQuery;
  try
    try
      Iniciou := not FConexao.EmTransacao;
      FConexao.IniciarTransacao;

      Q.SQL.Text := SQL_BUSCAR_PENDENTE;
      Q.ParamByName('VENDA_ID').AsInteger := AVendaId;
      Q.ParamByName('TIPO').AsString := TipoFilaToStr(ATipo);
      Q.Open;
      if Q.IsEmpty then
        IdExistente := 0
      else
        IdExistente := Q.FieldByName('ID').AsInteger;
      Q.Close;

      if IdExistente > 0 then
      begin
        Q.SQL.Text := SQL_INCREMENTAR;
        Q.ParamByName('ID').AsInteger := IdExistente;
        Q.ParamByName('ERRO').AsString := TruncarErro(AErro);
      end
      else
      begin
        Q.SQL.Text := SQL_INSERIR;
        Q.ParamByName('VENDA_ID').AsInteger := AVendaId;
        Q.ParamByName('TIPO').AsString := TipoFilaToStr(ATipo);
        Q.ParamByName('ERRO').AsString := TruncarErro(AErro);
      end;
      Q.ExecSQL;

      if Iniciou then
        FConexao.Confirmar;
    except
      on E: Exception do
      begin
        if Iniciou then
          FConexao.Desfazer;
        if E is EInfra then
          raise;
        TratarFalha('enfileirar', E);
      end;
    end;
  finally
    Q.Free;
  end;
end;

function TFilaRepository.Listar(ASomentePendentes: Boolean): TDataSet;
var
  Q: TFDQuery;
  SQL: string;
begin
  SQL := SQL_LISTAR_BASE;
  if ASomentePendentes then
    SQL := SQL + SQL_LISTAR_PENDENTES;
  SQL := SQL + SQL_LISTAR_ORDEM;

  Q := NovaQuery;
  try
    Q.UpdateOptions.ReadOnly := True; // grade somente leitura (ADR-003)
    Q.SQL.Text := SQL;
    Q.Open;
    Result := Q;
  except
    on E: Exception do
    begin
      Q.Free;
      if E is EInfra then
        raise;
      TratarFalha('listar', E);
      Result := nil; // inalcancavel (TratarFalha sempre levanta)
    end;
  end;
end;

procedure TFilaRepository.MarcarConcluido(AId: Integer);
var
  Q: TFDQuery;
  Iniciou: Boolean;
begin
  Iniciou := False;
  Q := NovaQuery;
  try
    try
      Iniciou := not FConexao.EmTransacao;
      FConexao.IniciarTransacao;
      Q.SQL.Text := SQL_CONCLUIR;
      Q.ParamByName('ID').AsInteger := AId;
      Q.ExecSQL;
      if Q.RowsAffected = 0 then
        raise EInfra.Create(MSG_NAO_ENCONTRADO);
      if Iniciou then
        FConexao.Confirmar;
    except
      on E: Exception do
      begin
        if Iniciou then
          FConexao.Desfazer;
        if E is EInfra then
          raise;
        TratarFalha('concluir', E);
      end;
    end;
  finally
    Q.Free;
  end;
end;

procedure TFilaRepository.RegistrarFalha(AId: Integer; const AErro: string);
var
  Q: TFDQuery;
  Iniciou: Boolean;
begin
  Iniciou := False;
  Q := NovaQuery;
  try
    try
      Iniciou := not FConexao.EmTransacao;
      FConexao.IniciarTransacao;
      Q.SQL.Text := SQL_INCREMENTAR;
      Q.ParamByName('ID').AsInteger := AId;
      Q.ParamByName('ERRO').AsString := TruncarErro(AErro);
      Q.ExecSQL;
      if Q.RowsAffected = 0 then
        raise EInfra.Create(MSG_NAO_ENCONTRADO);
      if Iniciou then
        FConexao.Confirmar;
    except
      on E: Exception do
      begin
        if Iniciou then
          FConexao.Desfazer;
        if E is EInfra then
          raise;
        TratarFalha('registrar falha', E);
      end;
    end;
  finally
    Q.Free;
  end;
end;

function TFilaRepository.ContarPendencias: Integer;
var
  Q: TFDQuery;
begin
  Result := 0;
  Q := NovaQuery;
  try
    try
      Q.SQL.Text := SQL_CONTAR;
      Q.Open;
      Result := Q.FieldByName('TOTAL').AsInteger;
    except
      on E: Exception do
      begin
        if E is EInfra then
          raise;
        TratarFalha('contar', E);
      end;
    end;
  finally
    Q.Free;
  end;
end;

function TFilaRepository.ExistePendenciaPorVenda(AVendaId: Integer;
  ATipo: TTipoFila): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Q := NovaQuery;
  try
    try
      Q.SQL.Text := SQL_BUSCAR_PENDENTE;
      Q.ParamByName('VENDA_ID').AsInteger := AVendaId;
      Q.ParamByName('TIPO').AsString := TipoFilaToStr(ATipo);
      Q.Open;
      Result := not Q.IsEmpty;
    except
      on E: Exception do
      begin
        if E is EInfra then
          raise;
        TratarFalha('existe', E);
      end;
    end;
  finally
    Q.Free;
  end;
end;

end.
