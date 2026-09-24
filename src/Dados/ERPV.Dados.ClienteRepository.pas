unit ERPV.Dados.ClienteRepository;

(*
  T17 (Lote 4) - Implementacao FireDAC de IClienteRepository (ADR-003/010).

  - Usa somente a API de TConexao (Connection, IniciarTransacao, Confirmar,
    Desfazer, EmTransacao). SQL sempre parametrizado (ParamByName), nunca
    concatenado (GUARDRAILS 11).
  - CPF/CNPJ chega ja normalizado (so digitos) do Service (T18); aqui so se
    filtra defensivamente na busca.
  - ListarDataSet devolve um TFDQuery somente leitura; QUEM CHAMA (form dono)
    libera o DataSet. A query usa a conexao compartilhada, entao deve ser
    liberada antes de TConexao.
  - Falhas FireDAC viram EInfra com mensagem amigavel (sem SQL/caminho); o
    detalhe tecnico vai ao log (TLogger). Violacao de unicidade do documento
    e de FK na exclusao tem mensagem propria. O log nao recebe valores de
    parametros (CPF/e-mail), so a operacao e a excecao do FireDAC.
  - Escritas de tabela unica usam transacao explicita curta (iniciada aqui
    somente se o chamador ainda nao abriu uma).

  ROTEIRO MANUAL NA IDE (sem testes automatizados, DEC-14): num form/projeto
  temporario, com Root montado: Incluir cliente (CPF so digitos) -> Obter ->
  Alterar -> ExistePorDocumento (mesmo doc = True; com AIgnorarId = Id = False)
  -> ListarDataSet('', False) e com AIncluirInativos True apos inativar ->
  Excluir. Incluir mesmo CPF duas vezes deve mostrar mensagem amigavel e
  registrar detalhe no log. Compilacao pendente de confirmacao na IDE.
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
  ERPV.Dominio.Cliente,
  ERPV.Dominio.Contratos.IClienteRepository;

type
  TClienteRepository = class(TInterfacedObject, IClienteRepository)
  private
    FConexao: TConexao;
    FLogger: TLogger;
    function NovaQuery: TFDQuery;
    procedure PreencherParametros(AQuery: TFDQuery; const ACliente: TCliente);
    procedure TratarFalha(const AOperacao: string; E: Exception);
  public
    constructor Create(AConexao: TConexao; ALogger: TLogger);

    function Incluir(const ACliente: TCliente): Integer;
    procedure Alterar(const ACliente: TCliente);
    procedure Excluir(AId: Integer);
    function Obter(AId: Integer): TCliente;
    function ListarDataSet(const AFiltroBusca: string; AIncluirInativos: Boolean): TDataSet;
    function ExistePorDocumento(const ACpfCnpj: string; AIgnorarId: Integer = 0): Boolean;
  end;

implementation

const
  MSG_FALHA_GRAVAR = 'Não foi possível gravar o cliente. Tente novamente.';
  MSG_FALHA_CONSULTAR = 'Não foi possível consultar os clientes. Tente novamente.';
  MSG_FALHA_EXCLUIR = 'Não foi possível excluir o cliente. Tente novamente.';
  MSG_DOC_DUPLICADO = 'Já existe um cliente cadastrado com este CPF/CNPJ.';
  MSG_CLIENTE_EM_USO = 'O cliente possui vendas e não pode ser excluído; inative-o.';
  MSG_NAO_ENCONTRADO = 'Cliente não encontrado.';

  SQL_INCLUIR =
    'INSERT INTO CLIENTES (NOME, TIPO_PESSOA, CPF_CNPJ, ENDERECO, TELEFONE, EMAIL, ATIVO) ' +
    'VALUES (:NOME, :TIPO_PESSOA, :CPF_CNPJ, :ENDERECO, :TELEFONE, :EMAIL, :ATIVO) ' +
    'RETURNING ID';
  SQL_ALTERAR =
    'UPDATE CLIENTES SET NOME = :NOME, TIPO_PESSOA = :TIPO_PESSOA, ' +
    'CPF_CNPJ = :CPF_CNPJ, ENDERECO = :ENDERECO, TELEFONE = :TELEFONE, ' +
    'EMAIL = :EMAIL, ATIVO = :ATIVO WHERE ID = :ID';
  SQL_EXCLUIR = 'DELETE FROM CLIENTES WHERE ID = :ID';
  SQL_OBTER =
    'SELECT ID, NOME, TIPO_PESSOA, CPF_CNPJ, ENDERECO, TELEFONE, EMAIL, ATIVO ' +
    'FROM CLIENTES WHERE ID = :ID';
  SQL_LISTAR_BASE =
    'SELECT ID, NOME, TIPO_PESSOA, CPF_CNPJ, ENDERECO, TELEFONE, EMAIL, ATIVO ' +
    'FROM CLIENTES WHERE (1 = 1) ';
  SQL_LISTAR_ATIVOS = 'AND ATIVO = TRUE ';
  { RF4-03: busca sem caixa e sem acento via collation ERPV_CI_AI (db/01_schema.sql). }
  SQL_LISTAR_BUSCA =
    'AND (NOME COLLATE ERPV_CI_AI LIKE :BUSCA ESCAPE ''\'' ' +
    'OR EMAIL COLLATE ERPV_CI_AI LIKE :BUSCA ESCAPE ''\'' ' +
    'OR CPF_CNPJ LIKE :DOC) ';
  SQL_LISTAR_ORDEM = 'ORDER BY NOME, ID';
  SQL_EXISTE_DOC = 'SELECT 1 FROM CLIENTES WHERE CPF_CNPJ = :DOC AND ID <> :IGNORAR_ID';

function SoDigitos(const S: string): string;
var
  C: Char;
begin
  Result := '';
  for C in S do
    if (C >= '0') and (C <= '9') then
      Result := Result + C;
end;

function EscaparLike(const S: string): string;
begin
  Result := StringReplace(S, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '%', '\%', [rfReplaceAll]);
  Result := StringReplace(Result, '_', '\_', [rfReplaceAll]);
end;

{ TClienteRepository }

constructor TClienteRepository.Create(AConexao: TConexao; ALogger: TLogger);
begin
  inherited Create;
  if not Assigned(AConexao) then
    raise EArgumentException.Create('TClienteRepository.Create: conexao nao pode ser nil.');
  if not Assigned(ALogger) then
    raise EArgumentException.Create('TClienteRepository.Create: logger nao pode ser nil.');
  FConexao := AConexao;
  FLogger := ALogger;
end;

function TClienteRepository.NovaQuery: TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := FConexao.Connection;
end;

procedure TClienteRepository.PreencherParametros(AQuery: TFDQuery; const ACliente: TCliente);
begin
  AQuery.ParamByName('NOME').AsString := ACliente.Nome;
  AQuery.ParamByName('TIPO_PESSOA').AsString := TipoPessoaToChar(ACliente.TipoPessoa);
  AQuery.ParamByName('CPF_CNPJ').AsString := ACliente.CpfCnpj;
  AQuery.ParamByName('ENDERECO').AsString := ACliente.Endereco;
  AQuery.ParamByName('TELEFONE').AsString := ACliente.Telefone;
  AQuery.ParamByName('EMAIL').AsString := ACliente.Email;
  AQuery.ParamByName('ATIVO').AsBoolean := ACliente.Ativo;
end;

procedure TClienteRepository.TratarFalha(const AOperacao: string; E: Exception);
var
  Mensagem: string;
begin
  // Detalhe tecnico so no log; mensagem ao usuario e amigavel e fixa.
  FLogger.Erro('Falha no ClienteRepository: ' + AOperacao, E);

  if AOperacao = 'excluir' then
    Mensagem := MSG_FALHA_EXCLUIR
  else if (AOperacao = 'obter') or (AOperacao = 'listar') or (AOperacao = 'existe-por-documento') then
    Mensagem := MSG_FALHA_CONSULTAR
  else
    Mensagem := MSG_FALHA_GRAVAR;

  if E is EFDDBEngineException then
    case EFDDBEngineException(E).Kind of
      ekUKViolated: Mensagem := MSG_DOC_DUPLICADO;
      ekFKViolated: if AOperacao = 'excluir' then Mensagem := MSG_CLIENTE_EM_USO;
    end;

  // Mensagens especificas fixas passam pelo handler global; as genericas seguem EInfra.
  if (Mensagem = MSG_DOC_DUPLICADO) or (Mensagem = MSG_CLIENTE_EM_USO) then
    raise EInfraMensagemSegura.Create(Mensagem);
  raise EInfra.Create(Mensagem);
end;

function TClienteRepository.Incluir(const ACliente: TCliente): Integer;
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
      PreencherParametros(Q, ACliente);
      Q.Open;
      Result := Q.FieldByName('ID').AsInteger;
      Q.Close;
      if Iniciou then
        FConexao.Confirmar;
      ACliente.Id := Result;
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

procedure TClienteRepository.Alterar(const ACliente: TCliente);
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
      PreencherParametros(Q, ACliente);
      Q.ParamByName('ID').AsInteger := ACliente.Id;
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

procedure TClienteRepository.Excluir(AId: Integer);
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

function TClienteRepository.Obter(AId: Integer): TCliente;
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
        Result := TCliente.Create;
        Result.Id := Q.FieldByName('ID').AsInteger;
        Result.Nome := Q.FieldByName('NOME').AsString;
        Result.TipoPessoa := CharToTipoPessoa(Q.FieldByName('TIPO_PESSOA').AsString[1]);
        Result.CpfCnpj := Q.FieldByName('CPF_CNPJ').AsString;
        Result.Endereco := Q.FieldByName('ENDERECO').AsString;
        Result.Telefone := Q.FieldByName('TELEFONE').AsString;
        Result.Email := Q.FieldByName('EMAIL').AsString;
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

function TClienteRepository.ListarDataSet(const AFiltroBusca: string;
  AIncluirInativos: Boolean): TDataSet;
var
  Q: TFDQuery;
  Busca, Digitos: string;
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
    begin
      Q.ParamByName('BUSCA').AsString := '%' + EscaparLike(Busca) + '%';
      Digitos := SoDigitos(Busca);
      if Digitos <> '' then
        Q.ParamByName('DOC').AsString := '%' + Digitos + '%'
      else
        Q.ParamByName('DOC').AsString := 'x'; // CPF/CNPJ so tem digitos: nao casa
    end;
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

function TClienteRepository.ExistePorDocumento(const ACpfCnpj: string;
  AIgnorarId: Integer): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Q := NovaQuery;
  try
    try
      Q.SQL.Text := SQL_EXISTE_DOC;
      Q.ParamByName('DOC').AsString := SoDigitos(ACpfCnpj);
      Q.ParamByName('IGNORAR_ID').AsInteger := AIgnorarId;
      Q.Open;
      Result := not Q.IsEmpty;
    except
      on E: Exception do
      begin
        if E is EInfra then
          raise;
        TratarFalha('existe-por-documento', E);
      end;
    end;
  finally
    Q.Free;
  end;
end;

end.
