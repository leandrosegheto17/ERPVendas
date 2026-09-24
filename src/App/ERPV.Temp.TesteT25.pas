unit ERPV.Temp.TesteT25;

{
  TEMPORARIO (T25) - remover apos verificar. Exercita TVendaRepository contra
  o banco real (cliente/produtos do seed) e mostra o resultado num
  ShowMessage. Limpa o que criar.
}

interface

uses
  ERPV.App.Root;

procedure RodarTesteT25(ARoot: TRootAplicacao);

implementation

uses
  System.SysUtils,
  Vcl.Dialogs,
  FireDAC.Comp.Client,
  ERPV.Dominio.Enums,
  ERPV.Dominio.Venda,
  ERPV.Dominio.VendaItem;

function NovaVenda(AClienteId, AProd1, AProd2, AQtd2: Integer): TVenda;
var
  I: TVendaItem;
begin
  Result := TVenda.Create;
  Result.ClienteId := AClienteId;
  Result.DataVenda := Now;
  Result.Status := svPendente;
  I := TVendaItem.Create;
  I.ProdutoId := AProd1;
  I.Quantidade := 2;
  I.PrecoUnitario := 10.55;
  Result.Itens.Add(I);
  I := TVendaItem.Create;
  I.ProdutoId := AProd2;
  I.Quantidade := AQtd2;
  I.PrecoUnitario := 5;
  Result.Itens.Add(I);
  Result.ValorTotal := 2 * 10.55 + AQtd2 * 5;
end;

procedure RodarTesteT25(ARoot: TRootAplicacao);
var
  Log: string;
  Cli, P1, P2, Id, AntesV, DepoisV: Integer;
  V, V2: TVenda;
  Ok: Boolean;

  procedure Passo(const AMsg: string; ACond: Boolean);
  begin
    if ACond then
      Log := Log + 'OK   ' + AMsg + sLineBreak
    else
    begin
      Log := Log + 'FALHA ' + AMsg + sLineBreak;
      Ok := False;
    end;
  end;

  function Contar(const ASQL: string): Integer;
  begin
    Result := ARoot.Conexao.Connection.ExecSQLScalar(ASQL);
  end;

begin
  Ok := True;
  Log := '';
  Id := 0;
  try
    Cli := Contar('SELECT MIN(ID) FROM CLIENTES');
    P1 := Contar('SELECT MIN(ID) FROM PRODUTOS');
    P2 := Contar('SELECT MAX(ID) FROM PRODUTOS');

    // (1) incluir com 2 itens e Obter
    V := NovaVenda(Cli, P1, P2, 1);
    try
      Id := ARoot.VendaRepository.Incluir(V);
    finally
      V.Free;
    end;
    V2 := ARoot.VendaRepository.Obter(Id);
    try
      Passo('(1) Obter devolve a venda', V2 <> nil);
      if V2 <> nil then
      begin
        Passo('(1) 2 itens', V2.Itens.Count = 2);
        Passo('(1) ValorTotal 26,10 (Currency)', V2.ValorTotal = 26.10);
        Passo('(1) status Pendente, sem quitacao', (V2.Status = svPendente) and not V2.TemDataQuitacao);
        Passo('(1) preco item 1 = 10,55', (V2.Itens.Count > 0) and (V2.Itens[0].PrecoUnitario = 10.55));
      end;
    finally
      V2.Free;
    end;

    // (2) erro forcado no 2o item (quantidade 0 -> CK_ITENS_QTD)
    AntesV := Contar('SELECT COUNT(*) FROM VENDAS');
    V := NovaVenda(Cli, P1, P2, 0);
    try
      try
        ARoot.VendaRepository.Incluir(V);
        Passo('(2) deveria ter levantado excecao', False);
      except
        on E: Exception do
          Passo('(2) excecao levantada (' + E.ClassName + ')', True);
      end;
    finally
      V.Free;
    end;
    DepoisV := Contar('SELECT COUNT(*) FROM VENDAS');
    Passo(Format('(2) VENDAS antes=%d depois=%d (rollback do mestre)', [AntesV, DepoisV]),
      AntesV = DepoisV);

    // (3) AtualizarStatus -> Quitada
    ARoot.VendaRepository.AtualizarStatus(Id, svQuitada, EncodeDate(2026, 9, 23) + EncodeTime(10, 30, 0, 0), '');
    V2 := ARoot.VendaRepository.Obter(Id);
    try
      Passo('(3) Quitada com dataQuitacao',
        (V2 <> nil) and (V2.Status = svQuitada) and V2.TemDataQuitacao and
        (Abs(V2.DataQuitacao - (EncodeDate(2026, 9, 23) + EncodeTime(10, 30, 0, 0))) < 1 / 86400));
    finally
      V2.Free;
    end;

    // (4) Excluir
    ARoot.VendaRepository.Excluir(Id);
    V2 := ARoot.VendaRepository.Obter(Id);
    try
      Passo('(4) Obter devolve nil apos excluir', V2 = nil);
    finally
      V2.Free;
    end;
    Passo('(4) itens sumiram',
      Contar('SELECT COUNT(*) FROM VENDA_ITENS WHERE VENDA_ID = ' + IntToStr(Id)) = 0);
    Id := 0;
  except
    on E: Exception do
    begin
      Log := Log + 'EXCECAO INESPERADA: ' + E.ClassName + ': ' + E.Message + sLineBreak;
      Ok := False;
    end;
  end;

  // limpeza best effort (caso algo tenha parado no meio)
  if Id <> 0 then
    try
      ARoot.VendaRepository.Excluir(Id);
    except
    end;

  if Ok then
    ShowMessage('T25 TESTE: TUDO OK' + sLineBreak + Log)
  else
    ShowMessage('T25 TESTE: HOUVE FALHAS' + sLineBreak + Log);
end;

end.
