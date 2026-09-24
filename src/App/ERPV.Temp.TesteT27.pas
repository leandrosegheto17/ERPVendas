unit ERPV.Temp.TesteT27;
// TEMPORARIO (T27) - remover apos verificacao.
interface
uses ERPV.App.Root;
procedure RodarTesteT27(Root: TRootAplicacao);
implementation
uses
  System.SysUtils, Data.DB, Vcl.Dialogs, ERPV.Core.Erros, ERPV.Dominio.Enums,
  ERPV.Dominio.Cliente, ERPV.Dominio.Produto, ERPV.Dominio.Venda, ERPV.Dominio.VendaItem;

procedure Rel(const ACaso: string; AOk: Boolean);
begin
  if AOk then ShowMessage('T26/T27 TESTE - OK: ' + ACaso) else ShowMessage('T26/T27 TESTE - FALHA: ' + ACaso);
end;

function Recusa(Root: TRootAplicacao; AVenda: TVenda): Boolean;
begin
  Result := False;
  try
    Root.VendaService.Salvar(AVenda);
  except
    on E: EValidacao do
    begin
      ShowMessage('T26/T27 TESTE - Motivo: ' + E.Message);
      Result := True;
    end;
  end;
end;

procedure AddItem(AVenda: TVenda; AProd, AQtd: Integer);
var I: TVendaItem;
begin
  I := TVendaItem.Create;
  I.ProdutoId := AProd; I.Quantidade := AQtd; I.PrecoUnitario := 10;
  AVenda.Itens.Add(I);
end;

procedure RodarTesteT27(Root: TRootAplicacao);
var
  CliA, CliI: TCliente;
  ProA, ProI: TProduto;
  V, V2: TVenda;
  IdVenda: Integer;
  DS: TDataSet;
begin
  CliA := TCliente.Create; CliI := TCliente.Create;
  ProA := TProduto.Create; ProI := TProduto.Create;
  V := TVenda.Create;
  try
    try
      CliA.Nome := 'T27 Ativo'; CliA.TipoPessoa := tpFisica; CliA.CpfCnpj := '11144477735';
      CliA.Email := 't27a@teste.com'; CliA.Ativo := True;
      Root.ClienteService.Salvar(CliA);
      CliI.Nome := 'T27 Inativo'; CliI.TipoPessoa := tpJuridica; CliI.CpfCnpj := '11444777000161';
      CliI.Email := 't27i@teste.com'; CliI.Ativo := False;
      Root.ClienteService.Salvar(CliI);
      ProA.Descricao := 'T27 Prod Ativo'; ProA.Unidade := 'UN'; ProA.PrecoUnitario := 10; ProA.Ativo := True;
      Root.ProdutoService.Salvar(ProA);
      ProI.Descricao := 'T27 Prod Inativo'; ProI.Unidade := 'UN'; ProI.PrecoUnitario := 10; ProI.Ativo := False;
      Root.ProdutoService.Salvar(ProI);

      V.ClienteId := CliA.Id;
      Rel('sem itens recusada', Recusa(Root, V));

      AddItem(V, ProA.Id, 0);
      Rel('qtd 0 recusada', Recusa(Root, V));

      V.Itens.Clear; AddItem(V, ProA.Id, 1);
      V.ClienteId := CliI.Id;
      Rel('cliente inativo recusado', Recusa(Root, V));
      V.ClienteId := 999999;
      Rel('cliente inexistente recusado', Recusa(Root, V));

      V.ClienteId := CliA.Id; V.Itens.Clear; AddItem(V, ProI.Id, 1);
      Rel('produto inativo recusado', Recusa(Root, V));

      V.Itens.Clear; AddItem(V, ProA.Id, 2);
      IdVenda := Root.VendaService.Salvar(V);
      V2 := Root.VendaService.Obter(IdVenda);
      try
        Rel('venda valida grava Pendente e rele',
          (V2 <> nil) and (V2.Status = svPendente) and (V2.Itens.Count = 1));
      finally
        V2.Free;
      end;
      // --- T26 ---
      DS := Root.VendaService.ListarDataSet('', 0);
      try
        Rel('T26 lista traz venda com CLIENTE_NOME e VALOR_TOTAL',
          DS.Locate('ID', IdVenda, []) and (DS.FieldByName('CLIENTE_NOME').AsString = 'T27 Ativo')
          and (DS.FindField('VALOR_TOTAL') <> nil) and not DS.FieldByName('VALOR_TOTAL').IsNull);
      finally
        DS.Free;
      end;
      DS := Root.VendaService.ListarDataSet('Quitada', 0);
      try
        Rel('T26 filtro Quitada nao traz a Pendente', not DS.Locate('ID', IdVenda, []));
      finally
        DS.Free;
      end;
      DS := Root.VendaService.ListarDataSet('Pendente', CliA.Id);
      try
        Rel('T26 filtro Pendente+cliente traz a venda', DS.Locate('ID', IdVenda, []));
      finally
        DS.Free;
      end;
      Rel('T26 ExisteVendaPorCliente(com venda)=True', Root.VendaRepository.ExisteVendaPorCliente(CliA.Id));
      Rel('T26 ExisteVendaPorCliente(sem venda)=False', not Root.VendaRepository.ExisteVendaPorCliente(CliI.Id));
      Rel('T26 ExisteVendaPorProduto(vendido)=True', Root.VendaRepository.ExisteVendaPorProduto(ProA.Id));
      Rel('T26 ExisteVendaPorProduto(sem item)=False', not Root.VendaRepository.ExisteVendaPorProduto(ProI.Id));
      Root.VendaService.Excluir(IdVenda);
    except
      on E: Exception do ShowMessage('T26/T27 TESTE - FALHA inesperada: ' + E.Message);
    end;
    try Root.ProdutoService.Excluir(ProA.Id); except end;
    try Root.ProdutoService.Excluir(ProI.Id); except end;
    try Root.ClienteService.Excluir(CliA.Id); except end;
    try Root.ClienteService.Excluir(CliI.Id); except end;
  finally
    V.Free; CliA.Free; CliI.Free; ProA.Free; ProI.Free;
  end;
end;
end.
