unit ERPV.Dados.ProdutoRepository;

(*
  T21 (Lote 5) - Implementacao FireDAC de IProdutoRepository (ADR-003/010).

  Mesmas convencoes de ERPV.Dados.ClienteRepository (T17):
  - SQL 100% parametrizado (ParamByName); transacao explicita curta nas
    escritas (iniciada aqui somente se o chamador ainda nao abriu uma).
  - Preco: NUMERIC(15,2) <-> Currency (AsCurrency), nunca Double.
  - ListarDataSet devolve TFDQuery somente leitura; QUEM CHAMA libera o
    DataSet antes de TConexao. Busca por descricao ou categoria (LIKE
    escapado, case-insensitive); ordem por descricao, id.
  - Falha FireDAC vira EInfra amigavel (sem SQL) + detalhe no log. FK na
    exclusao (produto com itens de venda) tem mensagem propria.

  ROTEIRO MANUAL NA IDE (DEC-14): com Root montado, Incluir produto ->
  Obter -> Alterar (preco 10,55) -> ListarDataSet('', False) e com True apos
  inativar -> busca por trecho de descricao/categoria -> Excluir. Confirmar
  que o preco volta identico (Currency). Compilacao pendente na IDE.
*)

interface

uses
  System.SysUtils,
  Data.DB,
  FireDAC.Stan.Error,
  FireDAC.Comp.Client,
  ERPV.Core.Log,
  ERPV.Core.Erros,
  ERPV.Dados.Conexao,
  ERPV.Dominio.Produto,
  ERPV.Dominio.Contratos.IProdutoRepository;

type
  TProdutoRepository = class(TInterfacedObject, IProdutoRepository)
  private
    FConexao: TConexao;
    FLogger: TLogger;
    function NovaQuery: TFDQuery;
    procedure PreencherParametros(AQuery: TFDQuery; const AProduto: TProduto);
    procedure TratarFalha(const AOperacao: string; E: Exception);
  public
    constructor Create(AConexao: TConexao; ALogger: TLogger);

    function Incluir(const AProduto: TProduto): Integer;
    procedure Alterar(const AProduto: TProduto);
    procedure Excluir(AId: Integer);
    function Obter(AId: Integer): TProduto;
    function ListarDataSet(const AFiltroBusca: string; AIncluirInativos: Boolean): TDataSet;
  end;

implementation

const
  MSG_FALHA_GRAVAR = 'Não foi possível gravar o produto. Tente novamente.';
  MSG_FALHA_CONSULTAR = 'Não foi possível consultar os produtos. Tente novamente.';
  MSG_FALHA_EXCLUIR = 'Não foi possível excluir o produto. Tente novamente.';
  MSG_PRODUTO_EM_USO = 'O produto possui vendas e não pode ser excluído; inative-o.';
  MSG_NAO_ENCONTRADO = 'Produto não encontrado.';

  SQL_INCLUIR =
    'INSERT INTO PRODUTOS (DESCRICAO, UNIDADE, PRECO_UNITARIO, CATEGORIA, ATIVO) ' +
    'VALUES (:DESCRICAO, :UNIDADE, :PRECO_UNITARIO, :CATEGORIA, :ATIVO) ' +
    'RETURNING ID';
  SQL_ALTERAR =
    'UPDATE PRODUTOS SET DESCRICAO = :DESCRICAO, UNIDADE = :UNIDADE, ' +
    'PRECO_UNITARIO = :PRECO_UNITARIO, CATEGORIA = :CATEGORIA, ATIVO = :ATIVO ' +
    'WHERE ID = :ID';
  SQL_EXCLUIR = 'DELETE FROM PRODUTOS WHERE ID = :ID';
  SQL_OBTER =
    'SELECT ID, DESCRICAO, UNIDADE, PRECO_UNITARIO, CATEGORIA, ATIVO ' +
    'FROM PRODUTOS WHERE ID = :ID';
  SQL_LISTAR_BASE =
    'SELECT ID, DESCRICAO, UNIDADE, PRECO_UNITARIO, CATEGORIA, ATIVO ' +
    'FROM PRODUTOS WHERE (1 = 1) ';
  SQL_LISTAR_ATIVOS = 'AND ATIVO = TRUE ';
  { RF4-03: busca sem caixa e sem acento via collation ERPV_CI_AI (db/01_schema.sql). }
  SQL_LISTAR_BUSCA =
    'AND (DESCRICAO COLLATE ERPV_CI_AI LIKE :BUSCA ESCAPE ''\'' ' +
    'OR CATEGORIA COLLATE ERPV_CI_AI LIKE :BUSCA ESCAPE ''\'') ';
  SQL_LISTAR_ORDEM = 'ORDER BY DESCRICAO, ID';

function EscaparLike(const S: string): string;
begin
  Result := StringReplace(S, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '%', '\%', [rfReplaceAll]);
  Result := StringReplace(Result, '_', '\_', [rfReplaceAll]);
end;

{ TProdutoRepository }

constructor TProdutoRepository.Create(AConexao: TConexao; ALogger: TLogger);
begin
  inherited Create;
  if not Assigned(AConexao) then
    raise EArgumentException.Create('TProdutoRepository.Create: conexao nao pode ser nil.');
  if not Assigned(ALogger) then
    raise EArgumentException.Create('TProdutoRepository.Create: logger nao pode ser nil.');
  FConexao := AConexao;
  FLogger := ALogger;
end;

function TProdutoRepository.NovaQuery: TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := FConexao.Connection;
end;

procedure TProdutoRepository.PreencherParametros(AQuery: TFDQuery; const AProduto: TProduto);
begin
  AQuery.ParamByName('DESCRICAO').AsString := AProduto.Descricao;
  AQuery.ParamByName('UNIDADE').AsString := AProduto.Unidade;
  AQuery.ParamByName('PRECO_UNITARIO').AsCurrency := AProduto.PrecoUnitario;
  AQuery.ParamByName('CATEGORIA').AsString := AProduto.Categoria;
  AQuery.ParamByName('ATIVO').AsBoolean := AProduto.Ativo;
end;

procedure TProdutoRepository.TratarFalha(const AOperacao: string; E: Exception);
var
  Mensagem: string;
begin
  FLogger.Erro('Falha no ProdutoRepository: ' + AOperacao, E);

  if AOperacao = 'excluir' then
    Mensagem := MSG_FALHA_EXCLUIR
  else if (AOperacao = 'obter') or (AOperacao = 'listar') then
    Mensagem := MSG_FALHA_CONSULTAR
  else
    Mensagem := MSG_FALHA_GRAVAR;

  if (E is EFDDBEngineException) and (AOperacao = 'excluir') and
     (EFDDBEngineException(E).Kind = ekFKViolated) then
    Mensagem := MSG_PRODUTO_EM_USO;

  // Mensagens especificas fixas passam pelo handler global; as genericas seguem EInfra.
  if (Mensagem = MSG_PRODUTO_EM_USO) or (Mensagem = MSG_NAO_ENCONTRADO) then
    raise EInfraMensagemSegura.Create(Mensagem);
  raise EInfra.Create(Mensagem);
end;

function TProdutoRepository.Incluir(const AProduto: TProduto): Integer;
var
  Q: TFDQuery;
  Iniciou: Boolean;
begin
  Result := 0;
  Iniciou := False;
  Q := NovaQuery;
  try
    try
      Iniciou := not FConexao.EmTransacao;
      FConexao.IniciarTransacao;
      Q.SQL.Text := SQL_INCLUIR;
      PreencherParametros(Q, AProduto);
      Q.Open;
      Result := Q.FieldByName('ID').AsInteger;
      Q.Close;
      if Iniciou then
        FConexao.Confirmar;
      AProduto.Id := Result;
    except
      on E: Exception do
      begin
        if Iniciou then
          FConexao.Desfazer;
        if E is EInfra then
          raise;
        TratarFalha('incluir', E);
      end;
    end;
  finally
    Q.Free;
  end;
end;

procedure TProdutoRepository.Alterar(const AProduto: TProduto);
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
      Q.SQL.Text := SQL_ALTERAR;
      PreencherParametros(Q, AProduto);
      Q.ParamByName('ID').AsInteger := AProduto.Id;
      Q.ExecSQL;
      if Q.RowsAffected = 0 then
        raise EInfraMensagemSegura.Create(MSG_NAO_ENCONTRADO);
      if Iniciou then
        FConexao.Confirmar;
    except
      on E: Exception do
      begin
        if Iniciou then
          FConexao.Desfazer;
        if E is EInfra then
          raise;
        TratarFalha('alterar', E);
      end;
    end;
  finally
    Q.Free;
  end;
end;

procedure TProdutoRepository.Excluir(AId: Integer);
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
      Q.SQL.Text := SQL_EXCLUIR;
      Q.ParamByName('ID').AsInteger := AId;
      Q.ExecSQL;
      if Q.RowsAffected = 0 then
        raise EInfraMensagemSegura.Create(MSG_NAO_ENCONTRADO);
      if Iniciou then
        FConexao.Confirmar;
    except
      on E: Exception do
      begin
        if Iniciou then
          FConexao.Desfazer;
        if E is EInfra then
          raise;
        TratarFalha('excluir', E);
      end;
    end;
  finally
    Q.Free;
  end;
end;

function TProdutoRepository.Obter(AId: Integer): TProduto;
var
  Q: TFDQuery;
begin
  Result := nil;
  Q := NovaQuery;
  try
    try
      Q.SQL.Text := SQL_OBTER;
      Q.ParamByName('ID').AsInteger := AId;
      Q.Open;
      if not Q.IsEmpty then
      begin
        Result := TProduto.Create;
        Result.Id := Q.FieldByName('ID').AsInteger;
        Result.Descricao := Q.FieldByName('DESCRICAO').AsString;
        Result.Unidade := Q.FieldByName('UNIDADE').AsString;
        Result.PrecoUnitario := Q.FieldByName('PRECO_UNITARIO').AsCurrency;
        Result.Categoria := Q.FieldByName('CATEGORIA').AsString;
        Result.Ativo := Q.FieldByName('ATIVO').AsBoolean;
      end;
    except
      on E: Exception do
      begin
        FreeAndNil(Result);
        if E is EInfra then
          raise;
        TratarFalha('obter', E);
      end;
    end;
  finally
    Q.Free;
  end;
end;

function TProdutoRepository.ListarDataSet(const AFiltroBusca: string;
  AIncluirInativos: Boolean): TDataSet;
var
  Q: TFDQuery;
  Busca: string;
  SQL: string;
begin
  Busca := Trim(AFiltroBusca);
  SQL := SQL_LISTAR_BASE;
  if not AIncluirInativos then
    SQL := SQL + SQL_LISTAR_ATIVOS;
  if Busca <> '' then
    SQL := SQL + SQL_LISTAR_BUSCA;
  SQL := SQL + SQL_LISTAR_ORDEM;

  Q := NovaQuery;
  try
    Q.UpdateOptions.ReadOnly := True; // grade somente leitura (ADR-003)
    Q.SQL.Text := SQL;
    if Busca <> '' then
      Q.ParamByName('BUSCA').AsString := '%' + EscaparLike(Busca) + '%';
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

end.
