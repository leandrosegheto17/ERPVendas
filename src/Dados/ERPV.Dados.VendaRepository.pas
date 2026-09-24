unit ERPV.Dados.VendaRepository;

(*
  T25 (Lote 6) - Implementacao FireDAC de IVendaRepository (ADR-002/003/010):
  gravacao/leitura de VENDAS + VENDA_ITENS.

  - Mestre + itens SEMPRE na mesma transacao (iniciada aqui somente se o
    chamador ainda nao abriu uma); erro em qualquer item => Desfazer (rollback
    do mestre tambem). SQL 100% parametrizado; valores em Currency.
  - Alterar: UPDATE do mestre + DELETE dos itens + INSERT dos itens atuais.
  - Excluir: apaga itens explicitamente e depois o mestre (o banco tambem tem
    ON DELETE CASCADE, T03).
  - Falha FireDAC => EInfra amigavel (sem SQL) + detalhe no log.
  - ListarDataSet / ExisteVendaPorCliente / ExisteVendaPorProduto (T26) ja
    estao implementados abaixo (nao sao mais stubs).

  ROTEIRO MANUAL NA IDE (compilacao/execucao pendentes do usuario):
  1. Com Root montado e cliente/produtos existentes, montar TVenda com 2 itens
     (ClienteId, DataVenda=Now, ValorTotal, Status=svPendente) e chamar
     Incluir; conferir Id > 0 e, no banco, 1 linha em VENDAS + 2 em
     VENDA_ITENS. Obter(Id) devolve os 2 itens e valores Currency identicos.
  2. Rollback: repetir Incluir com o 2o item com ProdutoId inexistente (FK) ou
     Quantidade 0 (CHECK); deve levantar EInfra e NAO existir venda nova
     (SELECT COUNT(1) FROM VENDAS igual ao anterior).
  3. Alterar (trocar itens) e conferir; AtualizarStatus(Id, svQuitada, Now, '')
     e depois svCancelada com motivo; Obter reflete.
  4. Excluir(Id): VENDAS e VENDA_ITENS da venda ficam vazios.

  T45 (Lote 11) - RelatorioDataSet(AVendaId): DataSet somente leitura, 1 linha
  por item (venda + cliente repetidos), colunas VENDA_ID, DATA_VENDA, STATUS,
  VALOR_TOTAL, CLIENTE_NOME, CLIENTE_CPF_CNPJ, CLIENTE_EMAIL,
  PRODUTO_DESCRICAO, QUANTIDADE, PRECO_UNITARIO, SUBTOTAL. O chamador libera.
  ROTEIRO T45 NA IDE:
  5. Com venda de 2 itens: RelatorioDataSet(Id) devolve 2 registros; conferir
     CLIENTE_NOME, CLIENTE_CPF_CNPJ, descricao/quantidade/preco dos itens e
     VALOR_TOTAL contra SELECT direto no banco (Currency identicos; SUBTOTAL =
     QUANTIDADE*PRECO_UNITARIO; soma dos SUBTOTAL = VALOR_TOTAL).
  6. Id inexistente: DataSet vazio (IsEmpty). Tentar Edit/Post: deve recusar.
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
  ERPV.Dominio.Enums,
  ERPV.Dominio.Venda,
  ERPV.Dominio.VendaItem,
  ERPV.Dominio.Contratos.IVendaRepository;

type
  TVendaRepository = class(TInterfacedObject, IVendaRepository)
  private
    FConexao: TConexao;
    FLogger: TLogger;
    function NovaQuery: TFDQuery;
    procedure PreencherMestre(AQuery: TFDQuery; const AVenda: TVenda);
    procedure InserirItens(const AVenda: TVenda);
    procedure TratarFalha(const AOperacao: string; E: Exception);
    function Existe(const ASQL, AOperacao: string; AId: Integer): Boolean;
  public
    constructor Create(AConexao: TConexao; ALogger: TLogger);

    function Incluir(const AVenda: TVenda): Integer;
    procedure Alterar(const AVenda: TVenda);
    procedure Excluir(AId: Integer);
    function Obter(AId: Integer): TVenda;
    procedure AtualizarStatus(AId: Integer; AStatus: TStatusVenda; ADataQuitacao: TDateTime;
      const AMotivoCancelamento: string);
    // T26 (stubs)
    function ListarDataSet(const AStatusFiltro: string; AClienteIdFiltro: Integer): TDataSet;
    function ExisteVendaPorCliente(AClienteId: Integer): Boolean;
    function ExisteVendaPorProduto(AProdutoId: Integer): Boolean;
    // T45
    function RelatorioDataSet(AVendaId: Integer): TDataSet;
  end;

implementation

const
  MSG_FALHA_GRAVAR = 'Não foi possível gravar a venda. Tente novamente.';
  MSG_FALHA_CONSULTAR = 'Não foi possível consultar a venda. Tente novamente.';
  MSG_FALHA_EXCLUIR = 'Não foi possível excluir a venda. Tente novamente.';
  MSG_NAO_ENCONTRADA = 'Venda não encontrada.';
  MSG_FALHA_VERIFICAR_CLIENTE = 'Não foi possível verificar as vendas do cliente. Tente novamente.';
  MSG_FALHA_VERIFICAR_PRODUTO = 'Não foi possível verificar as vendas do produto. Tente novamente.';

  // T26: lista (JOIN p/ nome do cliente; VALOR_TOTAL ja e o total da venda)
  SQL_LISTAR_BASE =
    'SELECT V.ID, V.CLIENTE_ID, C.NOME AS CLIENTE_NOME, V.DATA_VENDA, ' +
    'V.VALOR_TOTAL, V.STATUS, V.DATA_QUITACAO, V.MOTIVO_CANCELAMENTO ' +
    'FROM VENDAS V JOIN CLIENTES C ON C.ID = V.CLIENTE_ID WHERE (1 = 1) ';
  SQL_LISTAR_STATUS = 'AND V.STATUS = :STATUS ';
  SQL_LISTAR_CLIENTE = 'AND V.CLIENTE_ID = :CLIENTE_ID ';
  SQL_LISTAR_ORDEM = 'ORDER BY V.DATA_VENDA DESC, V.ID DESC';
  SQL_EXISTE_CLIENTE = 'SELECT FIRST 1 ID FROM VENDAS WHERE CLIENTE_ID = :ID';
  SQL_EXISTE_PRODUTO = 'SELECT FIRST 1 ID FROM VENDA_ITENS WHERE PRODUTO_ID = :ID';

  // T45: relatorio (1 linha por item; SUBTOTAL calculado no banco)
  SQL_RELATORIO =
    'SELECT V.ID AS VENDA_ID, V.DATA_VENDA, V.STATUS, V.VALOR_TOTAL, ' +
    'C.NOME AS CLIENTE_NOME, C.CPF_CNPJ AS CLIENTE_CPF_CNPJ, ' +
    'C.EMAIL AS CLIENTE_EMAIL, P.DESCRICAO AS PRODUTO_DESCRICAO, ' +
    'I.QUANTIDADE, I.PRECO_UNITARIO, I.QUANTIDADE * I.PRECO_UNITARIO AS SUBTOTAL ' +
    'FROM VENDAS V JOIN CLIENTES C ON C.ID = V.CLIENTE_ID ' +
    'LEFT JOIN VENDA_ITENS I ON I.VENDA_ID = V.ID ' +
    'LEFT JOIN PRODUTOS P ON P.ID = I.PRODUTO_ID ' +
    'WHERE V.ID = :ID ORDER BY I.ID';

  SQL_INCLUIR =
    'INSERT INTO VENDAS (CLIENTE_ID, DATA_VENDA, VALOR_TOTAL, STATUS, DATA_QUITACAO, ' +
    'MOTIVO_CANCELAMENTO) VALUES (:CLIENTE_ID, :DATA_VENDA, :VALOR_TOTAL, :STATUS, ' +
    ':DATA_QUITACAO, :MOTIVO) RETURNING ID';
  SQL_ALTERAR =
    'UPDATE VENDAS SET CLIENTE_ID = :CLIENTE_ID, DATA_VENDA = :DATA_VENDA, ' +
    'VALOR_TOTAL = :VALOR_TOTAL, STATUS = :STATUS, DATA_QUITACAO = :DATA_QUITACAO, ' +
    'MOTIVO_CANCELAMENTO = :MOTIVO WHERE ID = :ID';
  SQL_ITEM_INCLUIR =
    'INSERT INTO VENDA_ITENS (VENDA_ID, PRODUTO_ID, QUANTIDADE, PRECO_UNITARIO) ' +
    'VALUES (:VENDA_ID, :PRODUTO_ID, :QUANTIDADE, :PRECO_UNITARIO)';
  SQL_ITENS_EXCLUIR = 'DELETE FROM VENDA_ITENS WHERE VENDA_ID = :ID';
  SQL_EXCLUIR = 'DELETE FROM VENDAS WHERE ID = :ID';
  SQL_OBTER =
    'SELECT ID, CLIENTE_ID, DATA_VENDA, VALOR_TOTAL, STATUS, DATA_QUITACAO, ' +
    'MOTIVO_CANCELAMENTO FROM VENDAS WHERE ID = :ID';
  SQL_OBTER_ITENS =
    'SELECT ID, VENDA_ID, PRODUTO_ID, QUANTIDADE, PRECO_UNITARIO ' +
    'FROM VENDA_ITENS WHERE VENDA_ID = :ID ORDER BY ID';
  SQL_STATUS =
    'UPDATE VENDAS SET STATUS = :STATUS, DATA_QUITACAO = :DATA_QUITACAO, ' +
    'MOTIVO_CANCELAMENTO = :MOTIVO WHERE ID = :ID';

procedure DefinirDataOuNulo(AQuery: TFDQuery; const ANome: string; AValor: TDateTime);
begin
  AQuery.ParamByName(ANome).DataType := ftDateTime;
  if AValor <> 0 then
    AQuery.ParamByName(ANome).AsDateTime := AValor
  else
    AQuery.ParamByName(ANome).Clear;
end;

procedure DefinirTextoOuNulo(AQuery: TFDQuery; const ANome, AValor: string);
begin
  AQuery.ParamByName(ANome).DataType := ftString;
  if AValor <> '' then
    AQuery.ParamByName(ANome).AsString := AValor
  else
    AQuery.ParamByName(ANome).Clear;
end;

{ TVendaRepository }

constructor TVendaRepository.Create(AConexao: TConexao; ALogger: TLogger);
begin
  inherited Create;
  if not Assigned(AConexao) then
    raise EArgumentException.Create('TVendaRepository.Create: conexao nao pode ser nil.');
  if not Assigned(ALogger) then
    raise EArgumentException.Create('TVendaRepository.Create: logger nao pode ser nil.');
  FConexao := AConexao;
  FLogger := ALogger;
end;

function TVendaRepository.NovaQuery: TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := FConexao.Connection;
end;

procedure TVendaRepository.PreencherMestre(AQuery: TFDQuery; const AVenda: TVenda);
begin
  AQuery.ParamByName('CLIENTE_ID').AsInteger := AVenda.ClienteId;
  AQuery.ParamByName('DATA_VENDA').AsDateTime := AVenda.DataVenda;
  AQuery.ParamByName('VALOR_TOTAL').AsCurrency := AVenda.ValorTotal;
  AQuery.ParamByName('STATUS').AsString := StatusVendaToStr(AVenda.Status);
  DefinirDataOuNulo(AQuery, 'DATA_QUITACAO', AVenda.DataQuitacao);
  DefinirTextoOuNulo(AQuery, 'MOTIVO', AVenda.MotivoCancelamento);
end;

procedure TVendaRepository.TratarFalha(const AOperacao: string; E: Exception);
var
  Mensagem: string;
begin
  FLogger.Erro('Falha no VendaRepository: ' + AOperacao, E);
  if AOperacao = 'excluir' then
    Mensagem := MSG_FALHA_EXCLUIR
  else if AOperacao = 'verificar-cliente' then
    Mensagem := MSG_FALHA_VERIFICAR_CLIENTE
  else if AOperacao = 'verificar-produto' then
    Mensagem := MSG_FALHA_VERIFICAR_PRODUTO
  else if AOperacao = 'obter' then
    Mensagem := MSG_FALHA_CONSULTAR
  else
    Mensagem := MSG_FALHA_GRAVAR;
  if (Mensagem = MSG_FALHA_VERIFICAR_CLIENTE) or
    (Mensagem = MSG_FALHA_VERIFICAR_PRODUTO) then
    raise EInfraMensagemSegura.Create(Mensagem);
  raise EInfra.Create(Mensagem);
end;

procedure TVendaRepository.InserirItens(const AVenda: TVenda);
var
  Q: TFDQuery;
  Item: TVendaItem;
begin
  Q := NovaQuery;
  try
    Q.SQL.Text := SQL_ITEM_INCLUIR;
    for Item in AVenda.Itens do
    begin
      Q.ParamByName('VENDA_ID').AsInteger := AVenda.Id;
      Q.ParamByName('PRODUTO_ID').AsInteger := Item.ProdutoId;
      Q.ParamByName('QUANTIDADE').AsInteger := Item.Quantidade;
      Q.ParamByName('PRECO_UNITARIO').AsCurrency := Item.PrecoUnitario;
      Q.ExecSQL;
    end;
  finally
    Q.Free;
  end;
end;

function TVendaRepository.Incluir(const AVenda: TVenda): Integer;
var
  Q: TFDQuery;
  Iniciou: Boolean;
  IdAnterior: Integer;
begin
  Result := 0;
  Iniciou := False;
  IdAnterior := AVenda.Id;
  Q := NovaQuery;
  try
    try
      Iniciou := not FConexao.EmTransacao;
      FConexao.IniciarTransacao;
      Q.SQL.Text := SQL_INCLUIR;
      PreencherMestre(Q, AVenda);
      Q.Open;
      Result := Q.FieldByName('ID').AsInteger;
      Q.Close;
      AVenda.Id := Result;
      InserirItens(AVenda);
      if Iniciou then
        FConexao.Confirmar;
    except
      on E: Exception do
      begin
        AVenda.Id := IdAnterior; // rollback: nao deixa Id de venda inexistente
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

procedure TVendaRepository.Alterar(const AVenda: TVenda);
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
      PreencherMestre(Q, AVenda);
      Q.ParamByName('ID').AsInteger := AVenda.Id;
      Q.ExecSQL;
      if Q.RowsAffected = 0 then
        raise EInfraMensagemSegura.Create(MSG_NAO_ENCONTRADA);

      Q.SQL.Text := SQL_ITENS_EXCLUIR;
      Q.ParamByName('ID').AsInteger := AVenda.Id;
      Q.ExecSQL;
      InserirItens(AVenda);
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

procedure TVendaRepository.Excluir(AId: Integer);
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
      Q.SQL.Text := SQL_ITENS_EXCLUIR;
      Q.ParamByName('ID').AsInteger := AId;
      Q.ExecSQL;
      Q.SQL.Text := SQL_EXCLUIR;
      Q.ParamByName('ID').AsInteger := AId;
      Q.ExecSQL;
      if Q.RowsAffected = 0 then
        raise EInfraMensagemSegura.Create(MSG_NAO_ENCONTRADA);
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

function TVendaRepository.Obter(AId: Integer): TVenda;
var
  Q: TFDQuery;
  Item: TVendaItem;
begin
  Result := nil;
  Q := NovaQuery;
  try
    try
      Q.SQL.Text := SQL_OBTER;
      Q.ParamByName('ID').AsInteger := AId;
      Q.Open;
      if Q.IsEmpty then
        Exit;
      Result := TVenda.Create;
      Result.Id := Q.FieldByName('ID').AsInteger;
      Result.ClienteId := Q.FieldByName('CLIENTE_ID').AsInteger;
      Result.DataVenda := Q.FieldByName('DATA_VENDA').AsDateTime;
      Result.ValorTotal := Q.FieldByName('VALOR_TOTAL').AsCurrency;
      Result.Status := StrToStatusVenda(Q.FieldByName('STATUS').AsString);
      if not Q.FieldByName('DATA_QUITACAO').IsNull then
        Result.DataQuitacao := Q.FieldByName('DATA_QUITACAO').AsDateTime;
      Result.MotivoCancelamento := Q.FieldByName('MOTIVO_CANCELAMENTO').AsString;
      Q.Close;

      Q.SQL.Text := SQL_OBTER_ITENS;
      Q.ParamByName('ID').AsInteger := AId;
      Q.Open;
      while not Q.Eof do
      begin
        Item := TVendaItem.Create;
        Result.Itens.Add(Item);
        Item.Id := Q.FieldByName('ID').AsInteger;
        Item.VendaId := Q.FieldByName('VENDA_ID').AsInteger;
        Item.ProdutoId := Q.FieldByName('PRODUTO_ID').AsInteger;
        Item.Quantidade := Q.FieldByName('QUANTIDADE').AsInteger;
        Item.PrecoUnitario := Q.FieldByName('PRECO_UNITARIO').AsCurrency;
        Q.Next;
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

procedure TVendaRepository.AtualizarStatus(AId: Integer; AStatus: TStatusVenda;
  ADataQuitacao: TDateTime; const AMotivoCancelamento: string);
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
      Q.SQL.Text := SQL_STATUS;
      Q.ParamByName('STATUS').AsString := StatusVendaToStr(AStatus);
      DefinirDataOuNulo(Q, 'DATA_QUITACAO', ADataQuitacao);
      DefinirTextoOuNulo(Q, 'MOTIVO', AMotivoCancelamento);
      Q.ParamByName('ID').AsInteger := AId;
      Q.ExecSQL;
      if Q.RowsAffected = 0 then
        raise EInfraMensagemSegura.Create(MSG_NAO_ENCONTRADA);
      if Iniciou then
        FConexao.Confirmar;
    except
      on E: Exception do
      begin
        if Iniciou then
          FConexao.Desfazer;
        if E is EInfra then
          raise;
        TratarFalha('status', E);
      end;
    end;
  finally
    Q.Free;
  end;
end;

function TVendaRepository.ListarDataSet(const AStatusFiltro: string;
  AClienteIdFiltro: Integer): TDataSet;
var
  Q: TFDQuery;
  SQL: string;
begin
  SQL := SQL_LISTAR_BASE;
  if AStatusFiltro <> '' then
    SQL := SQL + SQL_LISTAR_STATUS;
  if AClienteIdFiltro > 0 then
    SQL := SQL + SQL_LISTAR_CLIENTE;
  SQL := SQL + SQL_LISTAR_ORDEM;

  Q := NovaQuery;
  try
    Q.UpdateOptions.ReadOnly := True; // grade somente leitura (ADR-003)
    Q.SQL.Text := SQL;
    if AStatusFiltro <> '' then
      Q.ParamByName('STATUS').AsString := AStatusFiltro;
    if AClienteIdFiltro > 0 then
      Q.ParamByName('CLIENTE_ID').AsInteger := AClienteIdFiltro;
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

function TVendaRepository.RelatorioDataSet(AVendaId: Integer): TDataSet;
var
  Q: TFDQuery;
begin
  Q := NovaQuery;
  try
    Q.UpdateOptions.ReadOnly := True; // somente leitura
    Q.SQL.Text := SQL_RELATORIO;
    Q.ParamByName('ID').AsInteger := AVendaId;
    Q.Open;
    Result := Q;
  except
    on E: Exception do
    begin
      Q.Free;
      if E is EInfra then
        raise;
      TratarFalha('obter', E);
      Result := nil; // inalcancavel (TratarFalha sempre levanta)
    end;
  end;
end;

function TVendaRepository.Existe(const ASQL, AOperacao: string; AId: Integer): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Q := NovaQuery;
  try
    try
      Q.SQL.Text := ASQL;
      Q.ParamByName('ID').AsInteger := AId;
      Q.Open;
      Result := not Q.IsEmpty;
    except
      on E: Exception do
      begin
        if E is EInfra then
          raise;
        TratarFalha(AOperacao, E);
      end;
    end;
  finally
    Q.Free;
  end;
end;

function TVendaRepository.ExisteVendaPorCliente(AClienteId: Integer): Boolean;
begin
  Result := Existe(SQL_EXISTE_CLIENTE, 'verificar-cliente', AClienteId);
end;

function TVendaRepository.ExisteVendaPorProduto(AProdutoId: Integer): Boolean;
begin
  Result := Existe(SQL_EXISTE_PRODUTO, 'verificar-produto', AProdutoId);
end;

end.
